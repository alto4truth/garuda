use std::fs;
use garuda::chess::{Engine, GameStatus, Position, SearchConfig, TinyNeuralModel};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};

fn print_usage() {
    eprintln!("usage:");
    eprintln!("  garuda-chess bestmove [fen] [garuda_depth] [garuda_quiescence]");
    eprintln!("  garuda-chess apply <fen> <uci>");
    eprintln!("  garuda-chess status [fen]");
    eprintln!("  garuda-chess match-uci <engine_command> [plies] [movetime_ms] [garuda_color] [garuda_depth] [garuda_quiescence]");
    eprintln!("  garuda-chess bo-uci <engine_command> [games] [plies] [movetime_ms] [garuda_depth] [garuda_quiescence] [openings_file]");
}

struct UciEngine {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl UciEngine {
    fn spawn(engine_command: &str) -> Result<Self, String> {
        let mut child = if engine_command.contains(' ') {
            Command::new("sh")
                .arg("-lc")
                .arg(engine_command)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .spawn()
                .map_err(|error| format!("failed to launch engine command: {error}"))?
        } else {
            Command::new(engine_command)
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .spawn()
                .map_err(|error| format!("failed to launch engine: {error}"))?
        };
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| "missing engine stdin".to_string())?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| "missing engine stdout".to_string())?;
        let mut engine = Self {
            child,
            stdin,
            stdout: BufReader::new(stdout),
        };
        engine.command("uci")?;
        engine.read_until("uciok")?;
        engine.command("isready")?;
        engine.read_until("readyok")?;
        Ok(engine)
    }

    fn command(&mut self, line: &str) -> Result<(), String> {
        writeln!(self.stdin, "{line}").map_err(|error| format!("failed to write to engine: {error}"))?;
        self.stdin
            .flush()
            .map_err(|error| format!("failed to flush engine stdin: {error}"))?;
        Ok(())
    }

    fn read_until(&mut self, needle: &str) -> Result<String, String> {
        let mut line = String::new();
        loop {
            line.clear();
            let bytes = self
                .stdout
                .read_line(&mut line)
                .map_err(|error| format!("failed to read engine output: {error}"))?;
            if bytes == 0 {
                return Err("engine closed stdout unexpectedly".to_string());
            }
            if line.trim_start().starts_with(needle) {
                return Ok(line.trim().to_string());
            }
        }
    }

    fn bestmove(&mut self, position: &Position, movetime_ms: u64) -> Result<String, String> {
        self.command("ucinewgame")?;
        self.command("isready")?;
        self.read_until("readyok")?;
        self.command(&format!("position fen {}", position.to_fen()))?;
        self.command(&format!("go movetime {movetime_ms}"))?;
        let bestmove_line = self.read_until("bestmove")?;
        let mut parts = bestmove_line.split_whitespace();
        let _ = parts.next();
        parts
            .next()
            .map(str::to_string)
            .ok_or_else(|| "engine did not return a bestmove".to_string())
    }

    fn shutdown(&mut self) {
        let _ = self.command("quit");
        let _ = self.child.wait();
    }
}

impl Drop for UciEngine {
    fn drop(&mut self) {
        self.shutdown();
    }
}

fn parse_color(text: &str) -> Result<garuda::chess::Color, String> {
    match text {
        "w" | "white" => Ok(garuda::chess::Color::White),
        "b" | "black" => Ok(garuda::chess::Color::Black),
        _ => Err(format!("invalid color: {text}")),
    }
}

fn format_status(status: GameStatus) -> &'static str {
    match status {
        GameStatus::Ongoing => "ongoing",
        GameStatus::Checkmate { loser } => match loser {
            garuda::chess::Color::White => "checkmate:white-loses",
            garuda::chess::Color::Black => "checkmate:black-loses",
        },
        GameStatus::Stalemate { side_to_move } => match side_to_move {
            garuda::chess::Color::White => "stalemate:white-to-move",
            garuda::chess::Color::Black => "stalemate:black-to-move",
        },
        GameStatus::DrawByFiftyMoveRule => "draw:fifty-move-rule",
        GameStatus::DrawByRepetition => "draw:threefold-repetition",
    }
}

fn parse_usize_arg(value: Option<String>, default: usize) -> usize {
    value.and_then(|text| text.parse::<usize>().ok()).unwrap_or(default)
}

fn parse_u64_arg(value: Option<String>, default: u64) -> u64 {
    value.and_then(|text| text.parse::<u64>().ok()).unwrap_or(default)
}

fn build_search_config(depth: usize, quiescence_depth: usize) -> SearchConfig {
    SearchConfig {
        max_depth: depth,
        quiescence_depth,
        ..SearchConfig::default()
    }
}

fn load_openings(path: &str) -> Result<Vec<Position>, String> {
    let contents = fs::read_to_string(path).map_err(|error| format!("failed to read openings file: {error}"))?;
    let mut openings = Vec::new();
    for (line_index, line) in contents.lines().enumerate() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let position = Position::from_fen(trimmed)
            .map_err(|error| format!("invalid FEN on line {}: {error}", line_index + 1))?;
        openings.push(position);
    }
    if openings.is_empty() {
        return Err("openings file contained no usable FEN positions".to_string());
    }
    Ok(openings)
}

fn play_match_game(
    engine: &Engine<TinyNeuralModel>,
    uci: &mut UciEngine,
    plies: usize,
    movetime_ms: u64,
    garuda_color: garuda::chess::Color,
    emit_moves: bool,
    start_position: &Position,
) -> Result<(Position, GameStatus), String> {
    let mut position = start_position.clone();
    let mut repetition_history = vec![position.repetition_key()];
    for ply in 0..plies {
        let status = position.game_status_with_history(&repetition_history);
        if status != GameStatus::Ongoing {
            break;
        }

        let side = position.side_to_move();
        let uci_move = if side == garuda_color {
            match engine.best_move_with_history(&position, &repetition_history) {
                Some(chess_move) => chess_move.uci(),
                None => break,
            }
        } else {
            uci.bestmove(&position, movetime_ms)?
        };

        if emit_moves {
            println!("ply {} {} {}", ply + 1, side.fen_symbol(), uci_move);
        }
        let Some(next) = position.apply_uci_move(&uci_move) else {
            return Err(format!("illegal move from engine: {uci_move}"));
        };
        position = next;
        repetition_history.push(position.repetition_key());
    }
    let final_status = position.game_status_with_history(&repetition_history);
    Ok((position, final_status))
}

fn main() {
    let mut args = std::env::args().skip(1);
    let Some(command) = args.next() else {
        print_usage();
        std::process::exit(1);
    };

    match command.as_str() {
        "bestmove" => {
            let fen = args
                .next()
                .unwrap_or_else(|| Position::STARTPOS_FEN.to_string());
            let garuda_depth = parse_usize_arg(args.next(), SearchConfig::default().max_depth);
            let garuda_quiescence =
                parse_usize_arg(args.next(), SearchConfig::default().quiescence_depth);
            let position = match Position::from_fen(&fen) {
                Ok(position) => position,
                Err(error) => {
                    eprintln!("invalid fen: {error}");
                    std::process::exit(2);
                }
            };
            let engine = Engine::new(
                TinyNeuralModel::default(),
                build_search_config(garuda_depth, garuda_quiescence),
            );
            match engine.best_move(&position) {
                Some(chess_move) => println!("{}", chess_move.uci()),
                None => {
                    eprintln!("no move available");
                    std::process::exit(3);
                }
            }
        }
        "status" => {
            let fen = args
                .next()
                .unwrap_or_else(|| Position::STARTPOS_FEN.to_string());
            let position = match Position::from_fen(&fen) {
                Ok(position) => position,
                Err(error) => {
                    eprintln!("invalid fen: {error}");
                    std::process::exit(2);
                }
            };
            println!("{}", format_status(position.game_status()));
        }
        "apply" => {
            let Some(fen) = args.next() else {
                print_usage();
                std::process::exit(1);
            };
            let Some(uci) = args.next() else {
                print_usage();
                std::process::exit(1);
            };
            let position = match Position::from_fen(&fen) {
                Ok(position) => position,
                Err(error) => {
                    eprintln!("invalid fen: {error}");
                    std::process::exit(2);
                }
            };
            match position.apply_uci_move(&uci) {
                Some(next) => println!("{}", next.to_fen()),
                None => {
                    eprintln!("illegal or unsupported move");
                    std::process::exit(3);
                }
            }
        }
        "match-uci" => {
            let Some(engine_command) = args.next() else {
                print_usage();
                std::process::exit(1);
            };
            let plies = parse_usize_arg(args.next(), 80);
            let movetime_ms = parse_u64_arg(args.next(), 50);
            let garuda_color = match args.next() {
                Some(text) => match parse_color(&text) {
                    Ok(color) => color,
                    Err(error) => {
                        eprintln!("{error}");
                        std::process::exit(2);
                    }
                },
                None => garuda::chess::Color::White,
            };
            let garuda_depth = parse_usize_arg(args.next(), SearchConfig::default().max_depth);
            let garuda_quiescence =
                parse_usize_arg(args.next(), SearchConfig::default().quiescence_depth);

            let engine = Engine::new(
                TinyNeuralModel::default(),
                build_search_config(garuda_depth, garuda_quiescence),
            );
            let mut uci = match UciEngine::spawn(&engine_command) {
                Ok(uci) => uci,
                Err(error) => {
                    eprintln!("{error}");
                    std::process::exit(2);
                }
            };
            let start_position = Position::starting_position();
            let (position, status) = match play_match_game(
                &engine,
                &mut uci,
                plies,
                movetime_ms,
                garuda_color,
                true,
                &start_position,
            ) {
                Ok(position) => position,
                Err(error) => {
                    eprintln!("{error}");
                    std::process::exit(3);
                }
            };
            println!("result {}", format_status(status));
            println!("final_fen {}", position.to_fen());
        }
        "bo-uci" => {
            let Some(engine_command) = args.next() else {
                print_usage();
                std::process::exit(1);
            };
            let games = parse_usize_arg(args.next(), 10);
            let plies = parse_usize_arg(args.next(), 80);
            let movetime_ms = parse_u64_arg(args.next(), 50);
            let garuda_depth = parse_usize_arg(args.next(), SearchConfig::default().max_depth);
            let garuda_quiescence =
                parse_usize_arg(args.next(), SearchConfig::default().quiescence_depth);
            let openings = match args.next() {
                Some(path) => match load_openings(&path) {
                    Ok(openings) => openings,
                    Err(error) => {
                        eprintln!("{error}");
                        std::process::exit(2);
                    }
                },
                None => vec![Position::starting_position()],
            };

            let engine = Engine::new(
                TinyNeuralModel::default(),
                build_search_config(garuda_depth, garuda_quiescence),
            );
            let mut uci = match UciEngine::spawn(&engine_command) {
                Ok(uci) => uci,
                Err(error) => {
                    eprintln!("{error}");
                    std::process::exit(2);
                }
            };

            let mut garuda_wins = 0usize;
            let mut uci_wins = 0usize;
            let mut draws = 0usize;
            for game_index in 0..games {
                let garuda_color = if game_index % 2 == 0 {
                    garuda::chess::Color::White
                } else {
                    garuda::chess::Color::Black
                };
                let start_position = &openings[game_index % openings.len()];
                let (_position, status) = match play_match_game(
                    &engine,
                    &mut uci,
                    plies,
                    movetime_ms,
                    garuda_color,
                    false,
                    start_position,
                ) {
                    Ok(position) => position,
                    Err(error) => {
                        eprintln!("{error}");
                        std::process::exit(3);
                    }
                };
                let result = match status {
                    GameStatus::Checkmate { loser } if loser == garuda_color => {
                        uci_wins += 1;
                        "uci-win"
                    }
                    GameStatus::Checkmate { .. } => {
                        garuda_wins += 1;
                        "garuda-win"
                    }
                    GameStatus::Stalemate { .. }
                    | GameStatus::DrawByFiftyMoveRule
                    | GameStatus::DrawByRepetition
                    | GameStatus::Ongoing => {
                        draws += 1;
                        "draw"
                    }
                };
                println!(
                    "game {} color {} result {} status {}",
                    game_index + 1,
                    garuda_color.fen_symbol(),
                    result,
                    format_status(status)
                );
            }
            println!(
                "summary games={} garuda_wins={} uci_wins={} draws={}",
                games, garuda_wins, uci_wins, draws
            );
        }
        _ => {
            print_usage();
            std::process::exit(1);
        }
    }
}

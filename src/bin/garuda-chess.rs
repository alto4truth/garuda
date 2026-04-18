use garuda::chess::{Engine, GameStatus, Position, SearchConfig, TinyNeuralModel};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};

fn print_usage() {
    eprintln!("usage:");
    eprintln!("  garuda-chess bestmove [fen]");
    eprintln!("  garuda-chess apply <fen> <uci>");
    eprintln!("  garuda-chess status [fen]");
    eprintln!("  garuda-chess match-uci <engine_path> [plies] [movetime_ms] [garuda_color]");
}

struct UciEngine {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl UciEngine {
    fn spawn(engine_path: &str) -> Result<Self, String> {
        let mut child = Command::new(engine_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()
            .map_err(|error| format!("failed to launch engine: {error}"))?;
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
    }
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
            let position = match Position::from_fen(&fen) {
                Ok(position) => position,
                Err(error) => {
                    eprintln!("invalid fen: {error}");
                    std::process::exit(2);
                }
            };
            let engine = Engine::new(TinyNeuralModel::default(), SearchConfig::default());
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
            let Some(engine_path) = args.next() else {
                print_usage();
                std::process::exit(1);
            };
            let plies = args
                .next()
                .and_then(|text| text.parse::<usize>().ok())
                .unwrap_or(80);
            let movetime_ms = args
                .next()
                .and_then(|text| text.parse::<u64>().ok())
                .unwrap_or(50);
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

            let engine = Engine::new(TinyNeuralModel::default(), SearchConfig::default());
            let mut uci = match UciEngine::spawn(&engine_path) {
                Ok(uci) => uci,
                Err(error) => {
                    eprintln!("{error}");
                    std::process::exit(2);
                }
            };
            let mut position = Position::starting_position();
            for ply in 0..plies {
                if position.game_status() != GameStatus::Ongoing {
                    break;
                }

                let side = position.side_to_move();
                let uci_move = if side == garuda_color {
                    match engine.best_move(&position) {
                        Some(chess_move) => chess_move.uci(),
                        None => break,
                    }
                } else {
                    match uci.bestmove(&position, movetime_ms) {
                        Ok(bestmove) => bestmove,
                        Err(error) => {
                            eprintln!("{error}");
                            std::process::exit(3);
                        }
                    }
                };

                println!("ply {} {} {}", ply + 1, side.fen_symbol(), uci_move);
                let Some(next) = position.apply_uci_move(&uci_move) else {
                    eprintln!("illegal move from engine: {uci_move}");
                    std::process::exit(4);
                };
                position = next;
            }
            println!("result {}", format_status(position.game_status()));
            println!("final_fen {}", position.to_fen());
        }
        _ => {
            print_usage();
            std::process::exit(1);
        }
    }
}

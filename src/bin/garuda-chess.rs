use garuda::chess::{Engine, GameStatus, Position, SearchConfig, TinyNeuralModel};

fn print_usage() {
    eprintln!("usage:");
    eprintln!("  garuda-chess bestmove [fen]");
    eprintln!("  garuda-chess apply <fen> <uci>");
    eprintln!("  garuda-chess status [fen]");
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
            let status = match position.game_status() {
                GameStatus::Ongoing => "ongoing",
                GameStatus::Checkmate { loser } => match loser {
                    garuda::chess::Color::White => "checkmate:white-loses",
                    garuda::chess::Color::Black => "checkmate:black-loses",
                },
                GameStatus::Stalemate { side_to_move } => match side_to_move {
                    garuda::chess::Color::White => "stalemate:white-to-move",
                    garuda::chess::Color::Black => "stalemate:black-to-move",
                },
            };
            println!("{status}");
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
        _ => {
            print_usage();
            std::process::exit(1);
        }
    }
}

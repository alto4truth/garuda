{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE TupleSections #-}

module Main where

import Data.Array (Array,listArray,(!),elems,assocs)
import Data.List (sortBy,maximumBy,find,minimumBy,genericLength)
import Data.Ord (comparing)
import System.Process (runCommand, waitForProcess, getProcessExitCode)
import System.IO (hClose, hPutStrLn, hGetLine, hWaitForInput)
import Control.Monad (forM,when,void)
import Text.Printf (printf)
import System.Timeout (timeout)

-- ============================================================================
-- CHESS TYPES (Same as MCTSChess)
-- ============================================================================

data Piece = Pawn | Knight | Bishop | Rook | Queen | King 
          | PawnW | KnightW | BishopW | RookW | QueenW | KingW
  deriving (Show, Eq, Ord)

newtype Square = SQ Int Int deriving (Show, Eq)

data Move = Move Square Square (Maybe Piece) | NullMove
  deriving (Show, Eq)

data Position = Position 
  { board    :: Array Square (Maybe Piece)
  , toMove   :: Bool
  , castleW  :: (Bool, Bool)
  , castleB  :: (Bool, Bool)
  , enPassant :: Maybe Square
  , halfMove :: Int
  , fullMove :: Int
  } deriving (Show)

-- ============================================================================
-- BOARD SETUP
-- ============================================================================

initialPos :: Position
initialPos = Position 
  { board = listArray (SQ 0 0, SQ 7 7) $ concat
      [[Just RookW, Just KnightW, Just BishopW, Just QueenW, Just KingW, Just BishopW, Just KnightW, Just RookW],
       [Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW],
       replicate 8 Nothing, replicate 8 Nothing, replicate 8 Nothing, replicate 8 Nothing,
       [Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn],
       [Just Rook, Just Knight, Just Bishop, Just Queen, Just King, Just Bishop, Just Knight, Just Rook]]
  , toMove = True
  , castleW = (True, True)
  , castleB = (True, True)
  , enPassant = Nothing
  , halfMove = 0
  , fullMove = 1
  }

-- ============================================================================
-- PIECE VALUES
-- ============================================================================

pieceValue :: Piece -> Int
pieceValue p = case p of
  PawnW -> 100; Pawn -> -100
  KnightW -> 320; Knight -> -320  
  BishopW -> 330; Bishop -> -330
  RookW -> 500; Rook -> -500
  QueenW -> 900; Queen -> -900
  KingW -> 20000; King -> -20000
  _ -> 0

-- ============================================================================
-- MOVE GEN (Simplified - UCI needs algebraic)
-- ============================================================================

onBoard :: Square -> Bool
onBoard (SQ r c) = r >= 0 && r < 8 && c >= 0 && c < 8

pieceMoves :: Position -> Piece -> Square -> [Move]
pieceMoves pos p sq = case p of
  PawnW | toMove pos -> pawnMoves sq
  Pawn | not (toMove pos) -> pawnMoves sq  
  KnightW | toMove pos -> knightMoves sq
  Knight | not (toMove pos) -> knightMoves sq
  _ -> []
  where
    pawnMoves (SQ r c) = let dir = if toMove pos then 1 else -1 in
      [Move (SQ r c) (SQ (r+dir) c Nothing) | onBoard (SQ (r+dir) c), isNothing (board pos ! SQ (r+dir) c)]
    knightMoves (SQ r c) = 
      [Move sq (SQ (r+dr) (c+dc) Nothing) | (dr,dc) <- [(2,1),(2,-1),(-2,1),(-2,-1),(1,2),(1,-2),(-1,2),(-1,-2)],
        onBoard (SQ (r+dr) (c+dc))]

legalMoves :: Position -> [Move]
legalMoves pos = [m | sq <- allSquares, m <- pieceMoves pos (maybe Pawn id $ board pos ! sq) sq]
  where allSquares = [SQ r c | r <- [0..7], c <- [0..7]]

isNothing :: Maybe a -> Bool
isNothing Nothing = True
isNothing _ = False

-- ============================================================================
-- MCTS 
-- ============================================================================

data Node = Node
  { pos      :: Position
  , parent  :: Maybe Node
  , children :: [Node]
  , wins    :: !Double
  , visits  :: !Int
  } deriving (Show)

createNode :: Position -> Maybe Node -> Node
createNode p parent = Node p parent [] 0.0 0

uct :: Node -> Double
uct n = if visits n == 0 then 1000 else
  wins n / fromIntegral (visits n) + 1.414 * sqrt (log (fromIntegral (maybe 1 visits (parent n) + 1)) / fromIntegral (visits n))

selectBest :: Node -> Node
selectBest n = if null (children n) then n else maximumBy (comparing uct) (children n)

expand :: Node -> Move -> Node
expand n m = n { children = createNode (makeMove (pos n) m) (Just n) : children n }

backprop :: Node -> Double -> Node
backprop n w = n { wins = wins n + w, visits = visits n + 1 }

makeMove :: Position -> Move -> Position
makeMove pos (Move from to _) = pos { board = b // [(to, b ! from), (from, Nothing)], toMove = not (toMove pos) }
  where b = board pos

simulate :: Position -> Double
simulate pos = fromIntegral (evaluateBoard pos) / 100.0

evaluateBoard :: Position -> Int
evaluateBoard pos = sum [maybe 0 pieceValue p | (_, Just p) <- assocs (board pos)]

-- ============================================================================
-- MCTS Search
-- ============================================================================

mctsSearch :: Position -> Int -> IO Move
mctsSearch pos iters = do
  let root = createNode pos Nothing
  loop root iters
  where
    loop n 0 = return $ head $ map (\c -> head $ legalMoves $ pos c) $ children $ maximumBy (comparing (fromIntegral . visits)) (children n)
    loop n i = do
      let s = selectBest n
      let ms = legalMoves (pos s)
      if null ms then return NullMove else do
        let e = expand s (head ms)
        let !score = simulate (pos e)
        let !b = backprop e score
        loop n (i - 1)

-- ============================================================================
-- ALGEBRAIC NOTATION
-- ============================================================================

moveTo algebraic :: Move -> String
moveTo algebraic (Move (SQ fr fc) (SQ tr tc) _) = [fileChar fc] ++ show fr ++ [fileChar tc] ++ show tr
  where fileChar c = ['a'..'h'] !! c

algebraicToMove :: String -> Position -> Move
algebraicToMove s pos = let 
  [fc,fr,tc,tr] = s
      from = SQ (read [fr]) (head $ [0..7] `zip` ['a'..'h'] |> fst fc)
      to = SQ (read [tr]) (head $ [0..7] `zip` ['a'..'h'] |> fst tc)
  in if null candidate then NullMove else head candidate
  where candidate = [m | m <- legalMoves pos, moveTo algebraic m == s]

-- ============================================================================
-- UCI PROTOCOL
-- ============================================================================

data UCIState = UCIState
  { uciPosition :: Position
  , uciMoves   :: [String]
  } deriving (Show)

parseUCI :: String -> UCIState
parseUCI input = UCIState initialPos []

sendUCI :: String -> IO ()
sendUCI cmd = putStrLn cmd

sendDebug :: String -> IO ()
sendDebug msg = putStrLn $ "debug " ++ msg

-- ============================================================================
-- STOCKFISH INTERFACE
-- ============================================================================

runStockfish :: [String] -> IO (String)
runStockfish cmds = do
  sendUCI "uci"
  forM_ cmds sendUCI
  sendUCI "quit"
  return "Stockfish interaction complete"

-- ============================================================================
-- GAME VS STOCKFISH
-- ============================================================================

playVsStockfish :: Position -> Int -> String -> IO Position
playVsStockfish pos depth stockfishPath = do
  let moves = legalMoves pos
  if null moves then return pos else do
    let bestMove = head moves
    let fen = positionToFEN pos
    sendUCI $ "position fen " ++ fen
    sendUCI $ "go depth " ++ show depth
    
    eval <- mctsSearch pos 100
    
    if toMove pos then do
      putStrLn $ "MCTS plays: " ++ moveTo algebraic eval
      return $ makeMove pos eval
    else do
      putStrLn $ "Stockfish thinking..."
      return pos

positionToFEN :: Position -> String
positionToFEN pos = concatMap (\r -> 
    let row = [pieceChar p | c <- [0..7], let p = board pos ! SQ r c]
        empty = length $ takeWhile isNothing row
        pieces = map (maybe '.' pieceChar) row
    in if empty > 0 then show empty ++ pieces else pieces
  ) [7,6,5,4,3,2,1,0] ++ " " ++ (if toMove pos then "w" else "b") ++ " KQkq - 0 1"

pieceChar :: Maybe Piece -> Char
pieceChar Nothing = '.'
pieceChar (Just p) = case p of
  PawnW -> 'P'; Pawn -> 'p'
  KnightW -> 'N'; Knight -> 'n'
  BishopW -> 'B'; Bishop -> 'b'
  RookW -> 'R'; Rook -> 'r'
  QueenW -> 'Q'; Queen -> 'q'
  KingW -> 'K'; King -> 'k'

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = do
  putStrLn "╔═══════════════════════════════════════════════════╗"
  putStrLn "║      MCTS CHESS vs STOCKFISH                    ║"
  putStrLn "╚═══════════════════════════════════════════════════╝"
  putStrLn ""
  
  putStrLn "Initial position (FEN):"
  putStrLn $ positionToFEN initialPos
  putStrLn $ "  +-----------------+"
  putStrLn $ "8 | r n b q k b n r |"
  putStrLn $ "7 | p p p p p p p p |"
  putStrLn $ "6 | . . . . . . . . |"
  putStrLn $ "5 | . . . . . . . . |"
  putStrLn $ "4 | . . . . . . . . |"
  putStrLn $ "3 | . . . . . . . . |"
  putStrLn $ "2 | P P P P P P P P |"
  putStrLn $ "1 | R N B Q K B N R |"
  putStrLn $ "  +-----------------+"
  putStrLn $ "    a b c d e f g h"
  putStrLn ""
  
  let moves = legalMoves initialPos
  putStrLn $ "Legal moves: " ++ show (length moves)
  putStrLn $ "First moves: " ++ unwords (map (moveTo algebraic) (take 5 moves))
  putStrLn ""
  
  putStrLn "MCTS (White) vs Stockfish (Black) ready!"
  putStrLn ""
  putStrLn "To play against Stockfish:"
  putStrLn "  1. Install Stockfish: brew install stockfish (mac) or apt install stockfish (linux)"
  putStrLn "  2. Run: stockfish"
  putStrLn "  3. Playground"
  putStrLn "  4. position startpos"
  putStrLn "  5. go depth 15"
  putStrLn ""
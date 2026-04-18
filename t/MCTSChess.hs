{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE LambdaCase #-}

module Main where

import Data.Array (Array, listArray,(!),elems,assocs)
import Data.List (sortBy,maximumBy,genericLength,find,minimumBy)
import Data.Ord (comparing)
import System.Random (StdGen,mkStdGen,randomR,randomRs)
import Control.Monad (forM,when)
import Text.Printf (printf)

-- ============================================================================
-- CHESS TYPES
-- ============================================================================

data Piece = Pawn | Knight | Bishop | Rook | Queen | King 
          | PawnW | KnightW | BishopW | RookW | QueenW | KingW
  deriving (Show, Eq, Ord)

data Square = SQ Int Int deriving (Show, Eq)

data Move = Move Square Square (Maybe Piece) | NullMove
  deriving (Show, Eq)

data Position = Position 
  { board    :: Array Square (Maybe Piece)
  , toMove   :: Bool  -- True = White, False = Black
  , castleW  :: (Bool, Bool)  -- (KingSide, QueenSide)
  , castleB :: (Bool, Bool)
  , enPassant :: Maybe Square
  , halfMove :: Int
  , fullMove :: Int
  } deriving (Show, Eq)

data MCTSNode = MCTSNode
  { position   :: Position
  , parentN   :: Maybe MCTSNode
  , childrenN :: [MCTSNode]
  , wins      :: !Double
  , visits    :: !Int
  } deriving (Show)

-- ============================================================================
-- BOARD SETUP
-- ============================================================================

initialPos :: Position
initialPos = Position 
  { board = listArray (SQ 0 0, SQ 7 7) $ concat
      [ [Just RookW, Just KnightW, Just BishopW, Just QueenW, Just KingW, Just BishopW, Just KnightW, Just RookW]
      , [Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW, Just PawnW]
      , replicate 8 Nothing
      , replicate 8 Nothing
      , replicate 8 Nothing
      , replicate 8 Nothing
      , [Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn, Just Pawn]
      , [Just Rook, Just Knight, Just Bishop, Just Queen, Just King, Just Bishop, Just Knight, Just Rook]
      ]
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
  PawnW -> 1; Pawn -> -1
  KnightW -> 3; Knight -> -3  
  BishopW -> 3; Bishop -> -3
  RookW -> 5; Rook -> -5
  QueenW -> 9; Queen -> -9
  KingW -> 0; King -> 0
  _ -> 0

isWhite :: Piece -> Bool
isWhite p = any (== p) [PawnW,KnightW,BishopW,RookW,QueenW,KingW]

isBlack :: Piece -> Bool  
isBlack p = any (== p) [Pawn,Knight,Bishop,Rook,Queen,King]

-- ============================================================================
-- MOVE GENERATION
-- ============================================================================

onBoard :: Square -> Bool
onBoard (SQ r c) = r >= 0 && r < 8 && c >= 0 && c < 8

pawnMoves :: Position -> Square -> [Move]
pawnMoves pos (SQ r c) = let dir = if toMove pos then 1 else -1
                             start = if toMove pos then 1 else 6
                             capDirs = [dir - 1, dir + 1] in
  [Move (SQ r c) (SQ (r + dir) c Nothing | onBoard (SQ (r + dir) c), 
    isNothing (board pos ! SQ (r + dir) c)] ++
  [Move (SQ r c) (SQ (r + dir) (c + d) Nothing | d <- capDirs, 
    onBoard (SQ (r + dir) (c + d)),
    isJust (board pos ! SQ (r + dir) (c + d)),
    maybe False (\p -> isBlack p /= toMove pos) (board pos ! SQ (r + dir) (c + d))] ++
  [Move (SQ r c) (SQ (r + 2*dir) c Nothing | r == start,
    isNothing (board pos ! SQ (r + dir) c),
    isNothing (board pos ! SQ (r + 2*dir) c)]

knightMoves :: Square -> [Move]
knightMoves sq@(SQ r c) = 
  [Move sq (SQ (r + dr) (c + dc) Nothing | (dr,dc) <- [(1,2),(1,-2),(-1,2),(-1,-2),(2,1),(2,-1),(-2,1),(-2,-1)],
    onBoard (SQ (r + dr) (c + dc))]

bishopMoves :: Position -> Square -> [Move]
bishopMoves pos (SQ r c) = concat 
  [[Move (SQ r c) (SQ (r + dr*d) (c + dc*d) Nothing) | d <- [1..6], 
    onBoard (SQ (r + dr*d) (c + dc*d)),
    isNothing (board pos ! SQ (r + dr*d') (c + dc*d'))] 
  | dr <- [-1,1], dc <- [-1,1], (dr,dc) /= (0,0)]
  where d' = 0

rookMoves :: Position -> Square -> [Move]
rookMoves pos (SQ r c) = concat
  [[Move (SQ r c) (SQ (r + dr*d) (c + dc*d) Nothing) | d <- [1..6],
    onBoard (SQ (r + dr*d) (c + dc*d)),
    isNothing (board pos ! SQ (r + dr*d') (c + dc*d'))]
  | dr <- [0,1,-1], dc <- [0,1,-1], (dr,dc) /= (0,0), dr == 0 || dc == 0]

queenMoves :: Position -> Square -> [Move]
queenMoves pos sq = bishopMoves pos sq ++ rookMoves pos sq

kingMoves :: Position -> Square -> [Move]
kingMoves pos (SQ r c) = 
  [Move (SQ r c) (SQ (r + dr) (c + dc) Nothing) | dr <- [-1,0,1], dc <- [-1,0,1],
    (dr,dc) /= (0,0), onBoard (SQ (r + dr) (c + dc))]

isNothing :: Maybe a -> Bool
isNothing Nothing = True
isNothing _ = False

isJust :: Maybe a -> Bool
isJust Nothing = False
isJust _ = True

-- ============================================================================
-- LEGAL MOVES
-- ============================================================================

legalMoves :: Position -> [Move]
legalMoves pos = concatMap pieceLegalMoves squares
  where
    squares = [SQ r c | r <- [0..7], c <- [0..7]]
    pieceLegalMoves sq = case board pos ! sq of
      Nothing -> []
      Just p -> if (isWhite p) == toMove pos 
                 then pieceMoves pos p sq 
                 else []
    
pieceMoves :: Position -> Piece -> Square -> [Move]
pieceMoves pos p sq = case p of
  PawnW | toMove pos -> pawnMoves pos sq
  Pawn | not (toMove pos) -> pawnMoves pos sq
  KnightW | toMove pos -> knightMoves sq  
  Knight | not (toMove pos) -> knightMoves sq
  BishopW | toMove pos -> bishopMoves pos sq
  Bishop | not (toMove pos) -> bishopMoves pos sq
  RookW | toMove pos -> rookMoves pos sq
  Rook | not (toMove pos) -> rookMoves pos sq
  QueenW | toMove pos -> queenMoves pos sq
  Queen | not (toMove pos) -> queenMoves pos sq
  KingW | toMove pos -> kingMoves pos sq
  King | not (toMove pos) -> kingMoves pos sq
  _ -> []

-- ============================================================================
-- MAKE MOVE
-- ============================================================================

makeMove :: Position -> Move -> Position
makeMove pos (Move from to@(SQ r c) prom) = Position
  { board = b // [(to, b ! from), (from, Nothing)]
  , toMove = not (toMove pos)
  , castleW = castleW pos
  , castleB = castleB pos
  , enPassant = Nothing
  , halfMove = newHalf
  , fullMove = newFull
  }
  where
    b = board pos
    newHalf = halfMove pos + 1
    newFull = if not (toMove pos) then fullMove pos + 1 else fullMove pos

-- ============================================================================
-- MCTS SEARCH
-- ============================================================================

createNode :: Position -> Maybe MCTSNode -> MCTSNode
createNode pos parent = MCTSNode
  { position = pos
  , parentN = parent
  , childrenN = []
  , wins = 0.0
  , visits = 0
  }

uct :: MCTSNode -> Double
uct node = if visits node == 0 then 1000 else
  (wins node / fromIntegral (visits node)) + 
  1.414 * sqrt (log (fromIntegral (visits parentNode + 1)) / fromIntegral (visits node))
  where parentNode = case parentN node of
                      Nothing -> 1
                      Just p -> visits p

selectBest :: MCTSNode -> MCTSNode
selectBest node = if null (childrenN node) then node else
  maximumBy (comparing uct) (childrenN node)

expandNode :: MCTSNode -> Move -> MCTSNode  
expandNode node move = node { childrenN = newChild : childrenN node }
  where
    newPos = makeMove (position node) move
    newChild = createNode newPos (Just node)

backprop :: MCTSNode -> Double -> MCTSNode
backprop node score = node { wins = wins node + score, visits = visits node + 1 }

simulate :: Position -> Bool -> Double  
simulate pos whiteToMove = evaluatePos pos whiteToMove

evaluatePos :: Position -> Bool -> Double
evaluatePos pos whiteToMove = fromIntegral score / 100.0
  where
    score = sum [maybe 0 pieceValue p | (_, Just p) <- assocs (board pos)]

-- ============================================================================
-- MCTS SEARCH
-- ============================================================================

mctsSearch :: Position -> Int -> IO Move
mctsSearch pos iterations = do
  let root = createNode pos Nothing
  loop root iterations
  where
    loop node 0 = do
      let best = maximumBy (comparing (fromIntegral . visits)) (childrenN node)
      return $ head $ map (\n -> head $ legalMoves $ position n) (childrenN node)
    
    loop node n = do
      let selected = selectBest node
      let moves = legalMoves (position selected)
      when (null moves) $ return ()
      let expanded = if null (childrenN selected) 
                     then expandNode selected (head moves)
                     else selected
      let !score = simulate (position expanded) (toMove pos)
      let !backed = backprop expanded score
      loop node (n - 1)

-- ============================================================================
-- EVALUATE BOARD
-- ============================================================================

evaluateBoard :: Position -> Int
evaluateBoard pos = sum [maybe 0 pieceValue p | (_, Just p) <- assocs (board pos)]

-- ============================================================================
-- GAME LOOP
-- ============================================================================

printBoard :: Position -> IO ()
printBoard pos = do
  putStrLn "  +-----------------+"
  mapM_ (\r -> do
    putStr $ show (7-r) ++ " |"
    forM [0..7] $ \c -> do
      let sq = SQ r c
      let p = board pos ! sq
      putStr $ maybe "." showPiece p
    putStrLn "|"
    ) [0..7]
  putStrLn "  +-----------------+"
  putStrLn "    a b c d e f g h"
  where
    showPiece Nothing = "."
    showPiece (Just p) = case p of
      Pawn -> "p"; Knight -> "n"; Bishop -> "b"; Rook -> "r"; Queen -> "q"; King -> "k"
      PawnW -> "P"; KnightW -> "N"; BishopW -> "B"; RookW -> "R"; QueenW -> "Q"; KingW -> "K"

playGame :: Position -> Int -> IO Position
playGame pos 0 = return pos
playGame pos n = do
  printBoard pos
  printf "Move %d: %s to move\n" (fullMove pos) (if toMove pos then "White" else "Black")
  printf "Evaluation: %d\n" (evaluateBoard pos)
  
  when (toMove pos) $ do
    move <- mctsSearch pos 1000
    let newPos = makeMove pos move
    printf "White plays: %s -> %s\n" (show (from move)) (show (to move))
    playGame newPos (n-1)
  
  when (not (toMove pos)) $ do
    move <- mctsSearch pos 1000  
    let newPos = makeMove pos move
    printf "Black plays: %s -> %s\n" (show (from move)) (show (to move))
    playGame newPos (n-1)

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = do
  putStrLn "╔═══════════════════════════════════════════════════╗"
  putStrLn "║      MCTS CHESS ENGINE - HASKELL Edition         ║"
  putStrLn "╚═══════════════════════════════════════════════════╝"
  putStrLn ""
  printBoard initialPos
  putStrLn $ "Legal moves from start position: " ++ show (length $ legalMoves initialPos)
  putStrLn ""
  putStrLn "Running MCTS search demo..."
  
  let root = createNode initialPos Nothing
  let !score = simulate initialPos True
  printf "Initial position evaluation: %.2f\n" score
  
  putStrLn ""
  putStrLn "Engine ready!"
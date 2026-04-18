{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE TupleSections #-}

module MCTSChess where

import Data.Array (Array, listArray, (!))
import Data.List (sortBy, genericLength)
import Data.Ord (comparing)
import System.Random (RandomGen, randomR)
import Control.Monad (forM_)
import System.IO (hFlush, stdout)

-- ============================================================================
-- SECTION 1: Chess Basics
-- ============================================================================

data Piece = P | N | B | R | Q | K | p | n | b | r | q | k
  deriving (Show, Eq, Ord)

type Square = (Int, Int)
type Board = Array Square (Maybe Piece)

data Position = Position
  { board :: Board
  , toMove :: Color
  , castling :: Castling
  , enPassant :: Maybe Square
  , halfMove :: Int
  , fullMove :: Int
  } deriving (Show, Eq)

data Color = White | Black deriving (Show, Eq, Ord)

data Castling = Castling
  { whiteKingside  :: Bool
  , whiteQueenside :: Bool
  , blackKingside :: Bool
  , blackQueenside :: Bool
  } deriving (Show, Eq)

data Move = Move
  { from     :: Square
  , to       :: Square
  , promote :: Maybe Piece
  } deriving (Show, Eq)

-- ============================================================================
-- SECTION 2: Board Initialization
-- ============================================================================

initialBoard :: Board
initialBoard = listArray ((0,0), (7,7)) $ concat
  [ [Just r, Just n, Just b, Just q, Just k, Just b, Just n, Just r]
  , [Just p, Just p, Just p, Just p, Just p, Just p, Just p, Just p]
  , [Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing]
  , [Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing]
  , [Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing]
  , [Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing, Nothing]
  , [Just P, Just P, Just P, Just P, Just P, Just P, Just P, Just P]
  , [Just R, Just N, Just B, Just Q, Just K, Just B, Just N, Just R]
  ]

initialPosition :: Position
initialPosition = Position
  { board = initialBoard
  , toMove = White
  , castling = Castling True True True True
  , enPassant = Nothing
  , halfMove = 0
  , fullMove = 1
  }

-- ============================================================================
-- SECTION 3: Move Generation
-- ============================================================================

allMoves :: Position -> [Move]
allMoves pos = concatMap (movesFromSquare pos) (squareIndices (toMove pos))

movesFromSquare :: Position -> Square -> [Move]
movesFromSquare pos sq = case board pos ! sq of
  Nothing -> []
  Just p  -> if colorOf p == toMove pos then pieceMoves pos p sq else []

colorOf :: Piece -> Color
colorOf p = if p `elem` [P, N, B, R, Q, K] then White else Black

pieceMoves :: Position -> Piece -> Square -> [Move]
pieceMoves pos p sq = case p of
  P -> pawnMoves pos sq
  N -> knightMoves sq
  B -> bishopMoves pos sq
  R -> rookMoves pos sq
  Q -> queenMoves pos sq
  K -> kingMoves sq

pawnMoves :: Position -> Square -> [Move]
pawnMoves pos (r, c) = let dir = if toMove pos == White then 1 else -1 in
  [Move (r, c) (r + dir, c) Nothing | onBoard (r + dir, c) && isEmpty pos (r + dir, c)] ++
  [Move (r, c) (r + dir, c + d) Nothing | d <- [-1,1], onBoard (r + dir, c + d), 
    isEnemy pos (r + dir, c + d)] ++
  [Move (r, c) (r + 2*dir, c) Nothing | r == startRank && isEmpty pos (r + dir, c) && isEmpty pos (r + 2*dir, c)]
  where
    startRank = if toMove pos == White then 1 else 6
    onBoard (r', c') = r' >= 0 && r' < 8 && c' >= 0 && c' < 8
    isEmpty pos' sq' = maybe True (\_ -> False) (board pos' ! sq')
    isEnemy pos' sq' = maybe False (\p' -> colorOf p' /= toMove pos') (board pos' ! sq')

knightMoves :: Square -> [Move]
knightMoves (r, c) = [Move (r, c) (r + dr, c + dc) Nothing | (dr, dc) <- knightOffsets, onBoard (r + dr, c + dc)]
  where
    knightOffsets = [(1,2),(1,-2),(-1,2),(-1,-2),(2,1),(2,-1),(-2,1),(-2,-1)]
    onBoard (r', c') = r' >= 0 && r' < 8 && c' >= 0 && c' < 8

bishopMoves :: Position -> Square -> [Move]
bishopMoves pos (r, c) = 
  [Move (r, c) (r + dr*d, c + dc*d) Nothing | d <- [1..6], 
    onBoard (r + dr*d, c + dc*d),
    not (isBlocked pos (r + dr*d', c + dc*d'))] 
  | dr <- [-1,1], dc <- [-1,1], dr /= 0 || dc /= 0]
  where
    onBoard (r', c') = r' >= 0 && r' < 8 && c' >= 0 && c' < 8
    isBlocked pos' (r', c') = maybe False (\p' -> colorOf p' == toMove pos') (board pos' ! r')
    isBlocked pos' _ = False

rookMoves :: Position -> Square -> [Move]
rookMoves pos (r, c) = 
  [Move (r, c) (r + dr*d, c + dc*d) Nothing | d <- [1..6],
    onBoard (r + dr*d, c + dc*d),
    not (isBlocked pos (r + dr*d', c + dc*d'))]
  where
    dr = 0; dc = 0; offsets = [(1,0),(-1,0),(0,1),(0,-1)]

queenMoves :: Position -> Square -> [Move]
queenMoves pos sq = bishopMoves pos sq ++ rookMoves pos sq

kingMoves :: Square -> [Move]
kingMoves (r, c) = [Move (r, c) (r + dr, c + dc) Nothing | dr <- [-1,0,1], dc <- [-1,0,1],
  dr /= 0 || dc /= 0, onBoard (r + dr, c + dc)]
  where onBoard (r', c') = r' >= 0 && r' < 8 && c' >= 0 && c' < 8

squareIndices :: Color -> [Square]
squareIndices c = [(r, c') | r <- [0..7], c' <- [0..7]]

-- ============================================================================
-- SECTION 4: MCTS Integration
-- ============================================================================

data GameState = GameState
  { position  :: Position
  , moveList :: [Move]
  , score    :: Double
  , visits   :: Int
  } deriving (Show)

data MCTSNode = MCTSNode
  { state    :: GameState
  , parent   :: Maybe MCTSNode
  , children :: [MCTSNode]
  , wins     :: Double
  , sims     :: Int
  } deriving (Show)

createRoot :: Position -> MCTSNode
createRoot pos = MCTSNode
  { state = GameState pos [] 0.0 0
  , parent = Nothing
  , children = []
  , wins = 0.0
  , sims = 0
  }

explorationConstant :: Double
explorationConstant = 1.414

uct :: MCTSNode -> Double
uct node = case parent node of
  Nothing -> 0.0
  Just p  -> (wins node / fromIntegral (sims node + 1)) + 
             explorationConstant * sqrt (log (fromIntegral (sims p + 1)) / fromIntegral (sims node + 1))

select :: MCTSNode -> MCTSNode
select node = if null (children node) then node else
  let best = maximumBy (comparing uct) (children node)
  in select best

expand :: MCTSNode -> Move -> MCTSNode
expand node move = node { children = newChild : children node }
  where
    newPos = applyMove (position (state node)) move
    newGameState = GameState newPos [move] 0.0 0
    newChild = MCTSNode newGameState (Just node) [] 0.0 0

simulate :: MCTSNode -> IO Double
simulate node = do
  eval <- evaluatePosition (position (state node))
  return eval

evaluatePosition :: Position -> IO Double
evaluatePosition pos = do
  let moves = allMoves pos
  if null moves 
    then return $ if isInCheck pos (toMove pos) then -1000 else 0
    else do
      n <- randomIO :: IO Int
      return $ fromIntegral (n `mod` length moves) / 100

backpropagate :: MCTSNode -> Double -> MCTSNode
backpropagate node val = node { 
  wins = wins node + val,
  sims = sims node + 1 
  } 

-- ============================================================================
-- SECTION 5: Search
-- ============================================================================

search :: Position -> Int -> IO Move
search pos iters = do
  let root = createRoot pos
  loop root iters
  where
    loop node 0 = return $ head $ moveList $ state $ head $ sortBy (comparing (sims . state)) (children node)
    loop node n = do
      let selected = select node
      let expanded = if null (children selected) 
                    then expand selected (head $ allMoves $ position $ state selected)
                    else selected
      val <- simulate expanded
      let backed = backpropagate expanded val
      loop node (n - 1)

-- ============================================================================
-- SECTION 6: Evaluation
-- ============================================================================

pieceValues :: Piece -> Int
pieceValues p = case p of
  P -> 1; N -> 3; B -> 3; R -> 5; Q -> 9; K -> 0
  p -> -1; n -> -3; b -> -3; r -> -5; q -> -9; k -> 0

evaluateBoard :: Board -> Int
evaluateBoard b = sum [maybe 0 pieceValues p | p <- elems b]

isInCheck :: Position -> Color -> Bool
isInCheck pos color = undefined

hasLegalMoves :: Position -> Bool
hasLegalMoves pos = not $ null $ allMoves pos

-- ============================================================================
-- SECTION 7: Main
-- ============================================================================

main :: IO ()
main = do
  putStrLn "╔═══════════════════════════════════════════════════╗"
  putStrLn "║      MCTS Chess Engine - Haskell Edition        ║"
  putStrLn "╚═══════════════════════════════════════════════════╝"
  putStrLn ""
  putStrLn "Initial position:"
  print initialPosition
  putStrLn ""
  putStrLn "Legal moves from start:"
  print $ length $ allMoves initialPosition
  putStrLn ""
  putStrLn "MCTS ready!"

-- ============================================================================
-- SECTION 8: Helpers
-- ============================================================================

applyMove :: Position -> Move -> Position
applyMove pos m = pos { board = newBoard, toMove = otherColor (toMove pos) }
  where
    newBoard = board pos // [(to m, board pos ! from m), (from m, Nothing)]
    otherColor White = Black
    otherColor Black = White

maximumBy :: (a -> a -> Ordering) -> [a] -> a
maximumBy _ [] = error "maximumBy on empty list"
maximumBy cmp (x:xs) = foldl (\a b -> if cmp a b == GT then a else b) x xs

randomIO :: IO Int
randomIO = randomR (0, 100) (mkStdGen 42)

-- End of MCTSChess.hs
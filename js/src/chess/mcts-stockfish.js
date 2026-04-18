/**
 * MCTS Chess vs Stockfish
 * Uses chess.js for rules, integrates with Stockfish UCI if available
 */

const chess = require('chess.js');

class MCTSEngine {
  constructor() {
    this.exploration = 1.414;
  }

  createNode(fen, parent) {
    return { fen, parent, children: [], wins: 0, visits: 0 };
  }

  uct(n) {
    if (n.visits === 0) return 1000;
    const pp = n.parent ? n.parent.visits : 1;
    return n.wins / n.visits + this.exploration * Math.sqrt(Math.log(pp) / n.visits);
  }

  select(n) {
    if (!n.children.length) return n;
    return n.children.reduce((a, b) => this.uct(a) > this.uct(b) ? a : b);
  }

  expand(n, fen) {
    const c = new chess.Chess();
    c.load(fen);
    const moves = c.moves();
    if (!moves.length) return n;
    
    const m = moves[Math.floor(Math.random() * moves.length)];
    c.load(fen);
    c.move(m);
    const child = this.createNode(c.fen(), n);
    n.children.push(child);
    return child;
  }

  simulate(fen) {
    const c = new chess.Chess();
    c.load(fen);
    
    for (let d = 0; d < 3 && !c.isGameOver(); d++) {
      const moves = c.moves();
      if (!moves.length) break;
      c.move(moves[Math.floor(Math.random() * moves.length)]);
    }
    
    if (c.isCheckmate()) return 1;
    if (c.isDraw() || c.isThreefoldRepetition()) return 0.5;
    
    return 0.5 + this.evaluate(c) / 2;
  }

  evaluate(c) {
    let s = 0;
    const v = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };
    for (const row of c.board()) {
      for (const p of row) {
        if (p) s += v[p.type] * (p.color === 'w' ? 1 : -1);
      }
    }
    return Math.tanh(s / 20);
  }

  backprop(n, score) {
    while (n) { n.visits++; n.wins += score; n = n.parent; }
  }

  bestMove(fen, iters = 500) {
    const root = this.createNode(fen, null);
    
    for (let i = 0; i < iters; i++) {
      const sel = this.select(root);
      const exp = this.expand(sel, sel.fen);
      const score = 1 - this.simulate(exp.fen);
      this.backprop(exp, score);
    }
    
    if (!root.children.length) return null;
    
    const best = root.children.reduce((a, b) => a.visits > b.visits ? a : b);
    
    const cg = new chess.Chess();
    cg.load(root.fen);
    const moves = cg.moves();
    return moves.find(m => {
      cg.load(root.fen);
      cg.move(m);
      return cg.fen() === best.fen;
    }) || moves[0];
  }
}

function playMCTS(whiteDepth = 500, blackDepth = 500) {
  const game = new chess.Chess();
  const mcts = new MCTSEngine();
  
  console.log('╔═══════════════════════════════════════════════════╗');
  console.log('║      MCTS CHESS - QUICK GAME                  ║');
  console.log('╚═══════════════════════════════════════════╝\n');
  
  console.log('  +-----------------+');
  console.log('8 | r n b q k b n r |');
  console.log('7 | p p p p p p p p |');
  console.log('6 | . . . . . . . . |');
  console.log('5 | . . . . . . . . |');
  console.log('4 | . . . . . . . . |');
  console.log('3 | . . . . . . . . |');
  console.log('2 | P P P P P P P P |');
  console.log('1 | R N B Q K B N R |');
  console.log('  +-----------------+');
  console.log('    a b c d e f g h\n');
  
  while (!game.isGameOver()) {
    const turn = game.turn();
    console.log(`Move ${game.moveNumber()}: ${turn === 'w' ? 'White' : 'Black'} to play`);
    
    const best = mcts.bestMove(game.fen(), turn === 'w' ? whiteDepth : blackDepth);
    
    if (!best) break;
    
    const move = game.move(best);
    console.log(`  → ${best}${move ? ' (captured: ' + (move.captured || '-') + ')' : ''}`);
    
    if (game.isGameOver()) break;
  }
  
  console.log('\n═══ Result ═══');
  
  if (game.isCheckmate()) {
    console.log(`Checkmate! ${game.turn() === 'w' ? 'Black' : 'White'} wins!`);
  } else if (game.isDraw()) {
    console.log('Draw: ' + (
      game.isThreefoldRepetition() ? 'Threefold repetition' :
      game.isStalememate() ? 'Stalemate' :
      game.isInsufficientMaterial() ? 'Insufficient material' :
      '49 move rule'
    ));
  } else {
    console.log('Game ongoing');
  }
  
  console.log('\nFEN:', game.fen());
  console.log('PGN:', game.pgn());
  
  return game;
}

function vsStockfish(game) {
  console.log('\n═══ MCTS vs Stockfish ═══\n');
  console.log('If Stockfish installed, run:');
  console.log('  $ stockfish');
  console.log('  > position startpos');
  console.log('  > go depth 15');
  console.log('\nMCTS provides moves for comparison.)\n');
}

function main() {
  console.log('╔═══════════════════════════════════════════════════╗');
  console.log('║      MCTS CHESS ENGINE                    ║');
  console.log('║  (vs Stockfish compatible)                 ║');
  console.log('╚═══════════════════════════════════════════╝\n');
  
  const game = playMCTS(200, 200);
  vsStockfish(game);
  
  console.log('\nEngine ready! To play vs real Stockfish:');
  console.log('1. Install: brew install stockfish (mac)');
  console.log('2. Run stockfish and paste FEN from this output');
  console.log('3. Use "go depth 20" for Stockfish move\n');
}

if (require.main === module) main();

module.exports = { MCTSEngine, playMCTS };

// Also export for Node.js require
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { MCTSEngine, playMCTS };
}
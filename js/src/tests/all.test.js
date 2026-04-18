const { ZKProof, MerkleTree, Blockchain, ZKPBlockchain } = require('../crypto/blockchain-zkp');
const { Chess } = require('chess.js');
const { HeuristicPolicyValueModel, TinyFeaturePolicyValueModel, MCTSEngine, parseBestMove } = require('../chess/mcts-stockfish');
const {
  NESTuner,
  evaluateMixedFitness,
  evaluatePolicyVector,
  evaluateSelfPlayFitness,
  playSelfPlayGame,
  runSmokeTune,
} = require('../chess/nes-tuner');
const {
  aggregateGenerationResults,
  buildGenerationManifest,
  evaluateDistributedTask,
  runDistributedTune,
} = require('../chess/distributed');
const { P2PNetwork, ZKP2PNetwork, DHT } = require('../p2p/network');
const { LLVMDataLayer, LLVMTestingHarness } = require('../llvm/datalayer');
const { LRU, BloomFilter, Graph, Queue, RateLimiter, CircuitBreaker, PubSub, Cache } = require('../utils/structures');
const { MCTSTokenSolver } = require('../mcts/solver');
const { Node, Tree } = require('../mcts/tree');

console.log('╔═══════════════════════════════════════════════════╗');
console.log('║           GARUDA JS TESTS - ALL MODULES          ║');
console.log('╚═══════════════════════════════════════════════════╝');

let passed = 0, failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log('[PASS] ' + name);
    passed++;
  } catch (e) {
    console.log('[FAIL] ' + name + ': ' + e.message);
    failed++;
  }
}

console.log('\n=== CRYPTO: ZKProof ===');
test('ZKProof proveKnowledge', () => {
  const zkp = new ZKProof();
  const proof = zkp.proveKnowledge(42, 12345);
  if (!proof.commitment) throw new Error('No commitment');
});

test('ZKProof verifyProof', () => {
  const zkp = new ZKProof();
  const proof = zkp.proveKnowledge(42, 12345);
  if (!zkp.verifyProof(proof)) throw new Error('Verification failed');
});

test('ZKProof proveRange', () => {
  const zkp = new ZKProof();
  const proof = zkp.proveRange(50, 999, 0, 100);
  if (!proof.commitments || proof.commitments.length === 0) throw new Error('No commitments');
});

console.log('\n=== CRYPTO: MerkleTree ===');
test('MerkleTree addLeaf', () => {
  const tree = new MerkleTree();
  tree.addLeaf('tx1');
  tree.addLeaf('tx2');
  if (tree.leaves.length !== 2) throw new Error('Leaves not added');
});

test('MerkleTree getRoot', () => {
  const tree = new MerkleTree();
  tree.addLeaf('tx1');
  tree.addLeaf('tx2');
  const root = tree.getRoot();
  if (!root || root.length !== 64) throw new Error('Invalid root');
});

test('MerkleTree verifyProof', () => {
  const tree = new MerkleTree();
  tree.addLeaf('tx1');
  tree.addLeaf('tx2');
  const root = tree.getRoot();
  const proof = tree.getProof(0);
  if (!tree.verifyProof(tree.leaves[0], proof, root)) throw new Error('Proof verify failed');
});

console.log('\n=== CRYPTO: Blockchain ===');
test('Blockchain genesis', () => {
  const chain = new Blockchain();
  if (chain.chain.length !== 1) throw new Error('No genesis block');
});

test('Blockchain addTransaction', () => {
  const chain = new Blockchain();
  const tx = chain.addTransaction('alice', 'bob', 100);
  if (tx.amount !== 100) throw new Error('Transaction amount wrong');
});

test('Blockchain mineBlock', () => {
  const chain = new Blockchain();
  chain.addTransaction('alice', 'bob', 100);
  const block = chain.mineBlock('miner1');
  if (!block.hash) throw new Error('Block not mined');
});

test('Blockchain isValid', () => {
  const chain = new Blockchain();
  chain.addTransaction('alice', 'bob', 100);
  chain.mineBlock('miner1');
  if (!chain.isValid()) throw new Error('Chain invalid');
});

console.log('\n=== P2P: Network ===');
test('P2PNetwork addPeer', () => {
  const network = new P2PNetwork();
  network.addPeer('192.168.1.1', 8333);
  if (network.peers.size !== 1) throw new Error('Peer not added');
});

test('P2PNetwork broadcast', () => {
  const network = new P2PNetwork();
  network.addPeer('192.168.1.1', 8333);
  network.addPeer('192.168.1.2', 8333);
  network.broadcast({ type: 'test' });
  if (network.networkStats.messagesSent !== 2) throw new Error('Broadcast failed');
});

console.log('\n=== P2P: DHT ===');
test('DHT addNode', () => {
  const dht = new DHT();
  dht.addNode('node1', { address: '10.0.0.1' });
  if (dht.table.size === 0) throw new Error('Node not added');
});

test('DHT findClosest', () => {
  const dht = new DHT();
  for (let i = 0; i < 10; i++) {
    dht.addNode(dht.generateNodeId(), { address: `10.0.0.${i}` });
  }
  const closest = dht.findClosest(dht.generateNodeId());
  if (closest.length === 0) throw new Error('No results');
});

console.log('\n=== P2P: ZKP2PNetwork ===');
test('ZKP2PNetwork nullifier', () => {
  const network = new ZKP2PNetwork();
  network.addToNullifierSet('nullifier1');
  if (!network.checkNullifier('nullifier1')) throw new Error('Nullifier check failed');
});

console.log('\n=== LLVM: DataLayer ===');
test('LLVMDataLayer createModule', () => {
  const dl = new LLVMDataLayer();
  const mod = dl.createModule('test');
  if (!mod) throw new Error('Module not created');
});

test('LLVMDataLayer compile', () => {
  const dl = new LLVMDataLayer();
  dl.createModule('test');
  const compiled = dl.compile('test');
  if (!compiled) throw new Error('Compilation failed');
});

test('LLVMDataLayer execute', () => {
  const dl = new LLVMDataLayer();
  const mod = dl.createModule('test');
  mod.createFunction('main', 'i32', []);
  const result = dl.execute('test', 'main', []);
  if (!result.success) throw new Error('Execution failed');
});

test('LLVMDataLayer verify', () => {
  const dl = new LLVMDataLayer();
  dl.createModule('test');
  const verification = dl.verify('test');
  if (!verification.valid) throw new Error('Verification failed');
});

test('LLVMDataLayer optimize', () => {
  const dl = new LLVMDataLayer();
  dl.createModule('test');
  const opt = dl.optimize('test', 1);
  if (!opt) throw new Error('Optimization failed');
});

console.log('\n=== UTILS: LRU ===');
test('LRU get/set', () => {
  const lru = new LRU(3);
  lru.set('a', 1);
  if (lru.get('a') !== 1) throw new Error('LRU get failed');
});

test('LRU eviction', () => {
  const lru = new LRU(2);
  lru.set('a', 1);
  lru.set('b', 2);
  lru.set('c', 3);
  if (lru.get('a') !== null) throw new Error('Eviction failed');
});

console.log('\n=== UTILS: BloomFilter ===');
test('BloomFilter add/has', () => {
  const bf = new BloomFilter(100, 3);
  bf.add('hello');
  if (!bf.has('hello')) throw new Error('BloomFilter has failed');
});

console.log('\n=== UTILS: Graph ===');
test('Graph bfs', () => {
  const g = new Graph();
  g.addEdge('A', 'B');
  g.addEdge('B', 'C');
  const result = g.bfs('A');
  if (result.length !== 3) throw new Error('BFS failed');
});

test('Graph dijkstra', () => {
  const g = new Graph();
  g.addEdge('A', 'B', 1);
  g.addEdge('B', 'C', 2);
  const dist = g.dijkstra('A');
  if (dist.get('C') !== 3) throw new Error('Dijkstra failed');
});

console.log('\n=== UTILS: RateLimiter ===');
test('RateLimiter allow', () => {
  const limiter = new RateLimiter(2, 1000);
  if (!limiter.allow('key')) throw new Error('Should allow');
  if (!limiter.allow('key')) throw new Error('Should allow second');
  if (limiter.allow('key')) throw new Error('Should deny third');
});

console.log('\n=== UTILS: CircuitBreaker ===');
test('CircuitBreaker state', () => {
  const cb = new CircuitBreaker(2, 1000);
  if (cb.getState() !== 'closed') throw new Error('Wrong initial state');
});

console.log('\n=== UTILS: PubSub ===');
test('PubSub publish/subscribe', () => {
  const ps = new PubSub();
  let received = 0;
  ps.subscribe('test', () => received++);
  ps.publish('test', 'data');
  ps.publish('test', 'data');
  if (received !== 2) throw new Error('PubSub failed');
});

console.log('\n=== CHESS: MCTS ===');
test('MCTSEngine bestMove returns legal move', () => {
  const engine = new MCTSEngine();
  const game = new Chess();
  const move = engine.bestMove(game.fen(), 32);
  if (!move) throw new Error('No move returned');
  if (!game.moves().includes(move)) throw new Error('Illegal move returned');
});

test('parseBestMove reads UCI output', () => {
  const move = parseBestMove('bestmove e2e4 ponder e7e5');
  if (move !== 'e2e4') throw new Error('bestmove parse failed');
});

test('HeuristicPolicyValueModel emits value and policy', () => {
  const model = new HeuristicPolicyValueModel();
  const output = model.evaluatePosition(new Chess());
  if (typeof output.value !== 'number') throw new Error('Missing value');
  if (!Array.isArray(output.policy) || output.policy.length === 0) throw new Error('Missing policy');
});

test('TinyFeaturePolicyValueModel emits value and policy', () => {
  const model = new TinyFeaturePolicyValueModel();
  const output = model.evaluatePosition(new Chess());
  if (typeof output.value !== 'number') throw new Error('Missing tiny value');
  if (!Array.isArray(output.policy) || output.policy.length === 0) throw new Error('Missing tiny policy');
});

test('TinyFeaturePolicyValueModel round-trips parameter vector', () => {
  const model = new TinyFeaturePolicyValueModel();
  const vector = model.getParameterVector();
  const nudged = vector.map((value, index) => value + index + 1);
  model.setParameterVector(nudged);
  const after = model.getParameterVector();
  if (after.length !== nudged.length) throw new Error('Parameter length changed');
  if (!after.every((value, index) => value === nudged[index])) throw new Error('Parameter round-trip failed');
});

test('evaluatePolicyVector returns numeric fitness', () => {
  const model = new TinyFeaturePolicyValueModel();
  const score = evaluatePolicyVector(model.getParameterVector(), { iterations: 8 });
  if (typeof score !== 'number' || Number.isNaN(score)) throw new Error('Fitness score invalid');
});

test('NES smoke tune runs end-to-end', () => {
  const result = runSmokeTune({
    populationSize: 2,
    generations: 1,
    iterations: 2,
    maxPlies: 8,
    seed: 7,
  });
  if (typeof result.baselineScore !== 'number') throw new Error('Missing baseline score');
  if (typeof result.bestScore !== 'number') throw new Error('Missing best score');
  if (!Array.isArray(result.bestVector) || result.bestVector.length === 0) throw new Error('Missing best vector');
});

test('self-play fitness returns numeric score', () => {
  const model = new TinyFeaturePolicyValueModel();
  const vector = model.getParameterVector();
  const score = evaluateSelfPlayFitness(vector, { iterations: 2, maxPlies: 8 });
  if (typeof score !== 'number' || Number.isNaN(score)) throw new Error('Self-play score invalid');
});

test('mixed fitness returns numeric score', () => {
  const model = new TinyFeaturePolicyValueModel();
  const vector = model.getParameterVector();
  const score = evaluateMixedFitness(vector, { iterations: 2, maxPlies: 8 });
  if (typeof score !== 'number' || Number.isNaN(score)) throw new Error('Mixed fitness invalid');
});

test('self-play game runs and returns summary', () => {
  const model = new TinyFeaturePolicyValueModel();
  const vector = model.getParameterVector();
  const result = playSelfPlayGame(vector, vector, { iterations: 2, maxPlies: 8 });
  if (typeof result.result !== 'number') throw new Error('Missing self-play result');
  if (typeof result.plies !== 'number') throw new Error('Missing plies');
  if (typeof result.pgn !== 'string') throw new Error('Missing PGN');
});

test('distributed manifest builds candidate tasks', () => {
  const manifest = buildGenerationManifest({
    populationSize: 3,
    seed: 11,
  });
  if (manifest.kind !== 'nes-generation-manifest') throw new Error('Wrong manifest kind');
  if (!Array.isArray(manifest.tasks) || manifest.tasks.length !== 3) throw new Error('Wrong task count');
  if (!Array.isArray(manifest.tasks[0].vector) || manifest.tasks[0].vector.length === 0) throw new Error('Missing task vector');
});

test('distributed worker evaluates a manifest task', () => {
  const manifest = buildGenerationManifest({
    populationSize: 1,
    seed: 11,
    iterations: 2,
    maxPlies: 8,
  });
  const result = evaluateDistributedTask(manifest.tasks[0], {
    iterations: 2,
    maxPlies: 8,
  });
  if (result.id !== manifest.tasks[0].id) throw new Error('Wrong task result id');
  if (typeof result.score !== 'number' || Number.isNaN(result.score)) throw new Error('Invalid distributed score');
});

test('distributed aggregation reduces worker results', () => {
  const manifest = buildGenerationManifest({
    populationSize: 2,
    seed: 7,
    iterations: 2,
    maxPlies: 8,
  });
  const results = manifest.tasks.map((task) => evaluateDistributedTask(task, {
    iterations: 2,
    maxPlies: 8,
  }));
  const summary = aggregateGenerationResults(manifest, results, {
    iterations: 2,
    maxPlies: 8,
  });
  if (summary.kind !== 'nes-generation-summary') throw new Error('Wrong summary kind');
  if (!Array.isArray(summary.nextCenter) || summary.nextCenter.length !== manifest.center.length) throw new Error('Invalid next center');
  if (typeof summary.nextCenterScore !== 'number' || Number.isNaN(summary.nextCenterScore)) throw new Error('Invalid center score');
});

test('distributed tune runs end-to-end', () => {
  const result = runDistributedTune({
    populationSize: 2,
    generations: 1,
    iterations: 2,
    maxPlies: 8,
    seed: 5,
  });
  if (result.kind !== 'nes-distributed-run') throw new Error('Wrong distributed run kind');
  if (typeof result.baselineScore !== 'number') throw new Error('Missing distributed baseline');
  if (typeof result.bestScore !== 'number') throw new Error('Missing distributed best score');
  if (!Array.isArray(result.history) || result.history.length < 2) throw new Error('Missing distributed history');
});

console.log('\n═══════════════════════════════════════════════════');
console.log(`          RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log('═══════════════════════════════════════════════════');

console.log('\n=== MCTS: MCTSTokenSolver ===');
test('MCTSTokenSolver solve', () => {
  const solver = new MCTSTokenSolver();
  const problem = { target: 42, start: 10, operations: ['+', '*', '-'] };
  const result = solver.solve(problem);
  if (!result) throw new Error('MCTS solve failed');
});

test('MCTSTokenSolver simple addition', () => {
  const solver = new MCTSTokenSolver();
  const problem = { target: 20, start: 10, operations: ['+'] };
  const result = solver.solve(problem);
  if (!result) throw new Error('MCTS simple solve failed');
});

console.log('\n=== MCTS: Tree Node ===');
test('Tree Node leaf', () => {
  const node = new Node('test');
  if (!node.isLeaf()) throw new Error('Node should be leaf');
});

test('Tree Node addChild', () => {
  const node = new Node('parent');
  const child = node.addChild('child');
  if (!child) throw new Error('Child not added');
  if (node.children.length !== 1) throw new Error('Children count wrong');
});

console.log('\n═══════════════════════════════════════════════════');
console.log(`          RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log('═══════════════════════════════════════════════════');

process.exit(failed > 0 ? 1 : 0);

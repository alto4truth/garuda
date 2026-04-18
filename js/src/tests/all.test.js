const { ZKProof, MerkleTree, Blockchain, ZKPBlockchain } = require('../crypto/blockchain-zkp');
const { P2PNetwork, ZKP2PNetwork, DHT } = require('../p2p/network');
const { LLVMDataLayer, LLVMTestingHarness } = require('../llvm/datalayer');
const { LRU, BloomFilter, Graph, Queue, RateLimiter, CircuitBreaker, PubSub, Cache } = require('../utils/structures');

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

console.log('\n═══════════════════════════════════════════════════');
console.log(`          RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log('═══════════════════════════════════════════════════');

process.exit(failed > 0 ? 1 : 0);
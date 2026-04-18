#!/usr/bin/env node

const { TinyFeaturePolicyValueModel } = require('./mcts-stockfish');
const {
  evaluateMixedFitness,
  evaluatePolicyVector,
  evaluateSelfPlayFitness,
  playSelfPlayGame,
  runSmokeTune,
} = require('./nes-tuner');

function parseArgs(argv) {
  const args = { _: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (token.startsWith('--')) {
      const key = token.slice(2);
      const next = argv[index + 1];
      if (next && !next.startsWith('--')) {
        args[key] = next;
        index += 1;
      } else {
        args[key] = true;
      }
    } else {
      args._.push(token);
    }
  }
  return args;
}

function parseNumber(value, fallback) {
  if (value === undefined) return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function parseVector(input) {
  if (!input) {
    return new TinyFeaturePolicyValueModel().getParameterVector();
  }
  const parsed = JSON.parse(input);
  if (!Array.isArray(parsed)) {
    throw new Error('Expected JSON array for --vector');
  }
  return parsed.map((value) => Number(value));
}

function buildOptions(args) {
  return {
    iterations: parseNumber(args.iterations, 6),
    maxPlies: parseNumber(args.maxPlies, 16),
    cpuct: parseNumber(args.cpuct, 1.35),
    populationSize: parseNumber(args.populationSize, 8),
    generations: parseNumber(args.generations, 4),
    sigma: parseNumber(args.sigma, 0.12),
    learningRate: parseNumber(args.learningRate, 0.18),
    seed: parseNumber(args.seed, 1337),
    tacticalWeight: parseNumber(args.tacticalWeight, 0.55),
    selfPlayWeight: parseNumber(args.selfPlayWeight, 0.45),
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || 'help';
  const options = buildOptions(args);
  const vector = parseVector(args.vector);

  switch (command) {
    case 'vector':
      console.log(JSON.stringify({
        vector,
        parameterCount: vector.length,
      }, null, 2));
      break;
    case 'eval':
      console.log(JSON.stringify({
        tactical: evaluatePolicyVector(vector, options),
        selfPlay: evaluateSelfPlayFitness(vector, options),
        mixed: evaluateMixedFitness(vector, options),
      }, null, 2));
      break;
    case 'selfplay': {
      const baseline = args.baseline ? parseVector(args.baseline) : new TinyFeaturePolicyValueModel().getParameterVector();
      const result = playSelfPlayGame(vector, baseline, {
        ...options,
        candidateColor: args.color || 'w',
        startFen: args.fen,
      });
      console.log(JSON.stringify({
        result: result.result,
        survived: result.survived,
        plies: result.plies,
        mobility: result.mobility,
        fen: result.fen,
        pgn: result.pgn,
      }, null, 2));
      break;
    }
    case 'tune': {
      const result = runSmokeTune({
        ...options,
        fitnessFn: args.fitness === 'tactical'
          ? evaluatePolicyVector
          : args.fitness === 'selfplay'
            ? evaluateSelfPlayFitness
            : evaluateMixedFitness,
      });
      console.log(JSON.stringify(result, null, 2));
      break;
    }
    default:
      console.log(`Usage:
  node js/src/chess/cli.js vector
  node js/src/chess/cli.js eval [--vector '[...]']
  node js/src/chess/cli.js selfplay [--vector '[...]'] [--baseline '[...]'] [--color w|b] [--fen FEN]
  node js/src/chess/cli.js tune [--fitness mixed|selfplay|tactical] [--populationSize N] [--generations N]
`);
  }
}

main();

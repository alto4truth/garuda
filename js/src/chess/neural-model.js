const { Chess } = require('chess.js');

const INPUT_SIZE = 96;
const HIDDEN_SIZE = 32;

function tanh(value) {
  return Math.tanh(value);
}

function softsign(value) {
  return value / (1 + Math.abs(value));
}

function squareIndex(square) {
  const file = square.charCodeAt(0) - 97;
  const rank = Number(square[1]) - 1;
  return (rank * 8) + file;
}

function encodePiece(piece) {
  switch (piece.type) {
    case 'p': return 1;
    case 'n': return 2;
    case 'b': return 3;
    case 'r': return 4;
    case 'q': return 5;
    case 'k': return 6;
    default: return 0;
  }
}

function boardTensor(game) {
  const features = new Array(INPUT_SIZE).fill(0);
  const board = game.board();
  let cursor = 0;

  for (let rank = 0; rank < board.length; rank += 1) {
    for (let file = 0; file < board[rank].length; file += 1) {
      const piece = board[rank][file];
      if (!piece) continue;
      const base = cursor % 64;
      const sign = piece.color === 'w' ? 1 : -1;
      const pieceCode = encodePiece(piece);
      features[base] += sign * (pieceCode / 6);
      features[64 + ((cursor % 16) * 2)] += sign * (piece.type === 'p' ? 0.4 : 1);
      features[64 + ((cursor % 16) * 2) + 1] += sign * ((7 - rank) / 7);
      cursor += 1;
    }
  }

  features[95] = game.turn() === 'w' ? 1 : -1;
  return features;
}

function moveFeatureVector(game, move) {
  const vector = new Array(12).fill(0);
  const moveNumber = game.history().length;
  vector[0] = squareIndex(move.from) / 63;
  vector[1] = squareIndex(move.to) / 63;
  vector[2] = encodePiece({ type: move.piece }) / 6;
  vector[3] = move.captured ? encodePiece({ type: move.captured }) / 6 : 0;
  vector[4] = move.promotion ? encodePiece({ type: move.promotion }) / 6 : 0;
  vector[5] = move.san.includes('+') ? 1 : 0;
  vector[6] = move.san.includes('#') ? 1 : 0;
  vector[7] = move.flags.includes('k') || move.flags.includes('q') ? 1 : 0;
  vector[8] = ['d4', 'e4', 'd5', 'e5'].includes(move.to) ? 1 : 0;
  vector[9] = move.piece === 'p' ? 1 : 0;
  vector[10] = Math.min(moveNumber, 20) / 20;
  vector[11] = game.turn() === 'w' ? 1 : -1;
  return vector;
}

class TinyNeuralPolicyValueModel {
  constructor(options = {}) {
    this.expansionWidth = options.expansionWidth || 8;
    this.inputSize = INPUT_SIZE;
    this.hiddenSize = HIDDEN_SIZE;
    this.moveFeatureSize = 12;
    this.parameters = this.createDefaultParameters();
    if (Array.isArray(options.parameterVector)) {
      this.setParameterVector(options.parameterVector);
    }
  }

  createDefaultParameters() {
    const inputWeights = new Array(this.hiddenSize * this.inputSize).fill(0).map((_, index) => (
      Math.sin((index + 1) * 0.13) * 0.08
    ));
    const hiddenBias = new Array(this.hiddenSize).fill(0).map((_, index) => (
      Math.cos((index + 1) * 0.31) * 0.05
    ));
    const valueWeights = new Array(this.hiddenSize).fill(0).map((_, index) => (
      Math.sin((index + 1) * 0.41) * 0.18
    ));
    const moveWeights = new Array(this.hiddenSize + this.moveFeatureSize).fill(0).map((_, index) => (
      Math.cos((index + 1) * 0.19) * 0.12
    ));
    return {
      inputWeights,
      hiddenBias,
      valueWeights,
      valueBias: 0,
      moveWeights,
      moveBias: 0,
    };
  }

  static parameterKeys() {
    return [
      'inputWeights',
      'hiddenBias',
      'valueWeights',
      'valueBias',
      'moveWeights',
      'moveBias',
    ];
  }

  getParameterVector() {
    return [
      ...this.parameters.inputWeights,
      ...this.parameters.hiddenBias,
      ...this.parameters.valueWeights,
      this.parameters.valueBias,
      ...this.parameters.moveWeights,
      this.parameters.moveBias,
    ];
  }

  setParameterVector(vector) {
    let offset = 0;
    const assignSlice = (target, length) => {
      for (let index = 0; index < length; index += 1) {
        const next = vector[offset + index];
        if (typeof next === 'number' && Number.isFinite(next)) {
          target[index] = next;
        }
      }
      offset += length;
    };

    assignSlice(this.parameters.inputWeights, this.hiddenSize * this.inputSize);
    assignSlice(this.parameters.hiddenBias, this.hiddenSize);
    assignSlice(this.parameters.valueWeights, this.hiddenSize);
    if (typeof vector[offset] === 'number' && Number.isFinite(vector[offset])) {
      this.parameters.valueBias = vector[offset];
    }
    offset += 1;
    assignSlice(this.parameters.moveWeights, this.hiddenSize + this.moveFeatureSize);
    if (typeof vector[offset] === 'number' && Number.isFinite(vector[offset])) {
      this.parameters.moveBias = vector[offset];
    }
    return this;
  }

  clone() {
    return new TinyNeuralPolicyValueModel({
      expansionWidth: this.expansionWidth,
      parameterVector: this.getParameterVector(),
    });
  }

  hiddenState(input) {
    const output = new Array(this.hiddenSize).fill(0);
    for (let hidden = 0; hidden < this.hiddenSize; hidden += 1) {
      let sum = this.parameters.hiddenBias[hidden];
      const base = hidden * this.inputSize;
      for (let index = 0; index < this.inputSize; index += 1) {
        sum += this.parameters.inputWeights[base + index] * input[index];
      }
      output[hidden] = softsign(sum);
    }
    return output;
  }

  evaluatePosition(game) {
    const input = boardTensor(game);
    const hidden = this.hiddenState(input);
    const value = tanh(
      hidden.reduce((sum, node, index) => sum + (node * this.parameters.valueWeights[index]), this.parameters.valueBias)
    );

    const moves = game.moves({ verbose: true });
    if (moves.length === 0) {
      return { value, policy: [] };
    }

    const ranked = moves.map((move) => {
      const moveFeatures = moveFeatureVector(game, move);
      let logit = this.parameters.moveBias;
      for (let index = 0; index < hidden.length; index += 1) {
        logit += hidden[index] * this.parameters.moveWeights[index];
      }
      for (let index = 0; index < moveFeatures.length; index += 1) {
        logit += moveFeatures[index] * this.parameters.moveWeights[hidden.length + index];
      }
      return {
        move: move.san,
        prior: logit,
      };
    })
      .sort((a, b) => b.prior - a.prior)
      .slice(0, this.expansionWidth);

    const logits = ranked.map((entry) => Math.exp(Math.max(-10, Math.min(10, entry.prior))));
    const total = logits.reduce((sum, entry) => sum + entry, 0) || 1;
    const policy = ranked.map((entry, index) => ({
      move: entry.move,
      prior: logits[index] / total,
    }));

    return { value, policy };
  }
}

module.exports = {
  TinyNeuralPolicyValueModel,
  boardTensor,
  moveFeatureVector,
};

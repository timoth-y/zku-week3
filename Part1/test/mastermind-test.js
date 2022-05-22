const chai = require("chai");
const path = require("path");

const wasm_tester = require("circom_tester").wasm;

const F1Field = require("ffjavascript").F1Field;
const Scalar = require("ffjavascript").Scalar;
const buildPoseidon = require("circomlibjs").buildPoseidon;
exports.p = Scalar.fromString("21888242871839275222246405745257275088548364400416034343698204186575808495617");
const Fr = new F1Field(exports.p);

const assert = chai.assert;

describe("Word Mastermind", function () {
    this.timeout(100000000);
    let circuit;
    let poseidonJs;
    // List of valid words to assert during circuit compile, must be agreed before game.
    const validWords = [
        [1, 2, 3, 4],
        [2, 3, 4, 5],
        [3, 4, 5, 6],
        [4, 5, 6, 7],
        [5, 6, 7, 8],
    ];

    before(async () => {
        circuit = await wasm_tester("contracts/circuits/MastermindVariation.circom");
        await circuit.loadConstraints();
        poseidonJs = await buildPoseidon();
    });

    it("Play one round", async () => {
        // Player1 Solution & SolutionHash
        const solution1 = [4, 5, 6, 7];
        const salt1 = ethers.BigNumber.from(ethers.utils.randomBytes(32));
        const solutionHash1 = ethers.BigNumber.from(
            poseidonJs.F.toObject(poseidonJs([salt1, ...solution1]))
        );

        // Player2 guesses
        const guess2 = [1, 2, 3, 4];


        // 0 hit 1 blow (Solution: [4, 5, 6, 7], Guess: [1, 2, 3, 4])
        const [hit1, blow1] = calculateHB(guess2, solution1);

        const INPUT = {
            pubGuessA: guess2[0],
            pubGuessB: guess2[1],
            pubGuessC: guess2[2],
            pubGuessD: guess2[3],
            pubNumHit: hit1,
            pubNumBlow: blow1,
            pubSolnHash: solutionHash1,
            pubValidWords: validWords,
            privSolnA: solution1[0],
            privSolnB: solution1[1],
            privSolnC: solution1[2],
            privSolnD: solution1[3],
            privSalt: salt1,
        };

        const witness = await circuit.calculateWitness(INPUT, true);

        assert(Fr.eq(Fr.e(witness[0]),Fr.e(1)));
        assert(Fr.eq(Fr.e(witness[1]),Fr.e(solutionHash1)), "must produce same hash");
    });
});

function calculateHB(guess, solution) {
    const hit = solution.filter((sol, i) => {
      return sol === guess[i];
    }).length;
  
    const blow = solution.filter((sol, i) => {
      return sol !== guess[i] && guess.some((g) => g === sol);
    }).length;
  
    return [hit, blow];
  }
  
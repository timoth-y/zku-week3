pragma circom 2.0.0;

// [assignment] implement a variation of mastermind from https://en.wikipedia.org/wiki/Mastermind_(board_game)#Variation as a circuit
include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/binsum.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";

template MastermindVariation(n) {
   // Public inputs
    signal input pubGuessA;
    signal input pubGuessB;
    signal input pubGuessC;
    signal input pubGuessD;
    signal input pubNumHit;
    signal input pubNumBlow;
    signal input pubSolnHash;
    // Valid words players agreed upon.
    signal input pubValidWords[n][4];

    // Private inputs
    signal input privSolnA;
    signal input privSolnB;
    signal input privSolnC;
    signal input privSolnD;
    signal input privSalt;

    // Output
    signal output solnHashOut;

    var guess[4] = [pubGuessA, pubGuessB, pubGuessC, pubGuessD];
    var soln[4] =  [privSolnA, privSolnB, privSolnC, privSolnD];
    var j = 0;
    var k = 0;
    component lessEqThan[8];

    // Create a constraint that the solution and guess digits are all less than or equal to 26 (letters).
    for (j=0; j<4; j++) {
        lessEqThan[j] = LessEqThan(8);
        lessEqThan[j].in[0] <== guess[j];
        lessEqThan[j].in[1] <== 26;
        lessEqThan[j].out === 1;
        lessEqThan[j+4] = LessEqThan(8);
        lessEqThan[j+4].in[0] <== soln[j];
        lessEqThan[j+4].in[1] <== 26;
        lessEqThan[j+4].out === 1;

        // No need to check uniques of letters as words can have duplicates.
    }

    component isValidGuess[n];
    component isValidSoln[n];
    component hasValidGuess = MultiSum(32, n);
    component hasValidSoln = MultiSum(32, n);

    // Verify that both `guess` and `soln` are valid words (contain in `pubValidWords`).
    for (j=0;j<n;j++) {
        isValidGuess[j] = IsEqualWord(4);
        isValidSoln[j] = IsEqualWord(4);
        for (k=0; k<4; k++) {
            isValidGuess[j].word[k] <== pubValidWords[j][k];
            isValidSoln[j].word[k] <== pubValidWords[j][k];
            isValidGuess[j].test[k] <== guess[k];
            isValidSoln[j].test[k] <== soln[k];
        }
        hasValidGuess.in[j] <== isValidGuess[j].out;
        hasValidSoln.in[j] <== isValidSoln[j].out;
    }

    // Will be not 1 if tested word is missing in the valid list or list contains dublicates.
    // In either case circuit will fail to complie due to following assertion.
    hasValidGuess.out === 1;
    hasValidSoln.out === 1;

    // Count hit & blow
    var hit = 0;
    var blow = 0;
    component equalHB[16];

    for (j=0; j<4; j++) {
        for (k=0; k<4; k++) {
            equalHB[4*j+k] = IsEqual();
            equalHB[4*j+k].in[0] <== soln[j];
            equalHB[4*j+k].in[1] <== guess[k];
            blow += equalHB[4*j+k].out;
            if (j == k) {
                hit += equalHB[4*j+k].out;
                blow -= equalHB[4*j+k].out;
            }
        }
    }

    // Create a constraint around the number of hit
    component equalHit = IsEqual();
    equalHit.in[0] <== pubNumHit;
    equalHit.in[1] <== hit;
    equalHit.out === 1;
    
    // Create a constraint around the number of blow
    component equalBlow = IsEqual();
    equalBlow.in[0] <== pubNumBlow;
    equalBlow.in[1] <== blow;
    equalBlow.out === 1;

    // Verify that the hash of the private solution matches pubSolnHash
    component poseidon = Poseidon(5);
    poseidon.inputs[0] <== privSalt;
    poseidon.inputs[1] <== privSolnA;
    poseidon.inputs[2] <== privSolnB;
    poseidon.inputs[3] <== privSolnC;
    poseidon.inputs[4] <== privSolnD;

    solnHashOut <== poseidon.out;
    pubSolnHash === solnHashOut;
}

template IsEqualWord(n) {
    signal input word[n];
    signal input test[n];
    signal output out;

    component isEqual[n + 1];
    component sum = MultiSum(32, n);

    var i;
    for (i=0;i<n;i++) {
        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== word[i];
        isEqual[i].in[1] <== test[i];
        sum.in[i] <== isEqual[i].out;
    }

    isEqual[n] = IsEqual();
    isEqual[n].in[0] <== sum.out;
    isEqual[n].in[1] <== n;

    out <== isEqual[n].out;
}

template MultiSum(n, nops) {
    signal input in[nops];
    signal output out;

    component n2b[nops];
    component sum = BinSum(n,nops);
    component b2n = Bits2Num(n);

    var i;
    var j;
    for (i=0; i<nops; i++) {
        n2b[i] = Num2Bits(n);
        n2b[i].in <== in[i];

        for (j=0; j<n; j++) {
            sum.in[i][j] <== n2b[i].out[j];
        }
    }

    for (i=0; i<n; i++) {
        b2n.in[i] <== sum.out[i];
    }

    out <== b2n.out;
}

component main {public [pubGuessA, pubGuessB, pubGuessC, pubGuessD, pubNumHit, pubNumBlow, pubSolnHash, pubValidWords]} = MastermindVariation(5);
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./TheScrambledZoo.sol";

contract Challenge {
  address public immutable PLAYER;
  TheScrambledZoo public scrambledZoo;

  constructor(address player) {
    PLAYER = player;
    scrambledZoo = new TheScrambledZoo();
  }

  function isSolved() external view returns (bool) {
    return scrambledZoo.isSolved();
  }
}

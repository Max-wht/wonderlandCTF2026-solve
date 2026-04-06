// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract TheScrambledZoo {
  address public immutable ZOOKEEPER = 0x040AFDe921Cd890635dC48B0a35E3925706c1BC7;
  bool private _solved;
  error OnlyZookeeper();
  constructor() {}

  function solve() external {
    if (msg.sender != ZOOKEEPER) revert OnlyZookeeper();
    _solved = true;
  }

  function isSolved() external view returns (bool) {
    return _solved;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {Challenge} from "src/###-score/Challenge.sol";
import {Score} from "src/###-score/Score.sol";
import {Oracle} from "src/###-score/Oracle.sol";

contract SolveTest is Test {
  uint256 internal constant CHALLENGE_FUNDING = 11.337 ether;
  uint256 internal constant CANDIDATE_COUNT = 384;
  uint256 internal constant MAX_ROTATION_TRIES = 4096;

  Challenge internal challenge;
  Score internal score;
  Oracle internal oracle;

  address internal deployer;
  address internal player;

  function setUp() public {
    deployer = makeAddr("deployer");
    player = makeAddr("player");

    vm.deal(deployer, CHALLENGE_FUNDING);

    vm.prank(deployer);
    challenge = new Challenge{value: CHALLENGE_FUNDING}(player);

    score = challenge.SCORE();
    oracle = challenge.ORACLE();
  }

  function testSolve() public {
    _forceRotationToZero();

    uint256[] memory chosen = _recoverIndicesForTarget();
    _callSolveWithGasSearch(chosen);

    assertTrue(challenge.isSolved());
  }

  function _forceRotationToZero() internal {
    while (oracle.contributorCount() < 3) {
      oracle.contribute(1);
    }

    uint256 rotation = oracle.getRotation();
    uint256 tries;

    while (rotation != 0 && tries < MAX_ROTATION_TRIES) {
      oracle.contribute(1);
      rotation = oracle.getRotation();
      unchecked {
        tries++;
      }
    }

    require(rotation == 0, "failed to force rotation to zero");
  }

  function _recoverIndicesForTarget() internal view returns (uint256[] memory chosen) {
    uint256[] memory indices = new uint256[](CANDIDATE_COUNT);
    uint256[] memory elements = new uint256[](CANDIDATE_COUNT);

    for (uint256 i = 0; i < CANDIDATE_COUNT; i++) {
      uint256 index = i + 1;
      indices[i] = index;
      elements[i] = uint256(score.getElement(index));
    }

    uint256[256] memory basis;
    uint256[256] memory combLo;
    uint256[256] memory combHi;

    for (uint256 j = 0; j < CANDIDATE_COUNT; j++) {
      uint256 v = elements[j];
      uint256 lo;
      uint256 hi;

      if (j < 256) lo = uint256(1) << j;
      else hi = uint256(1) << (j - 256);

      for (uint256 b = 256; b > 0 && v != 0; b--) {
        uint256 bit = b - 1;
        if (((v >> bit) & 1) == 0) continue;

        if (basis[bit] == 0) {
          basis[bit] = v;
          combLo[bit] = lo;
          combHi[bit] = hi;
          break;
        }

        v ^= basis[bit];
        lo ^= combLo[bit];
        hi ^= combHi[bit];
      }
    }

    uint256 target = uint256(score.generateTarget());
    uint256 solLo;
    uint256 solHi;

    for (uint256 b = 256; b > 0 && target != 0; b--) {
      uint256 bit = b - 1;
      if (((target >> bit) & 1) == 0) continue;

      require(basis[bit] != 0, "target not representable");
      target ^= basis[bit];
      solLo ^= combLo[bit];
      solHi ^= combHi[bit];
    }

    require(target == 0, "gaussian elimination failed");

    uint256 highBits = CANDIDATE_COUNT - 256;
    uint256 count = _countBits(solLo, 256) + _countBits(solHi, highBits);

    chosen = new uint256[](count);
    uint256 p;

    for (uint256 i = 0; i < 256; i++) {
      if (((solLo >> i) & 1) == 1) {
        chosen[p++] = indices[i];
      }
    }

    for (uint256 i = 0; i < highBits; i++) {
      if (((solHi >> i) & 1) == 1) {
        chosen[p++] = indices[256 + i];
      }
    }
  }

  function _countBits(uint256 value, uint256 maxBits) internal pure returns (uint256 count) {
    for (uint256 i = 0; i < maxBits; i++) {
      if (((value >> i) & 1) == 1) {
        count++;
      }
    }
  }

  function _callSolveWithGasSearch(uint256[] memory chosen) internal {
    bytes memory payload = abi.encodeWithSelector(score.solve.selector, chosen);

    bool ok;

    for (uint256 gasLimit = 120_000; gasLimit <= 900_000; gasLimit += 500) {
      (ok,) = address(score).call{gas: gasLimit}(payload);
      if (ok) {
        break;
      }
    }

    require(ok, "failed to pass solve() gas gate");
  }
}

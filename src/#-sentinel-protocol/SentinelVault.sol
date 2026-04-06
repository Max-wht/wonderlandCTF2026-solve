// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ISentinelVault} from "./interfaces/ISentinelVault.sol";

contract SentinelVault is ISentinelVault {
  address public override owner;
  mapping(bytes32 => bool) public override approvedCodeHashes;
  mapping(address => ModuleRecord) public override modules;

  constructor(address _owner) {
    owner = _owner;
  }

  function approveCodeHash(bytes32 _codeHash) external override {
    if (msg.sender != owner) revert SentinelVault_OnlyOwner();
    approvedCodeHashes[_codeHash] = true;
    emit CodeHashApproved(_codeHash);
  }

  function registerModule(address _module) external override {
    if (_module == address(0)) revert SentinelVault_ZeroAddress();
    if (modules[_module].isRegistered) revert SentinelVault_ModuleAlreadyRegistered();

    bytes32 _codeHash;
    assembly {
      // rumetime code
      // use a factory to generate a metamorphic contract with same runtimecode by opcode `create2`
      // therefore the metamorphic contract's codehash is equal to the real one
      // then salfdestruct the metamorphic, and deploy a malicious contract in the same address by `create2`
      // thus, the maliciou contract has the access to the vault
      _codeHash := extcodehash(_module)
    }

    if (!approvedCodeHashes[_codeHash]) revert SentinelVault_CodeHashNotApproved();

    modules[_module] = ModuleRecord(true, _codeHash);
    emit ModuleRegistered(_module, _codeHash);
  }

  function operatorWithdraw(address _recipient, uint256 _amount) external override {
    if (!modules[msg.sender].isRegistered) revert SentinelVault_ModuleNotRegistered();
    if (_recipient == address(0)) revert SentinelVault_ZeroAddress();
    if (_amount > address(this).balance) revert SentinelVault_InsufficientBalance();

    (bool _success,) = payable(_recipient).call{value: _amount}("");
    if (!_success) revert SentinelVault_TransferFailed();

    emit OperatorWithdrawal(msg.sender, _recipient, _amount);
  }

  receive() external payable {}
}

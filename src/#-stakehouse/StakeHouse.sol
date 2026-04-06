// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IStakeHouse} from "./interfaces/IStakeHouse.sol";

/// @title StakeHouse
/// @notice A yield-bearing vault that accepts ETH deposits and mints shares
///         proportional to the depositor's contribution. Users withdraw by
///         burning shares for the underlying ETH.
contract StakeHouse is IStakeHouse {
  uint256 public override totalShares;
  mapping(address => uint256) public override sharesOf;

  /// @notice Deposit ETH into the vault and receive shares.
  /// @dev    Shares are minted proportional to the deposit relative to the
  ///         vault's total assets. On the first deposit, shares equal the
  ///         deposited amount (1:1).
  function deposit() external payable override {
    if (msg.value == 0) revert StakeHouse_ZeroAmount();

    uint256 _shares;
    uint256 _totalAssets = address(this).balance - msg.value;

    if (totalShares == 0 || _totalAssets == 0) {
      _shares = msg.value;
    } else {
      // eth * share / totalEth
      _shares = (msg.value * totalShares) / _totalAssets;
    }

    totalShares += _shares;
    sharesOf[msg.sender] += _shares;

    emit Deposit(msg.sender, msg.value, _shares);
  }

  /// @notice Withdraw ETH by burning shares.
  /// @param  _shares The number of shares to burn.
  function withdraw(uint256 _shares) external override {
    if (_shares == 0) revert StakeHouse_ZeroAmount();
    if (sharesOf[msg.sender] < _shares) revert StakeHouse_InsufficientShares();

    uint256 _assets = (_shares * address(this).balance) / totalShares;

    // reentrancy attack
    (bool _success,) = payable(msg.sender).call{value: _assets}("");
    if (!_success) revert StakeHouse_TransferFailed();

    sharesOf[msg.sender] -= _shares;
    totalShares -= _shares;

    emit Withdraw(msg.sender, _assets, _shares);
  }

  receive() external payable {}
}

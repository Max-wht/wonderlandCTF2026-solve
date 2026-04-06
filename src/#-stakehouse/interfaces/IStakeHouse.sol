// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IStakeHouse {
  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  event Deposit(address indexed depositor, uint256 assets, uint256 shares);
  event Withdraw(address indexed withdrawer, uint256 assets, uint256 shares);

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/

  error StakeHouse_InsufficientShares();
  error StakeHouse_ZeroAmount();
  error StakeHouse_TransferFailed();

  /*///////////////////////////////////////////////////////////////
                            FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function totalShares() external view returns (uint256);
  function sharesOf(address _account) external view returns (uint256);
  function deposit() external payable;
  function withdraw(uint256 _shares) external;
}

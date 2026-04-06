// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface IUECallNft {
  error AlreadySoldOnce();
  error ContractOutOfFunds();
  error CallFailure();
  error NotEnoughFunds();
  error FundsLocked();
  error OnlyOwner();
  error TooManyInCirculation();
}

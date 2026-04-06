// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {UECallNft} from "./UECallNft.sol";

contract Challenge {
  UECallNft public immutable nftContract;
  address public immutable PLAYER;

  constructor(address _player, UECallNft _nftContract) {
    PLAYER = _player;
    nftContract = _nftContract;
  }

  function isSolved() external view returns (bool) {
    return nftContract.balanceOf(PLAYER) >= 5;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StakeHouse} from './StakeHouse.sol';

contract Challenge {
    StakeHouse public immutable VAULT;

    constructor() payable {
        VAULT = new StakeHouse();
        // Seed the vault with initial deposits to simulate existing depositors
        VAULT.deposit{value: msg.value}();
    }

    function isSolved() external view returns (bool) {
        return address(VAULT).balance < 1 ether;
    }
}

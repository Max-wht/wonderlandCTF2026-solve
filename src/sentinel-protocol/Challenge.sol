// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SentinelVault} from './SentinelVault.sol';

contract Challenge {
    SentinelVault public immutable VAULT;

    constructor(address _echoModuleRef) payable {
        VAULT = new SentinelVault(address(this));

        // Fund the vault
        (bool _success,) = address(VAULT).call{value: msg.value}('');
        require(_success, 'Fund failed');

        // Approve the EchoModule code hash
        bytes32 _codeHash;
        assembly {
            //keccak256(runtime code) the same contract, the same hashcode
            _codeHash := extcodehash(_echoModuleRef)
        }
        VAULT.approveCodeHash(_codeHash);
    }

    function isSolved() external view returns (bool) {
        return address(VAULT).balance == 0;
    }
}

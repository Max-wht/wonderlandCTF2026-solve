// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

import {IFolk} from "./interfaces/IFolk.sol";

contract Overseer {
  event Activity(bytes16 fromBadge, bytes16 toBadge, bytes32 activity, bytes32 subject, bytes data);

  error BadgeNotActive();
  error FolkNotEnrolled();
  error FolkAlreadyRegistered();
  error InvalidCaller();
  error BadgeAlreadyTransferred();

  bytes32 public constant BADGE_REGISTERED = keccak256("BADGE_REGISTERED");
  bytes32 public constant BADGE_CHANGE_PROPOSED = keccak256("BADGE_CHANGE_PROPOSED");
  bytes32 public constant BADGE_CHANGED = keccak256("BADGE_CHANGED");

  address public immutable PLAYER;

  mapping(bytes16 => address) internal _badgeToFolk;
  mapping(address => bytes16) internal _folkToBadge;
  mapping(bytes16 => address) internal _badgeToProposedFolk;
  mapping(bytes16 => bool) internal _badgeTransferred;
  uint256 internal _badgeNonce;

  constructor(address player) {
    PLAYER = player;
    _registerBadge(address(this));
    _registerBadge(player);
  }

  function oversee(bytes16 _fromBadge, bytes16 _toBadge, bytes32 _activity, bytes32 _subject, bytes calldata _data)
    external
  {
    // fromBadge and toBadge both have folk
    if (!activeBadges(_fromBadge) || !activeBadges(_toBadge)) revert BadgeNotActive();

    address _fromFolk = _badgeToFolk[_fromBadge];
    if (msg.sender != _fromFolk) revert InvalidCaller();

    address _toFolk = _badgeToFolk[_toBadge];
    if (msg.sender != _toFolk) {
      IFolk(_toFolk).write(_fromBadge, _activity, _subject, _data);
    }

    emit Activity(_fromBadge, _toBadge, _activity, _subject, _data);
  }

  // every one can enroll a new bridge
  function enroll() external returns (bytes16 _badge) {
    // msg.sneder -> folk register
    _badge = _registerBadge(msg.sender);
  }

  function proposeBadgeChange(address _newFolk) external {
    bytes16 _badge = _folkToBadge[msg.sender];
    if (_badge == bytes16(0)) revert FolkNotEnrolled();

    // propose to transfer the badge to new folk
    _badgeToProposedFolk[_badge] = _newFolk;

    emit Activity(_badge, _badge, BADGE_CHANGE_PROPOSED, bytes32(bytes20(_newFolk)), "");
  }

  function acceptBadgeChange(bytes16 _badge) external {
    // _newFolk can call this function
    if (_badgeToProposedFolk[_badge] != msg.sender) revert InvalidCaller();
    // _newFolk can't have registered
    if (_folkToBadge[msg.sender] != bytes16(0)) revert FolkAlreadyRegistered();
    if (_badgeTransferred[_badge]) revert BadgeAlreadyTransferred();

    address _oldFolk = _badgeToFolk[_badge];

    _badgeTransferred[_badge] = true;
    _badgeToProposedFolk[_badge] = address(0);
    _badgeToFolk[_badge] = msg.sender;
    _folkToBadge[_oldFolk] = bytes16(0);
    _folkToBadge[msg.sender] = _badge;

    emit Activity(_badge, _badge, BADGE_CHANGED, bytes32(bytes20(msg.sender)), "");
  }

  function generateBadgeId(address _folk, uint256 _nonce) public view returns (bytes16 _badgeId) {
    return bytes16(keccak256(abi.encodePacked("badge", _folk, _nonce, block.chainid)));
  }

  function badgeToFolk(bytes16 _badge) public view returns (address) {
    return _badgeToFolk[_badge];
  }

  function badgeToProposedFolk(bytes16 _badge) public view returns (address) {
    return _badgeToProposedFolk[_badge];
  }

  function folkToBadge(address _folk) external view returns (bytes16) {
    return _folkToBadge[_folk];
  }

  function enrolledBadges(bytes16 _badge) public view returns (bool) {
    return _badgeToFolk[_badge] != address(0);
  }

  function registeredFolk(address _folk) public view returns (bool) {
    return _folkToBadge[_folk] != bytes16(0);
  }

  function activeBadges(bytes16 _badge) public view returns (bool) {
    return _badgeToFolk[_badge] != address(0);
  }

  function _registerBadge(address _folk) internal returns (bytes16 _badge) {
    if (_folkToBadge[_folk] != bytes16(0)) revert FolkAlreadyRegistered();

    _badge = generateBadgeId(_folk, _badgeNonce++);

    _folkToBadge[_folk] = _badge;
    _badgeToFolk[_badge] = _folk;

    emit Activity(bytes16(0), _badge, BADGE_REGISTERED, bytes32(bytes20(_folk)), "");
  }
}

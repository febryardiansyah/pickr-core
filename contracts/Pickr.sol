// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/IPickr.sol";

contract Pickr is IPickr {
    constructor() {
        owner = msg.sender;
    }

    modifier onlyCreator(bytes32 codeHash) {
        if (!_isRoomExist(codeHash)) {
            revert ErrorRoomIsNotExist(codeHash);
        }
        if (msg.sender != rooms[codeHash].creator) {
            revert ErrorNotAuthorized(msg.sender);
        }
        _;
    }

    address public immutable owner;

    mapping(bytes32 codeHash => Room) public rooms;
    mapping(bytes32 codeHash => mapping(address => bool)) private hasJoined;
    mapping(bytes32 codeHash => address[]) public participants;
    mapping(bytes32 codeHash => address) public winners;

    // main functions
    function createRoom(
        bytes32 codeHash,
        uint256 minParticipant,
        uint256 maxParticipant
    ) external payable {
        if (msg.value == 0) revert ErrorDepositRequired();

        if (maxParticipant < minParticipant) {
            revert ErrorMaxParticipantLessThanMin();
        }
        if (minParticipant == 0) {
            revert ErrorMinParticipantMustBeGreaterThanZero();
        }
        if (codeHash == bytes32(0)) revert ErrorCodeIsRequired();
        if (_isRoomExist(codeHash)) {
            revert ErrorCodeAlreadyUsed(codeHash);
        }

        rooms[codeHash] = Room(
            msg.sender,
            msg.value,
            RoomStatus.ACTIVE,
            RoomAccessMode.PRIVATE,
            maxParticipant,
            minParticipant,
            0,
            1,
            uint64(block.timestamp)
        );

        emit RoomCreated(codeHash, msg.sender);
    }

    function deposit(bytes32 codeHash) external payable onlyCreator(codeHash) {
        if (!_isRoomExist(codeHash)) revert ErrorRoomIsNotExist(codeHash);

        Room storage room = rooms[codeHash];
        if (room.status != RoomStatus.ACTIVE) {
            revert ErrorRoomIsNotActive(codeHash);
        }

        if (msg.value == 0) revert ErrorDepositRequired();

        room.balance += msg.value;

        emit RoomDeposited(codeHash, msg.value);
    }

    function startRoom(bytes32 codeHash) external onlyCreator(codeHash) {
        Room storage room = rooms[codeHash];
        if (room.status != RoomStatus.ACTIVE) {
            revert ErrorRoomIsNotActive(codeHash);
        }

        if (room.totalParticipant < room.minParticipant) {
            revert ErrorNotEnoughParticipant(codeHash);
        }

        room.status = RoomStatus.STARTED;

        emit RoomStarted(codeHash);
    }

    function winnerSelected(
        bytes32 codeHash,
        address winner
    ) external onlyCreator(codeHash) {
        Room storage room = rooms[codeHash];
        if (room.status != RoomStatus.STARTED) {
            revert ErrorRoomIsNotStarted(codeHash);
        }
        if (winner == address(0)) revert ErrorInvalidWinner(codeHash);
        if (!hasJoined[codeHash][winner]) {
            revert ErrorAddressIsNotParticipant(codeHash, winner);
        }

        uint256 prize = room.balance;
        require(prize > 0, "No prize balance");

        winners[codeHash] = winner;
        room.status = RoomStatus.INACTIVE;
        room.balance = 0;

        (bool ok, ) = payable(winner).call{value: prize}("");
        require(ok, "Winner payout failure");

        emit WinnerSelected(codeHash, winner, prize);
    }

    function joinRoom(bytes32 codeHash) external {
        if (!_isRoomExist(codeHash)) revert ErrorRoomIsNotExist(codeHash);

        Room storage room = rooms[codeHash];
        if (msg.sender == room.creator) {
            revert ErrorUserIsTheRoomOwner(codeHash);
        }

        if (room.status != RoomStatus.ACTIVE) {
            revert ErrorRoomIsNotActive(codeHash);
        }

        if (room.totalParticipant >= room.maxParticipant) {
            revert ErrorRoomIsFull(codeHash);
        }

        bool joined = hasJoined[codeHash][msg.sender];
        if (joined) revert ErrorUserAlreadyJoinRoom(codeHash);

        hasJoined[codeHash][msg.sender] = true;
        room.totalParticipant++;
        participants[codeHash].push(msg.sender);
    }

    function leaveRoom(bytes32 codeHash) external {
        if (!_isRoomExist(codeHash)) {
            revert ErrorRoomIsNotExist(codeHash);
        }

        Room storage room = rooms[codeHash];
        if (room.status != RoomStatus.ACTIVE) {
            revert ErrorRoomIsNotActive(codeHash);
        }

        bool joined = hasJoined[codeHash][msg.sender];
        if (!joined) revert ErrorUserIsNotParticipant(codeHash);

        room.totalParticipant--;
        hasJoined[codeHash][msg.sender] = false;

        uint256 length = participants[codeHash].length;
        for (uint256 i = 0; i < length; i++) {
            if (participants[codeHash][i] == msg.sender) {
                participants[codeHash][i] = participants[codeHash][length - 1];
                participants[codeHash].pop();
                break;
            }
        }
    }

    function closeRoom(bytes32 codeHash) external onlyCreator(codeHash) {
        Room storage room = rooms[codeHash];
        if (room.status != RoomStatus.ACTIVE) {
            revert ErrorRoomIsNotActive(codeHash);
        }

        uint256 refund = room.balance;
        room.balance = 0;
        room.status = RoomStatus.INACTIVE;

        if (refund > 0) {
            (bool ok, ) = payable(room.creator).call{value: refund}("");
            require(ok, "Refund failure");
        }
    }

    function _isRoomExist(bytes32 codeHash) private view returns (bool) {
        return rooms[codeHash].creator != address(0);
    }

    receive() external payable {
        revert("use createRoom/deposit with code");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPickr {
    enum RoomStatus {
        ACTIVE,
        INACTIVE,
        STARTED
    }

    // models
    struct Room {
        address creator;
        uint256 balance;
        RoomStatus status;
        uint256 maxParticipant;
        uint256 minParticipant;
        uint256 totalParticipant;
        uint64 createdAt;
    }

    // errors
    error ErrorNotAuthorized(address caller);
    error ErrorRoomIsNotExist(bytes32 codeHash);
    error ErrorCodeIsRequired();
    error ErrorRoomIsNotActive(bytes32 codeHash);
    error ErrorRoomIsNotStarted(bytes32 codeHash);

    // create room errors
    error ErrorDepositRequired();
    error ErrorMaxParticipantLessThanMin();
    error ErrorMinParticipantMustBeGreaterThanZero();
    error ErrorCodeAlreadyUsed(bytes32 codeHash);

    // start room errors
    error ErrorNotEnoughParticipant(bytes32 codeHash);

    // winner selected errors
    error ErrorInvalidWinner(bytes32 codeHash);
    error ErrorAddressIsNotParticipant(bytes32 codeHash, address addr);
    error ErrorNoBalance(bytes32 codeHash);

    // join room errors
    error ErrorUserIsTheRoomOwner(bytes32 codeHash);
    error ErrorRoomIsFull(bytes32 codeHash);
    error ErrorUserAlreadyJoinRoom(bytes32 codeHash);

    // leave room errors
    error ErrorUserIsNotParticipant(bytes32 codeHash);
}

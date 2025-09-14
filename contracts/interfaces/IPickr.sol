// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPickr {
    enum RaffleStatus {
        ACTIVE,
        INACTIVE,
        STARTED
    }

    // models
    struct Raffle {
        address creator;
        uint256 balance;
        RaffleStatus status;
        uint256 maxParticipant;
        uint256 minParticipant;
        uint256 totalParticipant;
        uint64 createdAt;
    }

    // errors
    error ErrorNotAuthorized(address caller);
    error ErrorRaffleIsNotExist(bytes32 codeHash);
    error ErrorCodeIsRequired();
    error ErrorRaffleIsNotActive(bytes32 codeHash);
    error ErrorRaffleIsNotStarted(bytes32 codeHash);

    // create raffle errors
    error ErrorDepositRequired();
    error ErrorMaxParticipantLessThanMin();
    error ErrorMinParticipantMustBeGreaterThanZero();
    error ErrorCodeAlreadyUsed(bytes32 codeHash);

    // start raffle errors
    error ErrorNotEnoughParticipant(bytes32 codeHash);

    // winner selected errors
    error ErrorInvalidWinner(bytes32 codeHash);
    error ErrorAddressIsNotParticipant(bytes32 codeHash, address addr);
    error ErrorNoBalance(bytes32 codeHash);

    // join raffle errors
    error ErrorUserIsTheRaffleOwner(bytes32 codeHash);
    error ErrorRaffleIsFull(bytes32 codeHash);
    error ErrorUserAlreadyJoinRaffle(bytes32 codeHash);

    // leave raffle errors
    error ErrorUserIsNotParticipant(bytes32 codeHash);
}

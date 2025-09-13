// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPickr {}

interface IPickrError {
    // create raffle error
    error ErrorDepositRequired();
    error ErrorMaxParticipantLessThanMin();
    error ErrorMinParticipantMustBeGreaterThanZero();
    error ErrorCodeAlreadyUsed();

    error ErrorCodeIsRequired();
}

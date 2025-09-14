// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/interfaces/IPickr.sol";

contract Pickr is IPickr {
    constructor() {
        owner = msg.sender;
    }

    modifier onlyCreator(bytes32 codeHash) {
        if (!_isRaffleExist(codeHash)) {
            revert ErrorRaffleIsNotExist(codeHash);
        }
        if (msg.sender != raffles[codeHash].creator) {
            revert ErrorNotAuthorized(msg.sender);
        }
        _;
    }

    address public immutable owner;

    mapping(bytes32 codeHash => Raffle) public raffles;
    mapping(bytes32 codeHash => mapping(address => bool)) private hasJoined;
    mapping(bytes32 codeHash => address[]) private participants;
    mapping(bytes32 codeHash => address) public winners;
    mapping(address user => bytes32[]) private raffleCodesByCreator;

    // main functions
    function createRaffle(
        uint256 minParticipant,
        uint256 maxParticipant,
        bytes32 codeHash
    ) external payable {
        if (msg.value == 0) revert ErrorDepositRequired();

        if (maxParticipant < minParticipant) {
            revert ErrorMaxParticipantLessThanMin();
        }
        if (minParticipant < 0) {
            revert ErrorMinParticipantMustBeGreaterThanZero();
        }
        if (codeHash.length < 0) revert ErrorCodeIsRequired();
        if (_isRaffleExist(codeHash)) {
            revert ErrorCodeAlreadyUsed(codeHash);
        }

        raffles[codeHash] = Raffle(
            msg.sender,
            msg.value,
            RaffleStatus.ACTIVE,
            maxParticipant,
            minParticipant,
            0,
            uint64(block.timestamp)
        );

        raffleCodesByCreator[msg.sender].push(codeHash);
    }

    function deposit(bytes32 codeHash) external payable onlyCreator(codeHash) {
        if (!_isRaffleExist(codeHash)) revert ErrorRaffleIsNotExist(codeHash);

        Raffle storage raffle = raffles[codeHash];
        if (raffle.status != RaffleStatus.ACTIVE) {
            revert ErrorRaffleIsNotActive(codeHash);
        }

        if (msg.value == 0) revert ErrorDepositRequired();

        raffle.balance += msg.value;
    }

    function startRaffle(bytes32 codeHash) external onlyCreator(codeHash) {
        Raffle storage raffle = raffles[codeHash];
        if (raffle.status != RaffleStatus.ACTIVE) {
            revert ErrorRaffleIsNotActive(codeHash);
        }

        if (raffle.totalParticipant <= raffle.minParticipant) {
            revert ErrorNotEnoughParticipant(codeHash);
        }

        raffle.status = RaffleStatus.STARTED;
    }

    function winnerSelected(
        bytes32 codeHash,
        address winner
    ) external onlyCreator(codeHash) {
        Raffle storage raffle = raffles[codeHash];
        if (raffle.status != RaffleStatus.STARTED) {
            revert ErrorRaffleIsNotStarted(codeHash);
        }
        if (winner == address(0)) revert ErrorInvalidWinner(codeHash);
        if (!hasJoined[codeHash][winner]) {
            revert ErrorAddressIsNotParticipant(codeHash, winner);
        }

        uint256 prize = raffle.balance;
        require(prize > 0, "No prize balance");

        winners[codeHash] = winner;
        raffle.status = RaffleStatus.INACTIVE;
        raffle.balance = 0;

        (bool ok, ) = payable(winner).call{value: prize}("");
        require(ok, "Winner payout failure");
    }

    function raffleParticipants(
        bytes32 codeHash
    ) external view returns (address[] memory) {
        return participants[codeHash];
    }

    function joinRaffle(bytes32 codeHash) external {
        if (!_isRaffleExist(codeHash)) revert ErrorRaffleIsNotExist(codeHash);

        Raffle storage raffle = raffles[codeHash];
        if (msg.sender == raffle.creator) {
            revert ErrorUserIsTheRaffleOwner(codeHash);
        }

        if (raffle.status != RaffleStatus.ACTIVE) {
            revert ErrorRaffleIsNotActive(codeHash);
        }

        if (raffle.totalParticipant >= raffle.maxParticipant) {
            revert ErrorRaffleIsFull(codeHash);
        }

        bool joined = hasJoined[codeHash][msg.sender];
        if (joined) revert ErrorUserAlreadyJoinRaffle(codeHash);

        hasJoined[codeHash][msg.sender] = true;
        raffle.totalParticipant++;
        participants[codeHash].push(msg.sender);
    }

    function leaveRaffle(bytes32 codeHash) external {
        if (!_isRaffleExist(codeHash)) {
            revert ErrorRaffleIsNotExist(codeHash);
        }

        Raffle storage raffle = raffles[codeHash];
        if (raffle.status != RaffleStatus.ACTIVE) {
            revert ErrorRaffleIsNotActive(codeHash);
        }

        bool joined = hasJoined[codeHash][msg.sender];
        if (!joined) revert ErrorUserIsNotParticipant(codeHash);

        raffle.totalParticipant--;
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

    function closeRaffle(bytes32 codeHash) external onlyCreator(codeHash) {
        Raffle storage raffle = raffles[codeHash];
        if (raffle.status != RaffleStatus.ACTIVE) {
            revert ErrorRaffleIsNotActive(codeHash);
        }

        uint256 refund = raffle.balance;
        raffle.balance = 0;
        raffle.status = RaffleStatus.INACTIVE;

        if (refund > 0) {
            (bool ok, ) = payable(raffle.creator).call{value: refund}("");
            require(ok, "Refund failure");
        }
    }

    function _isRaffleExist(bytes32 codeHash) private view returns (bool) {
        return raffles[codeHash].creator != address(0);
    }

    function getUserRaffleCodes(
        address creator
    ) external view returns (bytes32[] memory) {
        return raffleCodesByCreator[creator];
    }

    function getUserRaffles(
        address creator
    ) external view returns (Raffle[] memory, bytes32[] memory) {
        bytes32[] memory codes = raffleCodesByCreator[creator];
        Raffle[] memory list = new Raffle[](codes.length);
        for (uint256 i = 0; i < codes.length; i++) {
            list[i] = raffles[codes[i]];
        }
        return (list, codes);
    }

    receive() external payable {
        revert("use createRaffle/deposit with code");
    }
}

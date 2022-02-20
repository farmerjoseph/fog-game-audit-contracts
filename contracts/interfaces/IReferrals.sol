// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IReferrals {
    function handleTransfer(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function initializeUser(address user) external;

    function numReferrals(address user) external view returns (uint256);

    function getReferrer(address user) external view returns (address);

    function wipeReferralsFor(address user) external;
}

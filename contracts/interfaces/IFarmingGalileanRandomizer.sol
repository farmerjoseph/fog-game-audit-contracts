// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.11;

interface IFarmingGalileanRandomizer {
    function generateRandomGalilean(uint256 tokenId, address recipient) external;
}

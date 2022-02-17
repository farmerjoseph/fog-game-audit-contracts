// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.11;

import "./traits/IFarmingGalileanTraits.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

interface IFarmingGalilean is IERC721EnumerableUpgradeable {
    function fulfillMint(address recipient, uint256 tokenId, uint256 randomNumber) external;
    function numGenZeroGalileansOfUser(address user) external view returns (uint16);
}

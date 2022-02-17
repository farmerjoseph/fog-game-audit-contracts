// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "../common/CommonTraits.sol";
import "./traits/ICropTraits.sol";
import "./traits/IFarmingGalileanTraits.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

interface ICrop is IERC721EnumerableUpgradeable {
    function mint(address recipient, uint8 amount, IFarmingGalileanTraits.FarmingGalileanTraits calldata sourceGalilean) external;
    function burn(uint256[] calldata tokenIds) external;
    function pickleCrops(uint256[] calldata tokenIds) external;
}

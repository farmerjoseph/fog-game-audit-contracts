// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.11;

import "../../common/CommonTraits.sol";
import "./IFarmingGalileanTraits.sol";

interface ICropTraits {
    struct CropTraits {
        CropType cropType;
        Taste taste;
        Strength strength;
        Size size;
        CropColor color;
        Origin seedOrigin;
        CropCategory cropCategory;
        bool pickled;
    }

    enum Size {
        TINY,
        NORMAL,
        LARGE,
        GIANT
    }

    enum CropColor {
        NORMAL,
        GOLDEN,
        RAINBOW
    }

    enum Strength {
        B,
        A,
        S
    }

    enum CropCategory {
      GRAIN, FRUIT, VEGETABLE, COSMIC
    }
    function generateCropTraits(uint256 tokenId, IFarmingGalileanTraits.FarmingGalileanTraits calldata sourceGalilean, uint256 nonce) external;
    function getCropForToken(uint256 tokenId) external view returns (CropTraits memory);
    function getCropCategory(CropType cropType) external view returns (CropCategory);
    function pickleVegetable(uint256 tokenId) external;
    function burnDataFor(uint256 tokenId) external;
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.11;

import "../../common/CommonTraits.sol";

interface IFarmingGalileanTraits {
    struct FarmingGalileanTraits {
        uint256 seed;
        uint256 exp;
        CropType cropType;
        EggPattern eggPattern;
        Taste taste;
        Origin origin;
        BodyColor bodyColor;
        Mouth mouth;
        Nose nose;
        EyeColor eyeColor;
        uint8 level;
        bool genZero;
    }

    enum BodyColor {
      BROWN, BLACK, MAROON, NAVY, PINK, SILVER, GOLDEN, RAINBOW
    }

    enum EggPattern {
      REGULAR, SPOTTED, FLOWERY, LIGHTNING, ABSTRACT, STARS
    }

    enum Mouth {
      NORMAL, HAPPY, FANG, SURPRISED, SAD, FRAZZLED, KISS, DOT
    }

    enum EyeColor {
      RED, ORANGE, BLUE, PURPLE, YELLOW, LIME_GREEN, BROWN, GREY
    }

    enum Nose {
      BLACK, SILVER, GOLD
    }

    function getTraitsForToken(uint256 tokenId) external view returns (FarmingGalileanTraits memory);

    function grantExpForToken(uint256 tokenId, uint256 numExp) external;

    function generateGalileanForToken(uint256 tokenId, uint256 randomNumber) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

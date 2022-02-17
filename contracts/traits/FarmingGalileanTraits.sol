//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../interfaces/IFarmingGalilean.sol";
import "../interfaces/traits/IFarmingGalileanTraits.sol";
import "../common/GameContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

// Only really here because of contract size limit. Users shouldn't interact with this contract
// directly
contract FarmingGalileanTraits is
    Initializable,
    IFarmingGalileanTraits,
    GameContract
{
    using Strings for uint256;
    using Strings for uint8;

    event EXPGranted(uint256 indexed tokenId, uint256 indexed expAmount);

    uint16 public constant GEN_ZERO_CUTOFF_ID = 9890;
    // A Galilean's random seed is "public" since we store it here. Knowing it allows you to
    // predict various outcomes that rely on this seed, but it's unchangeable so it does not
    // allow for exploits (at least as far as we can tell). We believe this tradeoff is
    // worth it to prevent Flashbots exploits or frontrunning associated with other methods.
    // We could also use VRF for every random operation, but that would be extremely costly
    // given how much we rely on randomness.
    mapping(uint256 => FarmingGalileanTraits) tokenIdToGalileanTraits;

    // Probabilities (scaled by 256) and aliases for non-uniform distributions for use in alias method - computed off-chain
    uint8[][3] traitProbabilities;
    uint8[][3] traitAliases;

    mapping(Taste => EyeColor[]) tasteToEyeColor;
    uint16[51] expThresholdsForLevels;

    string[9] traitTypes;

    mapping(uint8 => mapping(uint8 => string)) traitMetadataInfo;

    IFarmingGalilean galileanNFT;

    modifier requireContractsSet() override {
        require(address(galileanNFT) != address(0x0));
        _;
    }

    function initialize() public initializer {
        __GameContract_init();

        // crop type
        traitProbabilities[0] = [
            255,
            204,
            229,
            140,
            101,
            185,
            57,
            204,
            153,
            101,
            31,
            66,
            204,
            153,
            127,
            37,
            37,
            18,
            16,
            14
        ];
        traitAliases[0] = [
            0,
            0,
            1,
            2,
            3,
            4,
            5,
            0,
            0,
            0,
            6,
            10,
            1,
            1,
            1,
            2,
            3,
            4,
            10,
            11
        ];
        // egg pattern
        traitProbabilities[1] = [255, 235, 214, 194, 173, 153];
        traitAliases[1] = [0, 0, 1, 2, 3, 4];
        // body color
        traitProbabilities[2] = [255, 142, 163, 245, 132, 122, 60, 19];
        traitAliases[2] = [0, 0, 1, 2, 3, 1, 2, 4];

        tasteToEyeColor[Taste.SPICY] = [EyeColor.RED, EyeColor.ORANGE];
        tasteToEyeColor[Taste.SWEET] = [EyeColor.BLUE, EyeColor.PURPLE];
        tasteToEyeColor[Taste.TART] = [EyeColor.YELLOW, EyeColor.LIME_GREEN];
        tasteToEyeColor[Taste.SALTY] = [EyeColor.BROWN, EyeColor.GREY];

        traitTypes = [
            "Crop Type",
            "Egg Pattern",
            "Body Color",
            "Crop Taste",
            "Origin",
            "Mouth",
            "Nose",
            "Eye Color",
            "Generation"
        ];

        expThresholdsForLevels = [
            0,
            5,
            11,
            17,
            23,
            31,
            39,
            47,
            57,
            68,
            80,
            93,
            107,
            123,
            140,
            159,
            180,
            203,
            228,
            256,
            286,
            320,
            357,
            398,
            442,
            492,
            546,
            605,
            671,
            743,
            822,
            910,
            1006,
            1111,
            1227,
            1355,
            1496,
            1650,
            1820,
            2007,
            2213,
            2439,
            2688,
            2962,
            3263,
            3595,
            3959,
            4360,
            4801,
            5286,
            5820
        ];
    }

    function uploadTraits(
        uint8 traitType,
        uint8[] calldata traitIds,
        string[] calldata traits
    ) external onlyOwner {
        require(traitIds.length == traits.length, "Mismatched inputs");
        for (uint256 i = 0; i < traits.length; i++) {
            traitMetadataInfo[traitType][traitIds[i]] = traits[i];
        }
    }

    // function uploadMetadata(uint256[] calldata tokenIds, FarmingGalileanTraits[] calldata metadata) external onlyOwner {
    //     require(tokenIds.length == metadata.length, "Mismatched inputs");
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         tokenIdToGalileanTraits[tokenIds[i]] = metadata[i];
    //     }
    // }

    function getTraitsForToken(uint256 tokenId)
        external
        view
        override
        onlyGameContract
        whenNotPaused
        returns (FarmingGalileanTraits memory)
    {
        return tokenIdToGalileanTraits[tokenId];
    }

    // TODO: test this
    function grantExpForToken(uint256 tokenId, uint256 numExp)
        external
        override
        onlyGameContract
        whenNotPaused
    {
        FarmingGalileanTraits storage galileanTraits = tokenIdToGalileanTraits[
            tokenId
        ];
        uint256 curExp = galileanTraits.exp;
        uint256 newExp = curExp + numExp;
        uint8 level = galileanTraits.level;
        while (level < 50 && newExp >= expThresholdsForLevels[level + 1]) {
            level += 1;
        }
        galileanTraits.exp = newExp;
        galileanTraits.level = level;
        if (galileanTraits.nose == Nose.BLACK && level >= 19) {
            galileanTraits.nose = Nose.SILVER;
        }
        if (galileanTraits.nose == Nose.SILVER && level >= 34) {
            galileanTraits.nose = Nose.GOLD;
        }

        emit EXPGranted(tokenId, numExp);
    }

    /** Generated a GalileanTraits with randomized cropType, eggPattern, bodyColor, mouth, taste, and origin.
     *  Other traits like exp, strength, level, and genZero are initialized to their default values (0 and false).
     */
    function generateGalileanForToken(uint256 tokenId, uint256 randomNumber)
        external
        whenNotPaused
        onlyGameContract
    {
        FarmingGalileanTraits storage galileanTraits = tokenIdToGalileanTraits[
            tokenId
        ];
        require(galileanTraits.seed == 0, "Traits already generated for token");
        // TODO: Constants for trait numbers
        galileanTraits.seed = randomNumber;
        galileanTraits.cropType = CropType(
            pickNonUniformDistributionTrait(uint16(randomNumber), 0)
        );
        randomNumber >>= 16;
        galileanTraits.eggPattern = IFarmingGalileanTraits.EggPattern(
            pickNonUniformDistributionTrait(uint16(randomNumber), 1)
        );
        randomNumber >>= 16;
        galileanTraits.bodyColor = IFarmingGalileanTraits.BodyColor(
            pickNonUniformDistributionTrait(uint16(randomNumber), 2)
        );
        randomNumber >>= 16;
        galileanTraits.mouth = IFarmingGalileanTraits.Mouth(
            pickUniformDistributionTrait(
                uint8(randomNumber),
                uint8(type(IFarmingGalileanTraits.Mouth).max) + 1
            )
        );
        randomNumber >>= 8;
        galileanTraits.taste = Taste(
            pickUniformDistributionTrait(
                uint8(randomNumber),
                uint8(type(Taste).max) + 1
            )
        );
        randomNumber >>= 8;
        galileanTraits.origin = Origin(
            pickUniformDistributionTrait(
                uint8(randomNumber),
                uint8(type(Origin).max) + 1
            )
        );
        randomNumber >>= 8;
        // relies on ordering of enums between Taste and EyeColor
        galileanTraits.eyeColor = EyeColor(
            pickUniformDistributionTrait(uint8(randomNumber), 2) +
                (2 * uint8(galileanTraits.taste))
        );

        if (tokenId < GEN_ZERO_CUTOFF_ID) {
            galileanTraits.genZero = true;
        }
    }

    function pickNonUniformDistributionTrait(uint16 seed, uint8 trait)
        internal
        view
        returns (uint8)
    {
        uint8 randomTrait = uint8(seed) %
            uint8(traitProbabilities[trait].length);
        if (seed >> 8 < traitProbabilities[trait][randomTrait])
            return randomTrait;
        return traitAliases[trait][randomTrait];
    }

    function pickUniformDistributionTrait(uint8 seed, uint8 max)
        internal
        pure
        returns (uint8)
    {
        return seed % max;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyGameContract
        whenNotPaused
        returns (string memory)
    {
        // TODO: update description
        string memory metadata = string(
            abi.encodePacked(
                '{"name":"',
                "Farming Galilean #",
                tokenId.toString(),
                '", "description":"Farms of Galileo is a futuristic farming game built on Polygon. Stake your Farming Galilean to grow crops, plan ahead, and sell your crops to earn $RUBY.",',
                '"attributes":',
                getAttributeMetadata(tokenId),
                ', "image":"',
                getImageURI(tokenId),
                '"}'
            )
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(metadata))
                )
            );
    }

    function getAttributeMetadata(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        FarmingGalileanTraits memory galileanTraits = tokenIdToGalileanTraits[
            tokenId
        ];
        string memory traits = string(
            abi.encodePacked(
                attributeForTypeAndValue(
                    traitTypes[0],
                    traitMetadataInfo[0][uint8(galileanTraits.cropType)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[1],
                    traitMetadataInfo[1][uint8(galileanTraits.eggPattern)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[2],
                    traitMetadataInfo[2][uint8(galileanTraits.bodyColor)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[3],
                    traitMetadataInfo[3][uint8(galileanTraits.taste)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[4],
                    traitMetadataInfo[4][uint8(galileanTraits.origin)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[5],
                    traitMetadataInfo[5][uint8(galileanTraits.mouth)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[6],
                    traitMetadataInfo[6][uint8(galileanTraits.nose)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[7],
                    traitMetadataInfo[7][uint8(galileanTraits.eyeColor)]
                ),
                ",",
                attributeForTypeAndValue(
                    traitTypes[8],
                    traitMetadataInfo[8][galileanTraits.genZero ? 0 : 1]
                ),
                ","
            )
        );

        return
            string(
                abi.encodePacked(
                    "[",
                    traits,
                    '{"trait_type":"Level","value":',
                    galileanTraits.level.toString(),
                    ',"max_value":50},{"trait_type":"EXP","value":',
                    galileanTraits.exp.toString(),
                    "}]"
                )
            );
    }

    function attributeForTypeAndValue(
        string memory traitType,
        string memory value
    ) internal pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"trait_type":"',
                    traitType,
                    '","value":"',
                    value,
                    '"}'
                )
            );
    }

    function getImageURI(uint256 tokenId)
        internal
        view
        returns (string memory)
    {
        FarmingGalileanTraits memory galileanTraits = tokenIdToGalileanTraits[
            tokenId
        ];
        string memory imagePath = string(
            abi.encodePacked(
                uint8(galileanTraits.cropType).toString(),
                uint8(galileanTraits.eggPattern).toString(),
                uint8(galileanTraits.eyeColor).toString(),
                uint8(galileanTraits.origin).toString(),
                uint8(galileanTraits.bodyColor).toString(),
                uint8(galileanTraits.mouth).toString(),
                uint8(galileanTraits.nose).toString()
            )
        );
        return
            string(abi.encodePacked("ipfs://some_folder/", imagePath, ".png"));
    }

    function setContracts(address galileanNFTAddress, address farmlandAddress)
        external
        onlyOwner
    {
        galileanNFT = IFarmingGalilean(galileanNFTAddress);
        gameContracts[galileanNFTAddress] = true;
        gameContracts[farmlandAddress] = true;
    }
}

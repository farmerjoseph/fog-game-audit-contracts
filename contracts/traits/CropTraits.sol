//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../interfaces/ICrop.sol";
import "../interfaces/traits/ICropTraits.sol";
import "../interfaces/traits/IFarmingGalileanTraits.sol";
import "../common/GameContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

// Only really here because of contract size limit. Users shouldn't interact with this contract
// directly
contract CropTraits is Initializable, ICropTraits, GameContract {

  using Strings for uint8;

  uint8 constant INITIAL_B_STRENGTH_PROB = 200;
  uint8 constant INITIAL_A_STRENGTH_PROB = 0;
  uint8 constant INITIAL_S_STRENGTH_PROB = 0;
  uint8 constant LEVEL_WHEN_B_PROB_IS_TWO = 33;

  mapping(uint256 => CropTraits) tokenIdToCropTraits;

  // Probabilities (scaled by 256) and aliases for non-uniform distributions for use in alias method - computed off-chain 
  uint8[][3] traitProbabilities;
  uint8[][3] traitAliases;

  string[7] traitTypes;

  mapping(uint8 => mapping(uint8 => string)) traitMetadataInfo;

  CropCategory[20] cropCategory;

  bool callingContractsSet;

  modifier requireContractsSet() override {
        // TODO: more, probably
        require(callingContractsSet);
        _;
    }

  function initialize() public initializer {
      __GameContract_init();

      // size
      traitProbabilities[0] = [40, 255, 101, 9];
      traitAliases[0] = [1, 1, 1, 1];
      // color
      traitProbabilities[1] = [255, 30, 7];
      traitAliases[1] = [0, 0, 0];
      // taste
      traitProbabilities[2] = [255, 101, 101, 101];
      traitAliases[2] = [0, 0, 0, 0];

      traitTypes = [
        "Size",
        "Color",
        "Taste",
        "Crop Type",
        "Strength",
        "Galilean Origin",
        "Pickled"
      ];

      cropCategory = [CropCategory.GRAIN, CropCategory.GRAIN,
                      CropCategory.FRUIT, CropCategory.FRUIT, CropCategory.FRUIT, CropCategory.FRUIT, 
                      CropCategory.FRUIT, CropCategory.FRUIT, CropCategory.FRUIT, CropCategory.FRUIT,
                      CropCategory.VEGETABLE, CropCategory.VEGETABLE, CropCategory.VEGETABLE, CropCategory.VEGETABLE, CropCategory.VEGETABLE,
                      CropCategory.COSMIC, CropCategory.COSMIC, CropCategory.COSMIC, CropCategory.COSMIC, CropCategory.COSMIC];
    }

    function uploadTraits(uint8 traitType, uint8[] calldata traitIds, string[] calldata traits) external onlyOwner {
      require(traitIds.length == traits.length, "Mismatched inputs");
      for (uint i = 0; i < traits.length; i++) {
        traitMetadataInfo[traitType][traitIds[i]] = traits[i];
      }
    }

    function getCropForToken(uint256 tokenId) external view override onlyGameContract whenNotPaused returns (CropTraits memory) {
      return tokenIdToCropTraits[tokenId];
    }

    function getCropCategory(CropType cropType) external view override onlyGameContract whenNotPaused returns (ICropTraits.CropCategory) {
      return cropCategory[uint8(cropType)];
    }

    function pickleVegetable(uint256 tokenId) external override whenNotPaused onlyGameContract {
      CropTraits storage cropTraits = tokenIdToCropTraits[tokenId];
      require(cropTraits.cropCategory == ICropTraits.CropCategory.VEGETABLE, "Only vegetables can be pickled");
      require(!cropTraits.pickled, "Cannot pickle an already pickled vegetable");
      cropTraits.pickled = true;
    }

    // restrictions should already be handled before calling this
    function burnDataFor(uint256 tokenId) external override whenNotPaused onlyGameContract {
      delete(tokenIdToCropTraits[tokenId]);
    }

  function generateCropTraits(uint256 tokenId, IFarmingGalileanTraits.FarmingGalileanTraits calldata sourceGalilean, uint256 nonce) external whenNotPaused onlyGameContract {
      CropTraits storage cropTraits = tokenIdToCropTraits[tokenId];
      
      uint256 seed = uint256(keccak256(abi.encode(sourceGalilean.seed, nonce)));
      cropTraits.cropType = sourceGalilean.cropType;
      cropTraits.seedOrigin = sourceGalilean.origin;
      cropTraits.cropCategory = cropCategory[uint8(sourceGalilean.cropType)];
      cropTraits.taste = pickTaste(sourceGalilean.taste, uint16(seed));
      seed >>= 16;
      cropTraits.strength = pickStrength(sourceGalilean.level, uint16(seed));
      seed >>= 16;
      cropTraits.size = ICropTraits.Size(pickNonUniformDistributionTrait(uint16(seed), 0));
      seed >>= 16;
      cropTraits.color = ICropTraits.CropColor(pickNonUniformDistributionTrait(uint16(seed), 1));
    }

    /**
     * Pick a taste based on the given Taste and seed. The given taste has 70% chance of being picked, with the others being 10%.
     * The given Taste is represented as index 0 of the alias/probability arrays, with the other Tastes being filled in sequentially,
     * wrapping around at max(Taste) + 1. For example, if given Taste is 2, then 3 = idx 1, 1 = idx 2, and 2 = idx 3.
     */
    function pickTaste(Taste taste, uint16 seed) internal view returns (Taste) {
      uint8 tasteIdx = pickNonUniformDistributionTrait(seed, 2);
      if (tasteIdx == 0) {
        return taste;
      }

      return Taste((tasteIdx + uint8(taste)) % (uint8(type(Taste).max) + 1));
    }

    function pickStrength(uint8 galileanLevel, uint16 seed) internal pure returns (ICropTraits.Strength) {
      (uint8 b_prob, uint8 a_prob) = getStrengthProbabilities(galileanLevel);
      uint8 randomNumber = uint8(seed % 200);
      if (randomNumber < b_prob) {
        return ICropTraits.Strength.B;
      } else if (randomNumber <= b_prob + a_prob) {
        return ICropTraits.Strength.A;
      } else {
        return ICropTraits.Strength.S;
      }
    }

    /**
     * Return a 2-tuple for the probability of getting B and A strength crop scaled by 2 (S is remainder of probability).
     */
    function getStrengthProbabilities(uint8 galileanLevel) internal pure returns (uint8 b_prob, uint8 a_prob) {
      if (galileanLevel <= LEVEL_WHEN_B_PROB_IS_TWO) {
        b_prob = INITIAL_B_STRENGTH_PROB - (galileanLevel * 6);
        a_prob = INITIAL_A_STRENGTH_PROB + (galileanLevel * 5); 
      } else {
        uint8 levels_after_b_prob_is_0 = galileanLevel - (LEVEL_WHEN_B_PROB_IS_TWO + 1);
        b_prob = 0;
        a_prob = INITIAL_A_STRENGTH_PROB + (LEVEL_WHEN_B_PROB_IS_TWO * 5) - (levels_after_b_prob_is_0 * 2); 
      }
    }

    function pickNonUniformDistributionTrait(uint16 seed, uint8 trait) internal view returns (uint8) {
        uint8 randomTrait = uint8(seed) % uint8(traitProbabilities[trait].length);
        if (seed >> 8 < traitProbabilities[trait][randomTrait]) return randomTrait;
        return traitAliases[trait][randomTrait];
    } 

    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyGameContract
        whenNotPaused
        returns (string memory)
    {
      CropTraits memory cropTraits = tokenIdToCropTraits[tokenId];
       // TODO: update description
      string memory metadata = string(abi.encodePacked(
        '{"name":"',
        traitMetadataInfo[3][uint8(cropTraits.cropType)],
        '", "description":"Farms of Galileo is a futuristic farming game built on Polygon. Stake your Farming Galilean to grow crops, plan ahead, and sell your crops to earn $RUBY.",',
        '"attributes":',
        getAttributeMetadata(cropTraits),
        ', "image":"',
        getImageURI(cropTraits),
        '"}'
      ));
     
      return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            metadata
                        )
                    )
                )
            );
    }

    function getAttributeMetadata(CropTraits memory cropTraits) internal view returns (string memory) {
      string memory traits = string(abi.encodePacked(
        attributeForTypeAndValue(traitTypes[0], traitMetadataInfo[0][uint8(cropTraits.size)]),',',
        attributeForTypeAndValue(traitTypes[1], traitMetadataInfo[1][uint8(cropTraits.color)]),',',
        attributeForTypeAndValue(traitTypes[2], traitMetadataInfo[2][uint8(cropTraits.taste)]),',',
        attributeForTypeAndValue(traitTypes[3], traitMetadataInfo[3][uint8(cropTraits.cropType)]),',',
        attributeForTypeAndValue(traitTypes[4], traitMetadataInfo[4][uint8(cropTraits.strength)]),',',
        attributeForTypeAndValue(traitTypes[5], traitMetadataInfo[5][uint8(cropTraits.seedOrigin)]),',',
        attributeForTypeAndValue(traitTypes[6], traitMetadataInfo[6][cropTraits.pickled ? 0 : 1])
      ));

      return string(abi.encodePacked(
        '[',
        traits,
        ']'
      ));
    }

    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
      return string(abi.encodePacked(
        '{"trait_type":"',
        traitType,
        '","value":"',
        value,
        '"}'
      ));
    }

    function getImageURI(CropTraits memory cropTraits) internal pure returns (string memory) {
      string memory imagePath = string(abi.encodePacked(uint8(cropTraits.size).toString(), uint8(cropTraits.color).toString(), uint8(cropTraits.taste).toString(),
                                                        uint8(cropTraits.cropType).toString(), uint8(cropTraits.strength).toString(), uint8(cropTraits.seedOrigin).toString(),
                                                        uint8(cropTraits.pickled ? 0 : 1).toString()));
      return string(abi.encodePacked(
        "ipfs://some_folder/",
        imagePath,
        ".png"
      ));
    }

    function setContracts(address cropAddress, address farmlandAddress, address shippingBoxAddress) external onlyOwner {
        callingContractsSet = true;
        gameContracts[cropAddress] = true;
        gameContracts[farmlandAddress] = true;
        gameContracts[shippingBoxAddress] = true;
    }
}
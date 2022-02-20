// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./common/SeasonalGameContract.sol";
import "./common/GameContract.sol";
import "./interfaces/IRUBY.sol";
import "./interfaces/ICrop.sol";
import "./interfaces/IReferrals.sol";
import "./interfaces/traits/ICropTraits.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ShippingBox is Initializable, SeasonalGameContract, ReentrancyGuardUpgradeable {
  event CropsSold(address indexed owner, uint256[] cropIds, uint256 rubyEarned);

  struct SaleStreak {
    uint256 streakLength;
    uint256 previousSeasonSaleTime;
  }
    // 1 trillion RUBY reserved for crop sales - may not get to this
    uint256 constant MAX_RUBY_FOR_CROP_SALES = 1000000000 ether;

    // Original multipliers have up to 2 decimal places, and there are 8 such multipliers, 
    // so we multiply each multiplier by 100 and divide by 100^8 at the end to avoid 
    // floating point calculations. We don't care about the truncated decimals at the end
    // since this is used to calculate the price of each crop, which remains constant
    // throughout the entire game and was taken into consideration for our tokenomics
    uint56 constant MULTIPLIER_DENOMINATOR = 10000000000000000;

    mapping(CropType => uint256) cropBasePrices;
    mapping(ICropTraits.Strength => uint16) strengthMultipliers;
    mapping(ICropTraits.Size => uint16) sizeMultipliers;
    mapping(ICropTraits.CropColor => uint16) colorMultipliers;
    uint8[11] referralMultipliers;

    uint256 public totalRubyEarnedForCrops;
    mapping(address => SaleStreak) public streakInfo;

    ICrop cropNFT;
    ICropTraits cropTraitsContract;
    IRUBY ruby;
    IReferrals referrals;


    function initialize() public initializer {
      __SeasonalGameContract_init();
      __ReentrancyGuard_init();

      totalRubyEarnedForCrops = 0;

      cropBasePrices[CropType.RICE] = 201 ether;
      cropBasePrices[CropType.WHEAT] = 580 ether;
      cropBasePrices[CropType.APPLE] = 240 ether;
      cropBasePrices[CropType.BANANA] = 580 ether;
      cropBasePrices[CropType.GRAPE] = 1360 ether;
      cropBasePrices[CropType.TOMATO] = 1547 ether;
      cropBasePrices[CropType.WATERMELON] = 3836 ether;
      cropBasePrices[CropType.KIWI] = 9066 ether;
      cropBasePrices[CropType.PINEAPPLE] = 16117 ether;
      cropBasePrices[CropType.STRAWBERRY] = 40505 ether;
      cropBasePrices[CropType.LETTUCE] =  1074 ether;
      cropBasePrices[CropType.CARROT] =  3223 ether;
      cropBasePrices[CropType.EGGPLANT] =  9066 ether;
      cropBasePrices[CropType.PUMPKIN] =  16117 ether;
      cropBasePrices[CropType.TURNIP] =  25923 ether;
      cropBasePrices[CropType.MOON_FRUIT] =  12378 ether;
      cropBasePrices[CropType.GALAXY_CORN] =  12378 ether;
      cropBasePrices[CropType.VOLCANO_COCOA] =  31362 ether;
      cropBasePrices[CropType.MILKY_WAY_SUGARCANE] =  35163 ether;
      cropBasePrices[CropType.SOLAR_PEPPER] =  38680 ether;

      strengthMultipliers[ICropTraits.Strength.B] = 80;
      strengthMultipliers[ICropTraits.Strength.A] = 150;
      strengthMultipliers[ICropTraits.Strength.S] = 300;

      sizeMultipliers[ICropTraits.Size.TINY] = 300;
      sizeMultipliers[ICropTraits.Size.NORMAL] = 75;
      sizeMultipliers[ICropTraits.Size.LARGE] = 150;
      sizeMultipliers[ICropTraits.Size.GIANT] = 1200;

      colorMultipliers[ICropTraits.CropColor.NORMAL] = 85;
      colorMultipliers[ICropTraits.CropColor.GOLDEN] = 350;
      colorMultipliers[ICropTraits.CropColor.RAINBOW] = 800;

      referralMultipliers[0] = 100;
      referralMultipliers[1] = 115;
      referralMultipliers[2] = 117;
      referralMultipliers[3] = 119;
      referralMultipliers[4] = 121;
      referralMultipliers[5] = 123;
      referralMultipliers[6] = 125;
      referralMultipliers[7] = 127;
      referralMultipliers[8] = 129;
      referralMultipliers[9] = 131;
      referralMultipliers[10] = 135;
    }

    modifier requireContractsSet() override {
        // TODO: more, probably
        require(address(cropNFT) != address(0x0) && 
        address(cropTraitsContract) != address(0x0) &&
        address(ruby) != address(0x0) &&
        address(referrals) != address(0x0));
        _;
    }

    function sellCrops(uint256[] calldata tokenIds) external nonReentrant whenNotPaused onlyEOA {
      require(tokenIds.length > 0, "Must sell at least one crop");
      require(senderOwnsAllCrops(tokenIds, _msgSender()), "Must own all crops being sold");
      uint256 rubyEarned = 0;
      updateStreakInfo();
      for (uint i = 0; i < tokenIds.length; i++) {
        uint256 cropPrice = getCropPrice(tokenIds[i], _msgSender());
        // Don't go through with the sale if a crop's price wasn't uploaded correctly
        require (cropPrice > 0, "Crop has no price");
        rubyEarned += cropPrice;
      }

      require(rubyEarned + totalRubyEarnedForCrops <= MAX_RUBY_FOR_CROP_SALES, "Not enough RUBY left for this sale");
      totalRubyEarnedForCrops += rubyEarned;
      cropNFT.burn(tokenIds);
      ruby.mint(_msgSender(), rubyEarned);

      emit CropsSold(_msgSender(), tokenIds, rubyEarned);
    }

    function senderOwnsAllCrops(uint256[] calldata tokenIds, address sender) internal view returns (bool) {
      for (uint i = 0; i < tokenIds.length; i++) {
        if (!(cropNFT.ownerOf(tokenIds[i]) == sender)) {
          return false;
        }
      }

      return true;
    }

    function updateStreakInfo() internal {
      SaleStreak storage streak = streakInfo[_msgSender()];      
      uint256 currentSeasonTime = currentSeasonStartTime();
      bool alreadySoldInCurrentSeason = currentSeasonTime <= streak.previousSeasonSaleTime;
      // only care about the first sale of the day, exit early to save some gas
      if (alreadySoldInCurrentSeason) {
        return;
      }

      uint256 previousSeasonTime = previousSeasonStartTime();
      bool soldInPreviousSeason = previousSeasonTime <= streak.previousSeasonSaleTime && streak.previousSeasonSaleTime < currentSeasonTime;

      if (soldInPreviousSeason) {
        streak.streakLength++;
      } else {
        streak.streakLength = 1;
      } 

      streak.previousSeasonSaleTime = block.timestamp;
    }

    function getCropPrice(uint256 tokenId, address user) internal view returns (uint256) {
      ICropTraits.CropTraits memory cropTraits = cropTraitsContract.getCropForToken(tokenId);
      return cropBasePrices[cropTraits.cropType] * winterMultiplier(cropTraits) * summerMultiplier(cropTraits) *
             strengthMultipliers[cropTraits.strength] * sizeMultipliers[cropTraits.size] * streakMultiplier() * 
             colorMultipliers[cropTraits.color] * referralMultipliers[getReferralCount(user)] * getRefereeBonus(user) / 
             MULTIPLIER_DENOMINATOR;
    }

    function winterMultiplier(ICropTraits.CropTraits memory cropTraits) internal view returns (uint8) {
      if (isSeason(Season.WINTER) && cropTraits.cropCategory != ICropTraits.CropCategory.GRAIN) {
        require(cropTraits.pickled, "Only pickled or grain crops can be sold in the winter");
        return 125;
      }

      return 100;
    }

    function getReferralCount(address user) internal view returns (uint8) {
      return uint8(MathUpgradeable.min(referrals.numReferrals(user), 10));
    }

    function getRefereeBonus(address user) internal view returns (uint8) {
      return referrals.getReferrer(user) != address(0x0) ? 115 : 100;
    }

    function summerMultiplier(ICropTraits.CropTraits memory cropTraits) internal view returns (uint8) {
      return isSeason(Season.SUMMER) && cropTraits.cropCategory == ICropTraits.CropCategory.FRUIT ? 150 : 100;
    }

    function streakMultiplier() internal view returns (uint8) {
      return streakInfo[_msgSender()].streakLength > 4 ? 125 : 100;
    }

    function setContracts(address cropNFTAddress, address cropTraitsAddress, address rubyAddress, address referralsAddress) external onlyOwner {
        cropNFT = ICrop(cropNFTAddress);
        cropTraitsContract = ICropTraits(cropTraitsAddress);
        ruby = IRUBY(rubyAddress);
        referrals = IReferrals(referralsAddress);
    }
}

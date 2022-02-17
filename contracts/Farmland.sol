//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./common/GameContract.sol";
import "./common/CommonTraits.sol";
import "./common/SeasonalGameContract.sol";
import "./interfaces/IFarmingGalilean.sol";
import "./interfaces/traits/IFarmingGalileanTraits.sol";
import "./interfaces/ICrop.sol";
import "./interfaces/traits/ICropTraits.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Farmland is Initializable, IERC721ReceiverUpgradeable, SeasonalGameContract, ReentrancyGuardUpgradeable {
  event GalileanStaked(uint256 indexed tokenId, uint256 timestamp);
  event GalileanUnstaked(uint256 indexed tokenId, uint256 timestamp);
  event GalileanHarvested(uint256 indexed tokenId, uint8 numCropsHarvested);
  uint8 constant MAX_CROPS_HARVESTABLE = 5;
  uint8 constant EXP_PER_CROP = 5;

  mapping(CropType => uint256) public timeToHarvest;

  mapping(address => uint256[]) ownerToStakedTokens;
  mapping(uint256 => address) stakedTokens;
  mapping(uint256 => uint256) lastHarvestTimeForToken;

  IFarmingGalilean galileanNFT;
  IFarmingGalileanTraits galileanTraitsContract;
  ICrop cropNFT;
  ICropTraits cropTraitsContract;

  function initialize() public initializer {
    __SeasonalGameContract_init();
    __ReentrancyGuard_init();

    timeToHarvest[CropType.RICE] = 30 minutes;
    timeToHarvest[CropType.WHEAT] = 1 hours;
    timeToHarvest[CropType.APPLE] = 30 minutes;
    timeToHarvest[CropType.BANANA] = 1 hours;
    timeToHarvest[CropType.GRAPE] = 2 hours;
    timeToHarvest[CropType.TOMATO] = 2 hours;
    timeToHarvest[CropType.WATERMELON] = 4 hours;
    timeToHarvest[CropType.KIWI] = 8 hours;
    timeToHarvest[CropType.PINEAPPLE] = 8 hours;
    timeToHarvest[CropType.STRAWBERRY] = 12 hours;
    timeToHarvest[CropType.LETTUCE] = 2 hours;
    timeToHarvest[CropType.CARROT] = 4 hours;
    timeToHarvest[CropType.EGGPLANT] = 8 hours;
    timeToHarvest[CropType.PUMPKIN] = 8 hours;
    timeToHarvest[CropType.TURNIP] = 12 hours;
    timeToHarvest[CropType.MOON_FRUIT] = 4 hours;
    timeToHarvest[CropType.GALAXY_CORN] = 4 hours;
    timeToHarvest[CropType.VOLCANO_COCOA] = 8 hours;
    timeToHarvest[CropType.MILKY_WAY_SUGARCANE] = 8 hours;
    timeToHarvest[CropType.SOLAR_PEPPER] = 8 hours;
  }

  modifier requireContractsSet() override {
        // TODO: more, probably
        require(address(galileanNFT) != address(0x0) && address(galileanTraitsContract) != address(0x0) && 
                address(cropNFT) != address(0x0) && address(cropTraitsContract) != address(0x0));
        _;
    }

  function stakeGalilean(uint256 tokenId) external whenNotPaused nonReentrant onlyEOA {
    require(galileanNFT.ownerOf(tokenId) == _msgSender(), "Must own this token");
    IFarmingGalileanTraits.FarmingGalileanTraits memory galileanTraits = galileanTraitsContract.getTraitsForToken(tokenId);
    checkNotWinterOrGrains(isGalileanGrain(galileanTraits.cropType));
    stakedTokens[tokenId] = _msgSender();
    ownerToStakedTokens[_msgSender()].push(tokenId);
    lastHarvestTimeForToken[tokenId] = block.timestamp;
    galileanNFT.transferFrom(_msgSender(), address(this), tokenId);
    emit GalileanStaked(tokenId, block.timestamp);
  }

  function unstakeGalilean(uint256 tokenId) external whenNotPaused nonReentrant onlyEOA {
    require(galileanNFT.ownerOf(tokenId) == address(this), "Token not staked");
    require(stakedTokens[tokenId] == _msgSender(), "You must be the owner to unstake");
    delete stakedTokens[tokenId];
    removeStakedTokenFromOwnerStakedTokens(tokenId);

    galileanNFT.safeTransferFrom(address(this), _msgSender(), tokenId);
    emit GalileanUnstaked(tokenId, block.timestamp);
  }

  function removeStakedTokenFromOwnerStakedTokens(uint256 tokenId) internal {
    uint256[] storage ownerStakedTokens = ownerToStakedTokens[_msgSender()];
    uint tokenIdx = 0;
    for (; tokenIdx < ownerStakedTokens.length; tokenIdx++) {
      if (ownerStakedTokens[tokenIdx] == tokenId) {
        break;
      }
    }
    require(tokenIdx < ownerStakedTokens.length, "Token not found in staked tokens");
    ownerStakedTokens[tokenIdx] = ownerStakedTokens[ownerStakedTokens.length - 1];
    ownerStakedTokens.pop();
  }

  // Grains can stake and harvest during the winter, nothing else
  function checkNotWinterOrGrains(bool isGrain) internal view {
    require(isGrain || !isSeason(Season.WINTER), "Only grain crops can perform actions in the winter");
  }

  function isGalileanGrain(CropType cropType) internal view returns (bool) {
    return cropTraitsContract.getCropCategory(cropType) == ICropTraits.CropCategory.GRAIN;
  }

  function harvest(uint256 tokenId) external whenNotPaused nonReentrant onlyEOA {
    require(stakedTokens[tokenId] != address(0x0), "Token must be staked to harvest");
    require(stakedTokens[tokenId] == _msgSender(), "You must be the owner to harvest");
    IFarmingGalileanTraits.FarmingGalileanTraits memory galileanTraits = galileanTraitsContract.getTraitsForToken(tokenId);
    bool isGrain = isGalileanGrain(galileanTraits.cropType);
    checkNotWinterOrGrains(isGrain);
    uint256 lastHarvestTime = getEffectiveLastHarvestTime(tokenId, isGrain);
    uint8 numCropsToHarvest = numHarvestableCropsForGalilean(galileanTraits, lastHarvestTime);
    require(numCropsToHarvest > 0, "No crops to harvest");
    lastHarvestTimeForToken[tokenId] = block.timestamp;
    cropNFT.mint(_msgSender(), numCropsToHarvest, galileanTraits);
    galileanTraitsContract.grantExpForToken(tokenId, numCropsToHarvest * 5);

    emit GalileanHarvested(tokenId, numCropsToHarvest);
  }

  /**
   * Winter destroys all unharvested non-grain crops, and cannot grow during this time. So, to determine
   * the last time crops were harvested, we use the last time that crops could grow.
   */
  function getEffectiveLastHarvestTime(uint256 tokenId, bool isGrain) internal view returns (uint256) {
    if (isGrain) {
      return lastHarvestTimeForToken[tokenId];
    }

    return MathUpgradeable.max(lastHarvestTimeForToken[tokenId], lastWinterTime() + SEASON_LENGTH);
  }


  function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot transfer to Farmland directly");
      return this.onERC721Received.selector;
    }
  
  function getStakedTokensForOwner(address owner) external view returns (uint256[] memory) {
    return ownerToStakedTokens[owner];
  }

  function numHarvestableCropsForToken(uint256 tokenId) public view whenNotPaused returns (uint8) {
    require(stakedTokens[tokenId] != address(0x0), "Token must be staked to harvest");
    IFarmingGalileanTraits.FarmingGalileanTraits memory galileanTraits = galileanTraitsContract.getTraitsForToken(tokenId);
    bool isGrain = isGalileanGrain(galileanTraits.cropType);
    if (isSeason(Season.WINTER) && !isGrain) {
      return 0;
    }

    uint256 lastHarvestTime = getEffectiveLastHarvestTime(tokenId, isGrain);

    return numHarvestableCropsForGalilean(galileanTraits, lastHarvestTime);
  }

  function numHarvestableCropsForGalilean(IFarmingGalileanTraits.FarmingGalileanTraits memory galileanTraits, 
                                          uint256 lastHarvestTime) internal view returns (uint8) {
    return uint8(MathUpgradeable.min((block.timestamp - lastHarvestTime) / timeToHarvest[galileanTraits.cropType], 
                           MAX_CROPS_HARVESTABLE));
  }

  function setContracts(address galileanNFTAddress, address galileanTraitsAddress, 
                        address cropNFTAddress, address cropTraitsAddress) external onlyOwner {
        galileanNFT = IFarmingGalilean(galileanNFTAddress);
        galileanTraitsContract = IFarmingGalileanTraits(galileanTraitsAddress);
        cropNFT = ICrop(cropNFTAddress);
        cropTraitsContract = ICropTraits(cropTraitsAddress);
    }
}
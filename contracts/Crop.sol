// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interfaces/traits/IFarmingGalileanTraits.sol";
import "./interfaces/ICrop.sol";
import "./common/GameContract.sol";
import "./common/CommonTraits.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "base64-sol/base64.sol";

contract Crop is Initializable, ICrop, ERC721EnumerableUpgradeable, GameContract {
    event CropMinted(uint256 indexed tokenId);
    event CropBurned(uint256 indexed tokenId);
    event CropPickled(uint256 indexed tokenId);

    uint256 public numMinted;
    mapping(address => uint256) numCropsMintedByPlayer;

    ICropTraits traits;

    function initialize() public initializer {
      __ERC721_init("Farms of Galileo: Crop", "FoGC");
      __GameContract_init();

      numMinted = 0;
    }

    modifier requireContractsSet() override {
        // TODO: more, probably
        require(address(traits) != address(0x0));
        _;
    }

    function mint(address recipient, uint8 amount, IFarmingGalileanTraits.FarmingGalileanTraits calldata sourceGalilean) external override whenNotPaused onlyGameContract {
      uint256 numCropsMintedByRecipient = numCropsMintedByPlayer[recipient];
      for (uint i = 0; i < amount; i++) {
        uint256 tokenId = numMinted;
        numMinted++;
        traits.generateCropTraits(tokenId, sourceGalilean, numCropsMintedByRecipient + i + 1);
        _safeMint(recipient, tokenId);
        emit CropMinted(tokenId);
      }

      numCropsMintedByPlayer[recipient] += amount;
    }

    function burn(uint256[] calldata tokenIds) external override whenNotPaused onlyGameContract {
      for (uint i = 0; i < tokenIds.length; i++) {
        _burn(tokenIds[i]);
        traits.burnDataFor(tokenIds[i]);
        emit CropBurned(tokenIds[i]);
      }
    }

    function pickleCrops(uint256[] calldata tokenIds) external override whenNotPaused onlyEOA {
      for (uint i = 0; i < tokenIds.length; i++) {
        require(ownerOf(tokenIds[i]) == _msgSender(), "Must own crop to pickle");
        traits.pickleVegetable(tokenIds[i]);
        emit CropPickled(tokenIds[i]);
      }
    }

    function setContracts(address traitsAddress, address farmlandAddress, address shippingBoxAddress) external onlyOwner {
        traits = ICropTraits(traitsAddress);
        gameContracts[farmlandAddress] = true;
        gameContracts[shippingBoxAddress] = true;
    }
}
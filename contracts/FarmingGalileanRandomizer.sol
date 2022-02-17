//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./interfaces/IFarmingGalilean.sol";
import "./interfaces/IFarmingGalileanRandomizer.sol";
import "./common/GameContract.sol";
import "./chainlink/VRFConsumerBaseUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// exists solely because main contract is too big
contract FarmingGalileanRandomizer is
    Initializable,
    IFarmingGalileanRandomizer,
    GameContract,
    VRFConsumerBaseUpgradeable
{
    event GalileanRandomnessRequested(
        bytes32 indexed requestId,
        uint256 indexed tokenId,
        address indexed recipient
    );

    bytes32 keyHash;
    uint256 fee;

    mapping(bytes32 => address) requestIdToSender;
    mapping(bytes32 => uint256) requestIdToTokenId;

    IFarmingGalilean farmingGalilean;

    modifier requireContractsSet() override {
        require(address(farmingGalilean) != address(0x0));
        _;
    }

    function initialize(
        address _vrfCoordinator,
        address _linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) public initializer {
        __VRFConsumerBase_init(_vrfCoordinator, _linkToken);
        __GameContract_init();

        fee = _fee;
        keyHash = _keyHash;
    }

    function generateRandomGalilean(uint256 tokenId, address recipient) external override whenNotPaused onlyGameContract {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        bytes32 requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = recipient;
        requestIdToTokenId[requestId] = tokenId;
        emit GalileanRandomnessRequested(requestId, tokenId, recipient);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomNumber)
        internal
        override
    {
        address nftOwner = requestIdToSender[requestId];
        uint256 tokenId = requestIdToTokenId[requestId];
        farmingGalilean.fulfillMint(nftOwner, tokenId, randomNumber);
    }

    function setContracts(address galileanAddress, address minterAddress) external onlyOwner {
        farmingGalilean = IFarmingGalilean(galileanAddress);
        gameContracts[galileanAddress] = true;
        gameContracts[minterAddress] = true;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./interfaces/traits/IFarmingGalileanTraits.sol";
import "./interfaces/IFarmingGalilean.sol";
import "./interfaces/IFarmingGalileanRandomizer.sol";
import "./interfaces/IReferrals.sol";
import "./common/GameContract.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract FarmingGalilean is
    Initializable,
    IFarmingGalilean,
    GameContract,
    ERC721EnumerableUpgradeable,
    AccessControlUpgradeable
{
    event GalileanMinted(uint256 indexed tokenId);
    event TransferWithMetadata(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        bytes metaData
    );

    uint16 constant GEN_ZERO_CUTOFF_ID = 9890;
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    IFarmingGalileanRandomizer randomizer;
    IFarmingGalileanTraits traits;
    IReferrals referrals;

    modifier requireContractsSet() override {
        require(
            address(randomizer) != address(0x0) &&
                address(traits) != address(0x0) &&
                address(referrals) != address(0x0)
        );
        _;
    }

    function initialize() public initializer {
        __ERC721_init("Farms of Galileo: Farming Galilean", "FoGFG");
        __GameContract_init();
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        // TODO: change this to 0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa
        _setupRole(DEPOSITOR_ROLE, 0xb5505a6d998549090530911180f38aC5130101c6);
    }

    function deposit(address user, bytes calldata depositData) external {
        require(
            hasRole(DEPOSITOR_ROLE, _msgSender()),
            "Insufficient permissions"
        );
        // deposit single
        if (depositData.length == 32) {
            uint256 tokenId = abi.decode(depositData, (uint256));
            mintAndInitialize(user, tokenId);
            // deposit batch
        } else {
            uint256[] memory tokenIds = abi.decode(depositData, (uint256[]));
            uint256 length = tokenIds.length;
            for (uint256 i; i < length; i++) {
                mintAndInitialize(user, tokenIds[i]);
            }
        }
    }

    /**
     * @notice called when user wants to withdraw token back to root chain with arbitrary metadata
     * @dev Should handle withdraw by burning user's token.
     *
     * This transaction will be verified when exiting on root chain
     *
     * @param tokenId tokenId to withdraw
     */
    function withdrawWithMetadata(uint256 tokenId) external whenNotPaused onlyEOA {
        require(_msgSender() == ownerOf(tokenId), "Not token owner");
        require(tokenId < GEN_ZERO_CUTOFF_ID, "Only gen zero can bridge");

        // Encoding metadata associated with tokenId & emitting event
        emit TransferWithMetadata(
            _msgSender(),
            address(0),
            tokenId,
            abi.encode(tokenURI(tokenId))
        );
        
        referrals.wipeReferralsFor(_msgSender());
        _burn(tokenId);
    }

    function mintAndInitialize(address user, uint256 tokenId) internal {
        referrals.initializeUser(user);
        _mint(user, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721EnumerableUpgradeable,
            IERC165Upgradeable,
            AccessControlUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function fulfillMint(
        address recipient,
        uint256 tokenId,
        uint256 randomNumber
    ) external override onlyGameContract {
        traits.generateGalileanForToken(tokenId, randomNumber);
        _mint(recipient, tokenId);
        emit GalileanMinted(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return traits.tokenURI(tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        // allow game contracts to be send without approval
        if (!gameContracts[_msgSender()]) {
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        }
        _transfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        // only run referral logic if it's a transfer between users, not mint or burn
        if (from != address(0x0) && to != address(0x0)) {
            referrals.handleTransfer(from, to, tokenId);
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function setContracts(
        address traitsAddress,
        address randomizerAddress,
        address farmlandAddress,
        address referralsAddress,
        address minterAddress
    ) external onlyOwner {
        traits = IFarmingGalileanTraits(traitsAddress);
        randomizer = IFarmingGalileanRandomizer(randomizerAddress);
        referrals = IReferrals(referralsAddress);
        gameContracts[randomizerAddress] = true;
        gameContracts[farmlandAddress] = true;
        gameContracts[minterAddress] = true;
    }

    function numGenZeroGalileansOfUser(address user)
        external
        view
        returns (uint16 count)
    {
        uint256 balance = balanceOf(user);
        for (uint256 i = 0; i < balance; i++) {
            if (tokenOfOwnerByIndex(user, i) < GEN_ZERO_CUTOFF_ID) {
                count++;
            }
        }
    }
}

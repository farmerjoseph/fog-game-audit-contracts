//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./common/GameContract.sol";
import "./interfaces/IFarmingGalilean.sol";
import "./interfaces/IReferrals.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Referrals is Initializable, GameContract, IReferrals {
    uint16 constant GEN_ZERO_CUTOFF_ID = 9890;
    mapping(address => address) userToReferrer;
    mapping(address => uint256) userToReferralCount;
    // Don't mess around with referrals unless the user has bridged to Polygon
    mapping(address => bool) userInitialized;

    IFarmingGalilean galilean;

    function initialize() public initializer {
        __GameContract_init();
    }

    modifier requireContractsSet() override {
        // TODO: more, probably
        require(address(galilean) != address(0x0));
        _;
    }

    function uploadReferrers(
        address[] calldata users,
        address[] calldata referrers
    ) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            userToReferrer[users[i]] = referrers[i];
        }
    }

    function uploadReferrals(
        address[] calldata users,
        uint256[] calldata referralCount
    ) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            userToReferralCount[users[i]] = referralCount[i];
        }
    }

    function numReferrals(address user) external view returns (uint256) {
        return galilean.numGenZeroGalileansOfUser(user) > 0 ? userToReferralCount[user] : 0;
    }

    function getReferrer(address user) external view returns (address) {
        return galilean.numGenZeroGalileansOfUser(user) > 0 ? userToReferrer[user] : address(0x0);
    }

    function initializeUser(address user) external onlyGameContract {
        userInitialized[user] = true;
    }

    // If you bridge back to L1, all your referral data gets wiped.
    function wipeReferralsFor(address user) external onlyGameContract {
        // this is safe because this method is only called by the bridge withdraw,
        // meaning they must have a gen 0
        if (userToReferrer[user] != address(0x0)) {
            userToReferralCount[userToReferrer[user]]--;
        }
        
        delete userToReferrer[user];
        delete userToReferralCount[user];
    }

    function handleTransfer(
        address from,
        address to,
        uint256 tokenId
    ) external onlyGameContract {
        maybeRemoveReferral(from, tokenId);
        maybeAddReferral(to, tokenId);
    }

    function maybeRemoveReferral(address user, uint256 tokenId) internal {
        if (
            userToReferrer[user] != address(0x0) &&
            isGalileanGenZero(tokenId) &&
            galilean.numGenZeroGalileansOfUser(user) <= 1
        ) {
            userToReferralCount[userToReferrer[user]]--;
        }
    }

    function maybeAddReferral(address user, uint256 tokenId) internal {
        if (
            userToReferrer[user] != address(0x0) &&
            userInitialized[user] &&
            isGalileanGenZero(tokenId) &&
            galilean.numGenZeroGalileansOfUser(user) == 0
        ) {
            userToReferralCount[userToReferrer[user]]++;
        }
    }

    function isGalileanGenZero(uint256 tokenId) internal pure returns (bool) {
        return tokenId < GEN_ZERO_CUTOFF_ID;
    }

    function setContracts(address galileanAddress) external onlyOwner {
        galilean = IFarmingGalilean(galileanAddress);
        gameContracts[galileanAddress] = true;
    }
}

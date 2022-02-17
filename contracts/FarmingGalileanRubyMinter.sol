//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./interfaces/traits/IFarmingGalileanTraits.sol";
import "./interfaces/IFarmingGalileanRandomizer.sol";
import "./interfaces/IRUBY.sol";
import "./common/GameContract.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract FarmingGalileanRubyMinter is
    Initializable,
    GameContract
{
    uint16 public constant GEN_ZERO_CUTOFF_ID = 9890;

    uint256 public numRubyMints;
    uint256 public maxRubyMints;

    IFarmingGalileanRandomizer randomizer;
    IRUBY ruby;

    modifier requireContractsSet() override {
        require(
            address(randomizer) != address(0x0) &&
                address(ruby) != address(0x0)
        );
        _;
    }

    function initialize() public initializer {
        __GameContract_init();

        // TODO: UPDATE THIS
        maxRubyMints = 45000;
    }

    function rubyMint(uint256 amount) external whenNotPaused onlyEOA {
        require(
            numRubyMints + amount <= maxRubyMints,
            "Not enough tokens left"
        );
        uint256 rubyCost = 0;
        for (uint256 i = 0; i < amount; i++) {
            rubyCost += rubyMintCost(numRubyMints + 1);
        }

        ruby.burn(_msgSender(), rubyCost);
        for (uint256 i = 0; i < amount; i++) {
            randomizer.generateRandomGalilean(
                numRubyMints + GEN_ZERO_CUTOFF_ID,
                _msgSender()
            );
            numRubyMints++;
        }
    }

    // TODO: check RUBY cost
    function rubyMintCost(uint256 tokenId) internal view returns (uint256) {
        if (tokenId <= (maxRubyMints * 8) / 20) return 24000000 ether;
        if (tokenId <= (maxRubyMints * 13) / 20) return 36000000 ether;
        if (tokenId <= (maxRubyMints * 14) / 20) return 48000000 ether;
        if (tokenId <= (maxRubyMints * 17) / 20) return 60000000 ether;
        return 100000000 ether;
    }

    function setContracts(
        address randomizerAddress,
        address rubyAddress
    ) external onlyOwner {
        randomizer = IFarmingGalileanRandomizer(randomizerAddress);
        ruby = IRUBY(rubyAddress);
    }
}

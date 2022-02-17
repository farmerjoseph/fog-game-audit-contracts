// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// Common functionality belonging to all game contracts in Farms of Galileo
abstract contract GameContract is Initializable, OwnableUpgradeable, PausableUpgradeable {
    mapping(address => bool) gameContracts;

    function __GameContract_init() public initializer {
      __Ownable_init();
      __Pausable_init();

      _pause();
    }

    modifier onlyGameContract() {
      // owner can also call "private" functions for testing and debugging purposes
      require(_msgSender() == owner() || gameContracts[_msgSender()], "Only game contracts can perform this action");
      _;
    }

    modifier onlyEOA() {
      require(tx.origin == _msgSender(), "Only EOA");
      _;
    }

    modifier requireContractsSet() virtual {_;}

    function removeGameContracts(address[] calldata addresses) public onlyOwner {
         for (uint i=0; i < addresses.length; i++) {
            gameContracts[addresses[i]] = false;
        }
    }

    /// ADMIN FUNCTIONS

    /**
     * Unpause the game contract. Contracts start off as paused and can only
     * be unpaused once all the game contracts are hooked up with each other.
     * 
     * Inheriting contracts can override this to provide further restrictions on when 
     * the contract can be unpaused.
     */
    function unpause() public virtual onlyOwner requireContractsSet {
        _unpause();
    }

    function pause() external onlyOwner {
      _pause();
    }
}
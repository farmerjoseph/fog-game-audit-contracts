// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.11;

import "./interfaces/IRUBY.sol";
import "./common/GameContract.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RUBY is Initializable, IRUBY, ERC20Upgradeable, GameContract {

  bool callingContractsSet;

  function initialize() public initializer {
    __ERC20_init("Ruby Star", "RUBY");
    __GameContract_init();
  }

  modifier requireContractsSet() override {
      // TODO: more, probably
      require(callingContractsSet);
      _;
    }

  /**
   * @notice mints $RUBY to a recipient
   * @param to the recipient of the $RUBY
   * @param amount the amount of $RUBY to mint
   */
  function mint(address to, uint256 amount) external override onlyGameContract {
    _mint(to, amount);
  }

  /**
   * burns $RUBY from a holder
   * @param from the holder of the $RUBY
   * @param amount the amount of $RUBY to burn
   */
  function burn(address from, uint256 amount) external override onlyGameContract {
    _burn(from, amount);
  }

  /**
   * Bypasses the need to set approval for game contracts, saving some gas and an extra transactions.
   * Since we still call _transfer (which emits a Transfer event) and default to super.transferFrom
   * when the calling entity is not a game contract, this function still follows the ERC-20 standard.
   */
  function transferFrom(
      address sender,
      address recipient,
      uint256 amount
  ) public virtual override(ERC20Upgradeable, IRUBY) returns (bool) {
    if(gameContracts[_msgSender()]) {
      _transfer(sender, recipient, amount);
      return true;
    }

    return super.transferFrom(sender, recipient, amount);
  }

  function setContracts(address minterAddress, address shippingBoxAddress) external onlyOwner {
        callingContractsSet = true;
        gameContracts[minterAddress] = true;
        gameContracts[shippingBoxAddress] = true;
    }
}
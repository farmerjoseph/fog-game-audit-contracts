// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./GameContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * Any game contracts that need to know about the notion of in-game seasons should inherit
 * from this contract. It provides base functionality of keeping track of seasons. 
 * Note: since all game contracts should have the same startTime, it may be a good idea
 * to deploy this contract on its own and have other contracts call it, but its not 
 * too hard to synchronize all this via deployment scripts. This way, we can have easy 
 * access to things like modifiers and constants.
 */
contract SeasonalGameContract is Initializable, GameContract {
  enum Season {
    SPRING, SUMMER, FALL, WINTER
  }

  uint256 constant public SEASON_LENGTH = 1 days;
  uint8 constant NUM_SEASONS = uint8(type(Season).max) + 1;
  // first second of the game, starting at spring. Seasonality will be computed
  // from this number
  uint256 public startTime;

  function __SeasonalGameContract_init() internal initializer {
    __GameContract_init();
  }

  modifier requireSeasonsStarted() {
    require(block.timestamp >= startTime, "Cannot get season before the game has started");
    _;
  }

  function getSeason() public view requireSeasonsStarted returns (Season) {
    return Season(((block.timestamp - startTime) / SEASON_LENGTH) % NUM_SEASONS);
  }

  function isSeason(Season season) public view requireSeasonsStarted returns (bool) {
    return getSeason() == season;
  }

  /**
   * Get the timestamp of the start of the last winter season. If no winter has passed yet,
   * this function will return a value representing the winter that would've happened before 
   * the game started. Calling contracts/functions should handle this case properly.
   */
  function lastWinterTime() public view requireSeasonsStarted returns (uint256) {
    uint256 numSeasonsPassedSinceStart = (block.timestamp - startTime) / SEASON_LENGTH;
    if (numSeasonsPassedSinceStart < 3) {
      return startTime - SEASON_LENGTH;
    }
    // Offset current season by 1, because winter requires 0 to be subtracted from numSeasonsPassedSinceStart,
    // spring requires 1, summer requires 2, fall requires 3
    uint8 num_seasons_to_subtract = uint8((numSeasonsPassedSinceStart + 1) % NUM_SEASONS);

    return startTime + ((numSeasonsPassedSinceStart - num_seasons_to_subtract) * SEASON_LENGTH);
  }

  function previousSeasonStartTime() public view requireSeasonsStarted returns (uint256) {
    uint256 numSeasonsPassedSinceStart = (block.timestamp - startTime) / SEASON_LENGTH;
    if (numSeasonsPassedSinceStart == 0) {
      return startTime - SEASON_LENGTH;
    }
    
    return startTime + (numSeasonsPassedSinceStart - 1) * SEASON_LENGTH;
  }

  function currentSeasonStartTime() public view requireSeasonsStarted returns (uint256) {
    uint256 numSeasonsPassedSinceStart = (block.timestamp - startTime) / SEASON_LENGTH;
    return startTime + (numSeasonsPassedSinceStart * SEASON_LENGTH);
  }

  function setSeasonStartTime(uint256 _startTime) external onlyOwner {
    startTime = _startTime;
  }
}
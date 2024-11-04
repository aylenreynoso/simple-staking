// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IStaking {
  /*///////////////////////////////////////////////////////////////
                              STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Represents the details of a stake for a user.
   * @param amount The amount of tokens staked by the user.
   * @param duration The duration (in years) of the stake (1, 2, or 3 years).
   * @param startDate The timestamp when the stake was created.
   * @param lastClaimedTerm The last term that rewards were claimed for.
   */
  struct Stake {
    uint256 amount;
    uint256 duration;
    uint256 startDate;
    uint256 lastClaimedTerm;
  }

  /*///////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a user stakes tokens.
   * @param user The address of the user who staked tokens.
   */
  event StakeExcecuted(address user);
  /**
   * @notice Emitted when a user unstakes tokens.
   * @param user The address of the user who unstaked tokens.
   */
  event UnstakeExcecuted(address user);
  /**
   * @notice Emitted when a user claims rewards.
   * @param user The address of the user who claimed rewards.
   */
  event RewardClaimed(address user);
  /**
   * @notice Emitted when the contract owner adds liquidity to the contract.
   * @param amount The amount of tokens added.
   */
  event LiquidityAdded(uint256 amount);
  /**
   * @notice Emitted when a user tries to claim rewards, but no rewards are available.
   */
  event NoRewardsYet();
  /**
   * @notice Emitted when a user tries to claim rewards, and these have been claimed already.
   */
  event RewardsAlreadyClaimed();

  /*///////////////////////////////////////////////////////////////
                              ERRORS
  //////////////////////////////////////////////////////////////*/
  
  /**
   * @dev Reverts if a non-staked user tries to access restricted staking functions.
   */
  error IStake_OnlyUser();

  /**
   * @dev Reverts if a non-owner tries to access restricted owner functions.
   */
  error IStake_OnlyOwner();

  /*///////////////////////////////////////////////////////////////
                              VIEWS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Retrieves staking details for a user.
   * @param _user The address of the user.
   * @return amount The amount of tokens staked.
   * @return duration The duration of the stake in years.
   * @return startDate The timestamp when staking started.
   * @return lastClaimedTerm The last term for which rewards were claimed.
   */
  function getUserStakeDetails(address _user) external view returns (
      uint256 amount,
      uint256 duration,
      uint256 startDate,
      uint256 lastClaimedTerm
  );

  /**
   * @notice Calculates the pending rewards for a user based on completed terms.
   * @param _user The address of the user.
   * @return pendingRewards The total pending rewards amount.
   */
  function getPendingRewards(address _user) external view returns (uint256 pendingRewards);

  /**
   * @notice Calculates the total staked amount of tokens by all users.
   * @return totalStaked The cumulative amount of tokens staked in the contract.
   */
  function getTotalStakedTokens() external view returns (uint256 totalStaked);

  /**
   * @notice Retrieves the available rewards pool balance in the contract.
   * @return availableRewards The balance of tokens available for rewards.
   */
  function getAvailableRewardsPool() external view returns (uint256 availableRewards);

  /**
   * @notice Checks if a user's stake term is complete.
   * @param _user The address of the user.
   * @return termCompleted A boolean indicating if the stake term is complete.
   */
  function isStakeTermComplete(address _user) external view returns (bool termCompleted);

  /*///////////////////////////////////////////////////////////////
                              LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Stake a certain amount of tokens for a certain duration
   * @param _amount The amount of tokens to stake
   * @param _duration The duration of the stake
   */
  function stake(uint256 _amount, uint256 _duration) external;

  /**
   * @notice Unstakes tokens and claims any accrued rewards based on completed terms.
   * @dev If any staking term has completed, calculates the reward based on the number of completed terms not yet claimed.
   */
  function unStake() external;

  /**
   * @notice Claims rewards for completed terms based on staking duration.
   * @dev Rewards are only claimable for terms that have completed. If the current term matches the last claimed term, no rewards are distributed.
   */
  function claimReward() external;

  /**
     * @notice Allows the contract owner to deposit tokens as liquidity for rewards.
     * @param _amount The amount of tokens to deposit as liquidity.
     */
  function ownerDeposit(uint256 _amount) external;
}

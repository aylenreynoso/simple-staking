// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IStaking} from "interfaces/IStaking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title Staking
 * @dev A contract for staking ERC20 tokens with rewards based on staking duration.
 * Rewards are 25%, 50%, or 75% based on 1, 2, or 3-year duration, respectively.
 */
contract Staking is IStaking {
    /// @notice ERC20 token used for staking and rewards.
    IERC20 public token;
    /// @notice The contract owner who provides liquidity for rewards.
    address public owner;

    mapping(address => Stake) public users;

    /**
     * @notice Initializes the staking contract with a specific ERC20 token and owner address.
     * @param _token The address of the ERC20 token used for staking.
     * @param _owner The address of the owner who will provide liquidity.
     */
    constructor(IERC20 _token, address _owner) {
        token = _token;
        owner = _owner;
    }

    /**
     * @notice Ensures that only a user with an active stake can call specific functions.
     */
    modifier onlyUser() {
        if (users[msg.sender].amount == 0) {
            revert IStake_OnlyUser();
        }
        _;
    }

    /**
     * @notice Ensures that only the contract owner can call specific functions.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert IStake_OnlyOwner();
        }
        _;
    }

    /**
     * @inheritdoc IStaking
     */
    function stake(uint256 _amount, uint256 _duration) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _duration >= 1 && _duration <= 3,
            "Duration must be 1, 2, or 3 years"
        );

        users[msg.sender] = Stake(_amount, _duration, block.timestamp, 0);

        token.approve(address(this), _amount);
        token.transferFrom(msg.sender, address(this), _amount);

        emit StakeExcecuted(msg.sender);
    }

    /**
     * @inheritdoc IStaking
     */
    function unStake() external onlyUser {
        Stake storage _stake = users[msg.sender];
        uint256 amount = _stake.amount;
        uint256 currentTerm = calculateCurrentTerm(_stake);

        if (currentTerm > 0) {
            //se cumplio al menos un term
            amount += calculateReward(
                _stake,
                currentTerm - _stake.lastClaimedTerm
            ); //calcula el porcentaje de los rewards en base a la duracion establecida
            //lo multiplica por la cantidad de terms cimplidos que no hayan sido reclamados
        }

        delete users[msg.sender];

        token.transfer(msg.sender, amount);
        emit UnstakeExcecuted(msg.sender);
    }

    /**
     * @notice Calculates the total rewards based on stake duration and the number of terms to claim.
     * @param _stake The staking information for the user.
     * @param _termsToClaim The number of completed terms since the last claim.
     * @return reward The total reward amount based on the number of terms to claim.
     */
    function calculateReward(
        Stake memory _stake,
        uint _termsToClaim
    ) internal pure returns (uint256 reward) {
        // Calculate reward based on the term duration
        reward = (_stake.amount * (_stake.duration * 25)) / 100;
        reward = reward * _termsToClaim;
    }

    /**
     * @notice Calculates the number of terms completed based on the stake start date and term duration.
     * @param _stake The staking information for the user.
     * @return term The number of terms that have been completed.
     */
    function calculateCurrentTerm(
        Stake memory _stake
    ) internal view returns (uint256 term) {
        uint stakedDays = (block.timestamp - _stake.startDate) / 1 days;
        term = stakedDays / (_stake.duration * 365 days);
    }

    /**
     * @inheritdoc IStaking
     */
    function claimReward() external onlyUser {
        Stake storage _stake = users[msg.sender];
        uint256 currentTerm = calculateCurrentTerm(_stake);

        if (currentTerm == 0) {
            emit NoRewardsYet();
        } else if (currentTerm == _stake.lastClaimedTerm) {
            emit RewardsAlreadyClaimed();
        } else {
            uint256 amount = calculateReward(
                _stake,
                currentTerm - _stake.lastClaimedTerm
            ); //no son 0 ni iguales
            _stake.lastClaimedTerm = currentTerm; //or +1?
            token.transfer(msg.sender, amount);
            emit RewardClaimed(msg.sender);
        }
    }

    /**
     * @inheritdoc IStaking
     */
    function ownerDeposit(uint256 _amount) external onlyOwner {
        token.approve(address(this), _amount);
        token.transferFrom(msg.sender, address(this), _amount);
        emit LiquidityAdded(_amount);
    }

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
    ) {
        Stake memory userStake = users[_user];
        return (userStake.amount, userStake.duration, userStake.startDate, userStake.lastClaimedTerm);
    }

    /**
     * @notice Calculates the pending rewards for a user based on completed terms.
     * @param _user The address of the user.
     * @return pendingRewards The total pending rewards amount.
     */
    function getPendingRewards(address _user) external view returns (uint256 pendingRewards) {
        Stake memory _stake = users[_user];
        uint256 currentTerm = calculateCurrentTerm(_stake);

        if (currentTerm > _stake.lastClaimedTerm) {
            pendingRewards = calculateReward(_stake, currentTerm - _stake.lastClaimedTerm);
        }
    }

    /**
     * @notice Calculates the total staked amount of tokens by all users.
     * @return totalStaked The cumulative amount of tokens staked in the contract.
     */
    function getTotalStakedTokens() external view returns (uint256 totalStaked) {
        uint256 balance = token.balanceOf(address(this));
        totalStaked = balance - getAvailableRewardsPool();
    }

    /**
     * @notice Retrieves the available rewards pool balance in the contract.
     * @return availableRewards The balance of tokens available for rewards.
     */
    function getAvailableRewardsPool() public view returns (uint256 availableRewards) {
        availableRewards = token.balanceOf(address(this));
    }

    /**
     * @notice Checks if a user's stake term is complete.
     * @param _user The address of the user.
     * @return termCompleted A boolean indicating if the stake term is complete.
     */
    function isStakeTermComplete(address _user) external view returns (bool termCompleted) {
        Stake memory _stake = users[_user];
        uint256 finalDate = _stake.startDate + (_stake.duration * 365 days);
        termCompleted = block.timestamp >= finalDate;
    }
}
/*Nota: para simplificar el enunciado
- el contrato contempla que cada usuario solo pueda tener un stake activo
*/
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStaking, Staking} from "contracts/Staking.sol";

/**
 * @notice This contract is a test helper to test the Staking contract
 */
contract StakingForTest is Staking {
    constructor(IERC20 _token, address _owner) Staking(_token, _owner) {}

    function addStakeForTest(address _user, uint256 _amount, uint256 _duration) external {
        users[_user] = Stake({
            amount: _amount,
            duration: _duration,
            startDate: block.timestamp,
            lastClaimedTerm: 0
        });
    }
}

contract UnitStaking is Test {
    /// Contracts
    StakingForTest internal _staking;
    IERC20 internal _token;

    /// EOAs
    address internal _owner = makeAddr("owner");
    address internal _user = makeAddr("user");

    /// Constants
    uint256 internal constant YEAR_IN_SECONDS = 365 days;
    uint256 internal constant STAKE_AMOUNT = 1000;

    /// Events
    event StakeExcecuted(address user);
    event UnstakeExcecuted(address user);
    event RewardClaimed(address user);
    event LiquidityAdded(uint256 amount);
    event NoRewardsYet();
    event RewardsAlreadyClaimed();

    function setUp() external {
        _token = IERC20(makeAddr("token"));
        _staking = new StakingForTest(_token, _owner);
    }

    /// Testing helpers
    function _setNextTimestamp(uint256 _timestamp) internal {
        vm.warp(_timestamp);
    }
}

/**
 * @notice Tests for stake function
 */
contract Unit_Staking_Stake is UnitStaking {
    function test_RevertIfInvalidDuration(uint256 _amount, uint256 _invalidDuration) external {
        vm.assume(_invalidDuration < 1 || _invalidDuration > 3);
        vm.assume(_amount > 0);
        
        vm.expectRevert("Duration must be 1, 2, or 3 years");
        _staking.stake(_amount, _invalidDuration);
    }
    
    function test_RevertIfInvalidAmount(uint256 _duration) external {
        vm.assume(_duration >= 1 && _duration <= 3);

        uint256 _invalidAmount = 0;

        vm.expectRevert("Amount must be greater than 0");
        _staking.stake(_invalidAmount, _duration);
    }

    function test_Stake(uint256 _amount) external {
        vm.assume(_amount > 0);
        uint256 _duration = 1; // 1 year

        // Mock token approve
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.approve.selector, address(_staking), _amount),
            abi.encode(true)
        );

        // Mock token transferFrom
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transferFrom.selector, _user, address(_staking), _amount),
            abi.encode(true)
        );

        vm.expectEmit();
        emit StakeExcecuted(_user);

        vm.prank(_user);
        _staking.stake(_amount, _duration);

        // Verify stake details
        (uint256 stakedAmount, uint256 stakedDuration,,) = _staking.getUserStakeDetails(_user);
        assertEq(stakedAmount, _amount);
        assertEq(stakedDuration, _duration);
    }
}

/**
 * @notice Tests for unstake function
 */
contract Unit_Staking_Unstake is UnitStaking {

    function test_RevertIfNotStaked(address _nonStaker) external {
        vm.assume(_nonStaker != _user);
        
        vm.prank(_nonStaker);
        vm.expectRevert(IStaking.IStake_OnlyUser.selector);
        _staking.unStake();
    }

    function test_UnstakeAfterTermComplete() external {
        _staking.addStakeForTest(_user, STAKE_AMOUNT, 1);
        _setNextTimestamp(block.timestamp + YEAR_IN_SECONDS + 1);

        uint256 expectedAmount = STAKE_AMOUNT + (STAKE_AMOUNT * 25) / 100;

        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, _user, expectedAmount),
            abi.encode(true)
        );

        vm.expectEmit();
        emit UnstakeExcecuted(_user);

        vm.prank(_user);
        _staking.unStake();
    }
}

/**
 * @notice Tests for reward claiming
 */
contract Unit_Staking_ClaimReward is UnitStaking {

    function test_RevertIfNotStaked(address _nonStaker) external {
        vm.assume(_nonStaker != _user);
        
        vm.prank(_nonStaker);
        vm.expectRevert(IStaking.IStake_OnlyUser.selector);
        _staking.claimReward();
    }

    function test_EmitNoRewardsYet() external {
        // Add stake for testing   
        _staking.addStakeForTest(_user, STAKE_AMOUNT, 1);
        
        vm.expectEmit();
        emit NoRewardsYet();

        vm.prank(_user);
        _staking.claimReward();
    }

    function test_ClaimRewardsAfterTerm() external {
        // Add stake for testing
        _staking.addStakeForTest(_user, STAKE_AMOUNT, 1);

        // Use the helper function from the base test contract
        _setNextTimestamp(block.timestamp + YEAR_IN_SECONDS + 1);

        //how to get the amount from the test?
        uint256 _amount = 250;   
        // Mock token transfer
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transfer.selector, _user, _amount),
            abi.encode(true)
        );

        vm.expectEmit();
        emit RewardClaimed(_user);

        vm.prank(_user);
        _staking.claimReward();
    }
}

/**
 * @notice Tests for owner deposit
 */
contract Unit_Staking_OwnerDeposit is UnitStaking {
    function test_RevertIfNotOwner(address _nonOwner, uint256 _amount) external {
        vm.assume(_nonOwner != _owner);
        
        vm.prank(_nonOwner);
        vm.expectRevert(IStaking.IStake_OnlyOwner.selector);
        _staking.ownerDeposit(_amount);
    }

    function test_OwnerDeposit(uint256 _amount) external {
        vm.assume(_amount > 0);
      
        // Mock token approve
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.approve.selector, address(_staking), _amount),
            abi.encode(true)
        );

        // Mock token transferFrom
        vm.mockCall(
            address(_token),
            abi.encodeWithSelector(IERC20.transferFrom.selector, _owner, address(_staking), _amount),
            abi.encode(true)
        );

        vm.expectEmit();
        emit LiquidityAdded(_amount);

        vm.prank(_owner);
        _staking.ownerDeposit(_amount);

        //assertEq(_staking.getAvailableRewardsPool(), _amount);
    }
}

/**
 * @notice Tests for constructor
 */
contract Unit_Staking_Constructor is UnitStaking {
    function test_Constructor() external view {
        // it deploys
        assertEq(address(_staking.token()), address(_token));
        assertEq(address(_staking.owner()), _owner);
    }
}

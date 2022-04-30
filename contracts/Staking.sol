//stake: lock tokens into smart contract
//withdraw: unlock tokens
//claimReward: user get their reward
//good reward mechnanis
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking {
    IERC20 public s_stakingToken; //s_ for storage variable
    IERC20 public s_rewardToken;
    mapping(address => uint256) public s_balances; //how much they stake
    mapping(address => uint256) public s_userRewardPerTokenPaid; //how much each address already paid
    mapping(address => uint256) public s_rewards; //how much reward each address has to claim
    uint256 public s_totalSupply;
    uint256 public s_rewardPerTokenStored;
    uint256 public s_lastUpdateTime;
    uint256 public constant REWARD_RATE = 100;

    error Staking__TransferFailed();
    error Staking__NeedsMoreThanZero();

    modifier updateReward(address _account) {
        s_rewardPerTokenStored = rewardPerToken();
        s_lastUpdateTime = block.timestamp;
        s_rewards[_account] = earned(_account);
        s_userRewardPerTokenPaid[_account] = s_rewardPerTokenStored;
        _;
    }

    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) {
            revert Staking__NeedsMoreThanZero();
        }
        _;
    }

    constructor(address _stakingToken, address _rewardToken) {
        s_stakingToken = IERC20(_stakingToken);
        s_rewardToken = IERC20(_rewardToken);
    }

    function earned(address _account) public view returns (uint256) {
        uint256 currentBalance = s_balances[_account];
        //how much already paid
        uint256 amountPaid = s_userRewardPerTokenPaid[_account];
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 pastRewards = s_rewards[_account];
        uint256 _earned = ((currentBalance *
            (currentRewardPerToken - amountPaid)) / 1e18) + pastRewards;
        return _earned;
    }

    function rewardPerToken() public view returns (uint256) {
        if (s_totalSupply == 0) {
            return s_rewardPerTokenStored;
        }
        return
            s_rewardPerTokenStored +
            (((block.timestamp - s_lastUpdateTime) * REWARD_RATE * 1e18) /
                s_totalSupply);
    }

    //specific token allowed to stake
    function stake(uint256 _amount)
        external
        updateReward(msg.sender)
        moreThanZero(_amount)
    {
        s_balances[msg.sender] = s_balances[msg.sender] + _amount;
        s_totalSupply = s_totalSupply + _amount;
        bool success = s_stakingToken.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        //require(success, "Failed"); will take more gas because it returns string, so we make custom error
        if (!success) {
            revert Staking__TransferFailed();
        }
        //we dont add the balances after revert becuase of re-entrancy attack
        //external function are cheaper than public function
    }

    function withdraw(uint256 _amount)
        external
        updateReward(msg.sender)
        moreThanZero(_amount)
    {
        s_balances[msg.sender] = s_balances[msg.sender] - _amount;
        s_totalSupply = s_totalSupply - _amount;
        bool success = s_stakingToken.transfer(msg.sender, _amount);
        if (!success) {
            revert Staking__TransferFailed();
        }
    }

    function claimReward() external updateReward(msg.sender) {
        uint256 reward = s_rewards[msg.sender];
        bool success = s_rewardToken.transfer(msg.sender, reward);
        if (!success) {
            revert Staking__TransferFailed();
        }
        //reward mech: contract is going to emit x token per second
        //and disperse them to all token stakers
        //e.g. total user token stake/total token x X token
        //1:1 reward: bankrupt your protocol
    }
}

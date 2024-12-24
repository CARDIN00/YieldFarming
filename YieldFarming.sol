// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint amount)external returns(bool);
    function transferFrom(address sender, address recipient, uint amount)external returns (bool);
    function balanceOf(address account)external view returns (uint);
}

contract YieldFarm {
    //allow the contract to recieve Eth
    receive() external payable { }


    IERC20 public lpToken;      // The LP token (e.g., Uniswap LP token)
    IERC20 public rewardToken;  // The token to distribute as rewards
    address public owner;

    uint256 public totalEthStaked;     // Total amount of LP tokens staked
    uint256 public totalTokenStaked;
    uint256 public rewardRate;      // Reward rate (per block, for simplicity)

    // Mapping to track user staked balances and reward debts
    mapping(address => uint256) public tokenStakedAmount;
    mapping(address => uint256) public EthStakedAmount;
    mapping(address => uint256) public rewardRemaining;
    mapping (address => uint )public lastRewardUpdate;
    mapping (address => uint)public stakeTime;

    // Event for staking and reward distribution
    event EthStaked(address indexed user, uint256 amount);
    event TokenStaked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, string stakeType);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _lpToken, address _rewardToken, uint256 _rewardRate) {
        lpToken = IERC20(_lpToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // functions 
    function Tokenstake(uint amount)external{
        require(amount >0,"need valid amount");
        bool success = lpToken.transferFrom(msg.sender, address(this), amount);
        require(success,"failed");

        updateReward(msg.sender);

        tokenStakedAmount[msg.sender] += amount;
        totalTokenStaked  += amount;

        emit TokenStaked(msg.sender, amount);
        stakeTime[msg.sender] = block.timestamp;
    }

    function Ethstake() external payable {
        uint amount = msg.value;
        require(amount > 0, "need valid amount");

        updateReward(msg.sender);

        EthStakedAmount[msg.sender] += amount;
        totalEthStaked += amount;

        emit EthStaked(msg.sender, amount);
        stakeTime[msg.sender] = block.timestamp;
    }

    // REWARDS FUNCTIONS

    function updateReward(address user)internal {
        uint pendingReward = calculateRewards(user);

        if(pendingReward > 0){
            rewardRemaining[user] += pendingReward;
        }

        lastRewardUpdate[user] = block.timestamp;
    }


    function calculateRewards(address user) public view returns(uint){
        uint timeLapsed = block.timestamp - lastRewardUpdate[user];

        //reward for staking tokens
        uint userTokenShare = tokenStakedAmount[user];
        uint tokenReward = (userTokenShare * timeLapsed * rewardRate) /1e18;

        //reward for staking ether
        uint userEtherReward = EthStakedAmount[user];
        uint etherReward = (userEtherReward * timeLapsed * rewardRate) /1e18;
        return rewardRemaining[user] + tokenReward + etherReward;
    }


     function claimReward()external {
        updateReward(msg.sender);

        uint pendingReward = calculateRewards(msg.sender);
        require(pendingReward >0,"no pending rewards");

        //check if the contract has enough balance to distribute the rewards
        uint contractRewardBalance = rewardToken.balanceOf(address(this));
        require(contractRewardBalance >= pendingReward,"insufficient pool reward balance");

        rewardRemaining[msg.sender] = 0;
        lastRewardUpdate[msg.sender] = block.timestamp;

        require(rewardToken.transfer(msg.sender, pendingReward),"Failed");
        stakeTime[msg.sender] = block.timestamp;

        emit RewardClaimed(msg.sender, pendingReward);
    }

    function withdrawStakeEth(uint amount)external{
        require(EthStakedAmount[msg.sender]> amount,"not enough staked amount");
        require(amount>0,"Not valid value");

        updateReward(msg.sender);

        EthStakedAmount[msg.sender] -= amount;
        totalEthStaked -= amount;

        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount, "ETH");
        
    }
    function withdrawStakedToken(uint amount)external{
        require(tokenStakedAmount[msg.sender]> amount,"not enough staked amount");
        require(amount>0,"Not valid value");

        updateReward(msg.sender);

        tokenStakedAmount[msg.sender] -= amount;
        totalTokenStaked -= amount;

        require(lpToken.transferFrom(address(this), msg.sender, amount));
        emit Withdrawn(msg.sender, amount, "Token");
        
    }
}

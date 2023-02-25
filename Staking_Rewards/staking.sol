// SPDX-License-Identifier: GPL-3.0

pragma solidity >= 0.8.16;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.0.0/contracts/token/ERC20/IERC20.sol";

contract staking_REWARDS{

    IERC20 public immutable staking_token;
    IERC20 public immutable rewards_token;

    event Staked(address staker,uint _amount);
    event UnStaked(address staker,uint _amount);
    event Withdraw_rewards(address staker,uint rewards);

    address public owner;

    uint public duration;
    uint public expiresAt;
    uint public last_rewardupdate;
    uint public rewardRATE;
    uint public rewardpertoken_staked;
    uint public total_staked;


    mapping(address => uint) public usertokens_staked;
    mapping(address => uint) public rewards;

    constructor(address _staking_token,address _rewards_token){
        owner = msg.sender;
        staking_token = IERC20(_staking_token);
        rewards_token = IERC20(_rewards_token);
    }

    receive() external payable{
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    function set_reward_duration(uint _duration) external onlyOwner{
        require(block.timestamp > expiresAt,"gotta go past the expireat timestamp");

        duration = _duration;
    }

    function set_rewardrate(uint _amount) external onlyOwner{
        require (_amount > 0 );
        if(block.timestamp > expiresAt){
             rewardRATE = _amount/ duration;
        }else{
            uint remainingREWARDS = rewardRATE * (expiresAt - block.timestamp);
            rewardRATE = (remainingREWARDS + _amount) / duration;
        }

        require(rewardRATE * duration <= rewards_token.balanceOf(address(this)),"not enough balance for the given _amount input");

        expiresAt = block.timestamp + duration;
        last_rewardupdate = block.timestamp;
    }

    function stake(uint _amount) external payable {
        require(_amount > 0);

        staking_token.transferFrom(msg.sender, address(this), _amount);
        usertokens_staked[msg.sender] += _amount;
        total_staked += _amount;

        emit Staked(msg.sender,_amount);

    }

    function unStake(uint _amount) external {
        require( _amount < usertokens_staked[msg.sender],"your staked tokens less than the input _amount");

        staking_token.transfer(msg.sender,_amount);
        usertokens_staked[msg.sender] -= _amount;
        total_staked -= _amount;

        emit UnStaked(msg.sender,_amount);
    }

    function _min(uint _x, uint _y) private pure returns(uint){
        return _x <= _y ? _x : _y ;
    }

// getter when rewards yearned till now should be returned
    function UpdateRewards() public {
        require(total_staked != 0,"no tokens staked yet");
        rewardpertoken_staked = rewardRATE * (_min(block.timestamp,expiresAt) - last_rewardupdate)/ total_staked; 

        rewards[msg.sender] += usertokens_staked[msg.sender] * rewardpertoken_staked;       
    }

// rewards[msg.sender] should be updated when staker wnats to withdraw the rewards yearned till the timestamp, so UpdateRewards() is called;
    function withdraw_rewards() external {
        UpdateRewards(); 
        uint reward = rewards[msg.sender];
        require(reward > 0,"no rewards yearned yet");
        
        rewards[msg.sender] = 0;
        rewards_token.transfer(msg.sender, reward);
        emit Withdraw_rewards(msg.sender, reward);
    }  

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

interface Token {
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (uint256);
}

contract Staking is Ownable, ReentrancyGuard, Pausable {
    Token PBMCToken;

    constructor(Token _tokenAddress) {
        require(
            address(_tokenAddress) != address(0),
            "Token Address cannot be address 0"
        );

        PBMCToken = _tokenAddress;
    }

    uint256 planId = 1;

    struct Plans {
        uint256 interestRate;
        uint256 timePeriodInMonth;
        bool active;
        
        
    }

    struct User {
        uint256 startTS;
        uint256 endTS;
        uint256 amount;
        uint256 rewards;
        uint256 planId;
        bool active;
    }

    mapping(uint256 => Plans) public planIdToPlans; // for getting plans details
    mapping(address => mapping(uint256 => User)) public userToUserInfo; //for user information
    

    function createPlan(uint256 _interestRate, uint256 timePeriodInMonth)
        external
        onlyOwner
        whenNotPaused
        returns (bool)
    {
        planIdToPlans[planId] = Plans(_interestRate, timePeriodInMonth, true);
        planId++;
        return true;
    }

    function stake(uint256 _amount, uint256 _planId)
        external
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        Plans memory plan = planIdToPlans[_planId];
        User storage user = userToUserInfo[msg.sender][_planId];
        require(plan.active == true, "please enter a valid plan");
        require(_amount > 0, "please enter the amount greater than zero");
        require(user.active == false, "you have already staked ");
        PBMCToken.transferFrom(msg.sender, address(this), _amount);

        uint256 monthToSeconds = plan.timePeriodInMonth * 1;
        // uint256 monthToSeconds = plan.timePeriodInMonth *  2,592,000;  //=30 days
        uint256 rewards = calculateRewards(_amount, _planId);
        userToUserInfo[msg.sender][_planId] = User(
            block.timestamp,
            block.timestamp + monthToSeconds,
            _amount,
            rewards,
            _planId,
            true
        );

        return true;
    }

    function unstake(uint256 _planId) external nonReentrant {
        User storage user = userToUserInfo[msg.sender][_planId];
        require(user.active == true, "stake is not active");
        require(user.endTS < block.timestamp, "period is not expire");
        user.active = false;
        PBMCToken.transfer(msg.sender, user.amount + user.rewards);
    }

    function calculateRewards(
        uint256 amount,
        uint _planId
        
    ) public view returns (uint256) {
        uint256 rewards = (amount * planIdToPlans[_planId].timePeriodInMonth* planIdToPlans[_planId].interestRate) / (12 * 100 * 10);
        return rewards;
    }

    function withdraw() external onlyOwner {
        uint256 contractBalance = PBMCToken.balanceOf(address(this));
        require(
            contractBalance > 0,
            "Contract does not have any balance to withdraw"
        );
        PBMCToken.transfer(msg.sender, contractBalance);
    }

    function deactivatePlan(uint256 _planId) external onlyOwner {
        planIdToPlans[_planId].active = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}

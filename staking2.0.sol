// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function balanceOf(address account) external view returns (uint256);

function approve(address recipient, uint amount) external returns(bool);

}

contract StakingContract is Ownable, ReentrancyGuard, Pausable {
    uint256 public maxAmount = 100000 * 10**18;
    uint256 public minAmount = 100 * 10**18;
    uint public totalReward;
    IERC20 public token;
    uint256 public totalStakers;
    uint256 public totalStakeAmount;

    struct User {
        address stakeHolder;
        uint256 amount;
        uint256 reward;
        uint256 id;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        bool active;
    }

    struct UserInfo{ 
        User[] usersDetails;
    }

    struct Stakeholder {
        // contain all the plans according to the timeperiod of a user
        User[] userThreeMonthPlans;
        User[] userSixMonthPlans;
        User[] userOneYearPlans;
    }

    UserInfo private userInfos;
    Stakeholder[] stakeholders; //first element of this list is zero or empty to avoid confusion 
    mapping(address => uint256) stakeholderToIndex;
    

    constructor(address _address) {
        token = IERC20(_address);
        // push an empty struct to stakeholders array to avoid confusion during checking whether stakeholder does not exist or his index is zero. 
        // no stakeholder will have 0 index now.
        stakeholders.push();
    }

    function stake(uint256 amount, uint256 month)
        external
        nonReentrant
        whenNotPaused
        returns (bool)
    {
        require(amount >= minAmount, "You have to spend more");
        require(amount <= maxAmount, "You have to spend less");
        uint256 userLength;
        uint256 interest;
        uint256 index = stakeholderToIndex[msg.sender];
        
        if (index == 0) {
            totalStakers +=1;
            index = addStakeholder(msg.sender);
        }
        if (month == 3) {
            interest = 22;
            userLength = stakeholders[index].userThreeMonthPlans.length;
        } else if (month == 6) {
            interest = 45;
            userLength = stakeholders[index].userSixMonthPlans.length;
        } else if (month == 12) {
            interest = 100;
            userLength = stakeholders[index].userOneYearPlans.length;
        } else {
            revert("Please select a valid plan");
        }
        Stakeholder storage stakeholder = stakeholders[index];
        require(
            userLength < 5,
            "You have reached the maximum limit to stake for this plan"
        );
        
        token.transferFrom(msg.sender, address(this), amount);
        uint256 reward = calculateReward(amount,interest, month);
        User memory newUser = User(
            msg.sender,
            amount,
            reward,
            userLength,
            interest,
            block.timestamp,
            month,
            true
        );

        if (month == 3) {
            stakeholder.userThreeMonthPlans.push(newUser);
        } else if (month == 6) {
            stakeholder.userSixMonthPlans.push(newUser);
        } else if (month == 12) {
            stakeholder.userOneYearPlans.push(newUser);
        }
        userInfos.usersDetails.push(newUser);
        totalStakeAmount += amount;
        return true;
    }

    function unstake(uint256 month, uint256 id)
        external
        nonReentrant
        returns (bool)
    {
        uint256 index = stakeholderToIndex[msg.sender];
        Stakeholder storage stakeholder = stakeholders[index];
        uint256 secondInMonth = 60;
        User storage user;
        if (month == 3) {
            user = stakeholder.userThreeMonthPlans[id];
        } else if (month == 6) {
            user = stakeholder.userSixMonthPlans[id];
        } else if (month == 12) {
            user = stakeholder.userOneYearPlans[id];
        }else{
            revert("please enter a valid month");
        }

        uint256 endTimeStamp = (user.duration * secondInMonth) + user.startTime;
        require(block.timestamp > endTimeStamp, "plan is still active");
        require(user.active == true, "you have already unstaked");
        token.transfer(msg.sender, user.amount + user.reward);
        totalReward+=user.reward;
        user.active = false;
        totalStakers -= 1;
        totalStakeAmount -= user.amount;
        return true;
    }

    function calculateReward(
        uint256 amount,
        uint256 interestRate,
        uint256 month
    ) public pure returns (uint256) {
        uint256 reward = (amount * interestRate * month) / (1000 * 12);
        return reward;
    }

    function updateMinAmount(uint256 _minAmount) external onlyOwner returns(uint) {
        minAmount = _minAmount;
        return minAmount;
    }

    function updateMaxAmount(uint256 _maxAmount) external onlyOwner returns(uint) {
        maxAmount = _maxAmount;
        return maxAmount;
    }

    function withdraw() external onlyOwner returns(uint) {
        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance > 0,
            "Contract does not have any balance to withdraw"
        );
        token.transfer(msg.sender, contractBalance);
        return contractBalance;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getUsersPlans() external view returns (Stakeholder memory) {
        return stakeholders[stakeholderToIndex[msg.sender]];
        
    }
        //add a new stakeholder to the stakeholders array
    function addStakeholder(address _address) internal returns (uint256) {
        stakeholders.push(); 
        uint256 index = stakeholders.length - 1;
        stakeholderToIndex[_address] = index;
        return index;
    }

    function getAllUsersInfo() external view returns(UserInfo memory){
        return userInfos;
    }
}


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
}

contract StakingContract is Ownable, ReentrancyGuard, Pausable {
    uint256 maxAmount = 100000 * 10**18;
    uint256 minAmount = 100 * 10**18;
    IERC20 public token;
    uint256 public totalStakers;
    uint256 public totalStakeAmount;

    struct User {
        uint256 amount;
        uint256 claimed;
        uint256 id;
        uint256 interestRate;
        uint256 startTime;
        uint256 duration;
        bool active;
    }

    struct Stakeholder {
        // contain all the plans according to the timeperiod of a user
        User[] userThreeMonthPlans;
        User[] userSixMonthPlans;
        User[] userOneYearPlans;
    }
    Stakeholder[] stakeholders;
    mapping(address => uint256) stakeholderToIndex;

    constructor(address _address) {
        token = IERC20(_address);
        // push an empty struct to stakeholder array to avoid confusion during checking whether stakeholder does not exist or his index is zero. 
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

        User memory newUser = User(
            amount,
            0,
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
        totalStakers += 1;
        totalStakeAmount += 1;

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
        uint256 reward = calculateReward(user.amount, user.interestRate, month);
        token.transfer(msg.sender, user.amount + reward);
        user.claimed = reward;
        user.active = false;
        totalStakers -= 1;
        totalStakeAmount -= 1;
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

    function addStakeholder(address _address) internal returns (uint256) {
        stakeholders.push();
        uint256 index = stakeholders.length - 1;
        stakeholderToIndex[_address] = index;
        return index;
    }
}



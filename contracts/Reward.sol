// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Pass.sol";
import "./IT.sol";

// Interface for Reward contract
interface RewardInterface {
    // Logged when a user claims their reward.
    event ClaimReward(address indexed user, uint amount);
}

// Reward contract
contract Reward is ReentrancyGuard, Ownable, RewardInterface {
    address passContractAddress;
    Pass passContract;  
    address validateContractAddress;
    IT public ITContract;
    struct rewardStruct {
        uint shares;
        bool validatorReward;
        uint dailyRewardPool;
        bool TGE;
        uint day;
        uint timestamp;
    }
    mapping(address => rewardStruct[]) private userShares;
    address[] unclaimedAddresses;
    struct pool {
        uint dailyRewardPool;
        uint dailyRewardPoolToBeUpdated;
        uint updatedAt;
    }
    pool dailyRewardPool;
    mapping(uint => uint) public dailySharesClaimedByUsers;
    mapping(uint => uint) public dailySharesClaimedByValidators;

    // Constructor to initialize the daily reward pool
    constructor(uint _dailyRewardPool) {
        dailyRewardPool.dailyRewardPool = _dailyRewardPool;
    }

    // Modifier to restrict access to pass or validate contract
    modifier onlyPassOrValidateContract {
        require(msg.sender == passContractAddress || msg.sender == validateContractAddress, "Unauthorised");
        _;
    }

    // Function to get user shares
    function getUserShares(address _address) public view returns(rewardStruct[] memory) {
        return userShares[_address];
    }

    // Function to set the pass contract address
    function setPassContract(address _address) onlyOwner public {
        passContractAddress = _address;
        passContract = Pass(_address);
    }

    // Function to set the IT contract address
    function setITContract(address _address) onlyOwner public {
        ITContract = IT(_address);
    }

    // Function to set the validate contract address
    function setValidateContract(address _address) onlyOwner public {
        validateContractAddress = _address;
    }

    // Function to set the daily reward pool
    function setDailyRewardPool(uint _amount) onlyOwner public {
        pool memory newPool;
        newPool.dailyRewardPool = dailyRewardPool.dailyRewardPool;
        newPool.dailyRewardPoolToBeUpdated = _amount;
        newPool.updatedAt = block.timestamp;
        dailyRewardPool = newPool;
    }

    // Function to reward users and validators
    function reward(uint _passId, address _validator) onlyPassOrValidateContract public {
        uint currentDay = block.timestamp / 1 days;
        rewardStruct memory newReward;
        newReward.shares = 1;
        newReward.day = currentDay;
        newReward.timestamp = block.timestamp;
        if (ITContract != IT(address(0))) {
            newReward.TGE = true;
        }
        if (dailyRewardPool.dailyRewardPoolToBeUpdated > 0 && block.timestamp >= (dailyRewardPool.updatedAt + 1 days - (dailyRewardPool.updatedAt % 1 days))) {
            newReward.dailyRewardPool = dailyRewardPool.dailyRewardPoolToBeUpdated;
            dailyRewardPool.dailyRewardPool = dailyRewardPool.dailyRewardPoolToBeUpdated;
            dailyRewardPool.dailyRewardPoolToBeUpdated = 0;
        } else {
            newReward.dailyRewardPool = dailyRewardPool.dailyRewardPool;
        }
        if (_validator != address(0)) {
            newReward.validatorReward = true;
            dailySharesClaimedByValidators[currentDay] = dailySharesClaimedByValidators[currentDay] + 1;
            unclaimedAddresses.push(_validator);
        } else {
            (address user, , uint expiry) = passContract.passDetails(_passId);
            if (block.timestamp < expiry) {
                userShares[user].push(newReward);
                dailySharesClaimedByUsers[currentDay] = dailySharesClaimedByUsers[currentDay] + 1;
                unclaimedAddresses.push(user);
            }
        }
    }

    // Function to calculate user rewards
    function calculateUserRewards(address _address) public view returns (uint) {
        uint claimableReward;
        rewardStruct[] memory rewards = userShares[_address];
        for (uint i = 0; i < rewards.length; i++) {
            uint day = userShares[_address][i].day;
            if (block.timestamp >= (userShares[_address][i].timestamp + 1 days - (userShares[_address][i].timestamp % 1 days))) {
                uint dailySharesClaimed = rewards[i].validatorReward ? dailySharesClaimedByValidators[day] : dailySharesClaimedByUsers[day];
                if (dailySharesClaimed * (10**18) < (rewards[i].dailyRewardPool / 2)) {
                    claimableReward = claimableReward + dailySharesClaimed * ((rewards[i].dailyRewardPool / 2) * 5) / 10000;
                }
                if (dailySharesClaimed * (10**18) >= rewards[i].dailyRewardPool) {
                    claimableReward = claimableReward + (rewards[i].shares * (rewards[i].dailyRewardPool / 2)) / dailySharesClaimed;
                }
            }
        }
        return claimableReward;
    }

    // Function to calculate rewards
    function calculateRewards() public view returns (uint) {
        uint claimableReward;
        for (uint a = 0; a < unclaimedAddresses.length; a++) {
            rewardStruct[] memory rewards = userShares[unclaimedAddresses[a]];
            for (uint i = 0; i < rewards.length; i++) {
                uint day = rewards[i].day;
                if (block.timestamp >= (rewards[i].timestamp + 1 days - (rewards[i].timestamp % 1 days))) {
                    uint dailySharesClaimed = rewards[i].validatorReward ? dailySharesClaimedByValidators[day] : dailySharesClaimedByUsers[day];
                    if (dailySharesClaimed * (10**18) < (rewards[i].dailyRewardPool / 2)) {
                        claimableReward = claimableReward + dailySharesClaimed * ((rewards[i].dailyRewardPool / 2) * 5) / 10000;
                    }
                    if (dailySharesClaimed * (10**18) >= rewards[i].dailyRewardPool) {
                        claimableReward = claimableReward + (rewards[i].shares * (rewards[i].dailyRewardPool / 2)) / dailySharesClaimed;
                    }
                }
            }
        }
        return claimableReward;
    }

    // Function to calculate daily reward pool
    function calculateDailyRewardPool() public view returns (uint) {
        if (dailyRewardPool.dailyRewardPoolToBeUpdated > 0 && block.timestamp >= (dailyRewardPool.updatedAt + 1 days - (dailyRewardPool.updatedAt % 1 days))) {
            return dailyRewardPool.dailyRewardPoolToBeUpdated;
        } else {
            return dailyRewardPool.dailyRewardPool;
        }
    }

    // Function to claim reward
    function claimReward() nonReentrant public {
        require(ITContract != IT(address(0)), "The TGE (Token Generation Event) has not happened yet.");
        uint claimableReward;
        uint beforeTGEReward;
        rewardStruct[] memory rewards = userShares[msg.sender];
        for (uint i = 0; i < rewards.length; i++) {
            uint day = userShares[msg.sender][i].day;
            if (block.timestamp >= (userShares[msg.sender][i].timestamp + 1 days - (userShares[msg.sender][i].timestamp % 1 days))) {
                uint dailySharesClaimed = rewards[i].validatorReward ? dailySharesClaimedByValidators[day] : dailySharesClaimedByUsers[day];
                if (dailySharesClaimed * (10**18) < (rewards[i].dailyRewardPool / 2)) {
                    if (rewards[i].TGE) {
                        claimableReward = claimableReward + dailySharesClaimed * ((rewards[i].dailyRewardPool / 2) * 5) / 10000;
                    } else {
                        beforeTGEReward = beforeTGEReward + dailySharesClaimed * ((rewards[i].dailyRewardPool / 2) * 5) / 10000;
                    }
                }
                if (dailySharesClaimed * (10**18) >= rewards[i].dailyRewardPool) {
                    if (rewards[i].TGE) {
                        claimableReward = claimableReward + (rewards[i].shares * (rewards[i].dailyRewardPool / 2)) / dailySharesClaimed;
                    } else {
                        beforeTGEReward = claimableReward + (rewards[i].shares * (rewards[i].dailyRewardPool / 2)) / dailySharesClaimed;
                    }
                }
            }
        }
        require((claimableReward + beforeTGEReward) > 0, "You do not have any IT rewards to claim.");
        ITContract.reward(msg.sender, claimableReward, beforeTGEReward);
        delete userShares[msg.sender];
        uint index;
        for (uint a = 0; a < unclaimedAddresses.length; a++) {
            if (unclaimedAddresses[a] == msg.sender) {
                index = a;
                break;
            }
        }      
        for (uint i = index; i < unclaimedAddresses.length - 1; i++) {
            unclaimedAddresses[i] = unclaimedAddresses[i+1];
        }
        unclaimedAddresses.pop();
        emit ClaimReward(msg.sender, claimableReward + beforeTGEReward);
    }
}

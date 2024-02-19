// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Interface for the IT token
interface ITInterface {
    // Logged when IT will be minted.
    event Mint(uint amount);
    // Logged when IT will be burned.
    event Burn(uint amount);
}

// IT token contract
contract IT is ERC20, Ownable, ITInterface {
    // Constants for initial supply and inflation rate
    uint constant initialSupply = 1000000000;
    uint constant inflationRate = 3;
    uint totalSupplyAtStartOfYear = 0;

    // Arrays to store reward and payment contracts
    address[] public rewardContracts;
    address[] public paymentContracts;

    // Constructor to initialize the token
    constructor() ERC20("IT", "IT") {
        totalSupplyAtStartOfYear = initialSupply * (10**18);
        _mint(msg.sender, initialSupply * (10**18));
    }

    // Modifier to restrict functions to only reward contracts
    modifier onlyRewardContracts {
        bool isRewardContract;
        for(uint i = 0; i < rewardContracts.length; i++) {
            if(msg.sender == rewardContracts[i]) {
                isRewardContract = true;
            }
        }
        require(isRewardContract == true, "Unauthorised");
        _;
    }

    // Modifier to restrict functions to only payment contracts
    modifier onlyPaymentContracts {
        bool isPaymentContract;
        for(uint i = 0; i < paymentContracts.length; i++) {
            if(msg.sender == paymentContracts[i]) {
                isPaymentContract = true;
            }
        }
        require(isPaymentContract == true, "Unauthorised");
        _;
    }

    // Mapping to track daily minted amounts
    mapping(uint256 => uint256) private dailyMintedAmount;

    // Modifier to manage inflation
    modifier inflation(uint256 _rewardAmount, uint256 _beforeTGEReward) {
        uint256 currentDay = block.timestamp / 86400;
        uint256 maxMintableAmount = _beforeTGEReward + (totalSupplyAtStartOfYear * inflationRate * 10**16 / 365 / (10**18));
        require(_rewardAmount > 0, "Amount should be more than 0");
        require(_rewardAmount <= maxMintableAmount, "Requested amount exceeds max mintable amount");
        require(dailyMintedAmount[currentDay] + _rewardAmount <= maxMintableAmount, "Daily mintable amount exceeded");
        _;

        dailyMintedAmount[currentDay] += _rewardAmount;
        if (block.timestamp >= (totalSupplyAtStartOfYear + 365 days)) {
            totalSupplyAtStartOfYear = totalSupply();
        }
    }

    // Function to set reward contract address
    function setRewardContract(address _address) onlyOwner public {
        rewardContracts.push(_address);
    }

    // Function to set payment contract address
    function setPaymentContract(address _address) onlyOwner public {
        paymentContracts.push(_address);
    }

    // Function to remove a reward contract
    function removeRewardContract(uint _index) onlyOwner public {
        delete rewardContracts[_index];
    }

    // Function to remove a payment contract
    function removePaymentContract(uint _index) onlyOwner public {
        delete paymentContracts[_index];
    }

    // Function to reward users
    function reward(address _address, uint _rewardAmount, uint _beforeTGEReward) onlyRewardContracts inflation(_rewardAmount, _beforeTGEReward) public {
        _mint(_address, _rewardAmount + _beforeTGEReward);
        emit Mint(_rewardAmount + _beforeTGEReward);
    }

    // Function to burn tokens
    function burn(uint _burnAmount) onlyPaymentContracts public {
        _burn(msg.sender, _burnAmount);
        emit Burn(_burnAmount);
    }
}

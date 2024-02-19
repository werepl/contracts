// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./IT.sol";
import "./Pass.sol";
import "./Reward.sol";
import "./Payment.sol";

// Interface for Validate contract
interface ValidateInterface {
    // Logged when a validator validates a proposal.
    event ValidateProposal(address indexed validator, address indexed proposedby ,string indexed propId);
    // Logged when a validator stakes their IT.
    event StakeIT(address indexed validator, uint amount);
    // Logged when a validator unstakes their IT.
    event UnstakeIT(address indexed validator, uint amount);
    // Logged when a penalty is imposed on the validator.  
    event ImposePenalty(address indexed validator, uint amount);
    // Logged when a new validator is listed.
    event ListValidator(address indexed validator);
    // Logged when a validator is delisted.
    event DelistValidator(address indexed validator);
}

// Validate contract
contract Validate is ReentrancyGuard, Ownable, ValidateInterface {
    address wereplAddress;
    Pass passContract;  
    IERC20 ITContract;
    Reward rewardContract;
    address paymentContractAddress;
    Payment paymentContract;
    uint public stakingRequired;
    enum validatorStatus {unlisted,listed,delisted}
    struct validator{
        uint ITStaked;
        uint outstandingAmount;
        uint penalties;
        uint lastPenalty;
        validatorStatus status;
    }
    mapping(address=>validator) public validators;
    enum proposalStatus {pending, approved, rejected}
    struct proposal{
        string domain;
        string TOA;
        bool validated;
        address validator;
        proposalStatus status;
    }
    mapping(string=>proposal) public proposals;

    // Constructor to initialize werepl address
    constructor(address _wereplAddress) {
        wereplAddress = _wereplAddress;
    }

    // Modifier to restrict access to werepl
    modifier onlyWerepl {
        require(msg.sender == wereplAddress, "Unauthorised");
        _;
    }

    // Function to set the reward contract address
    function setRewardContract(address _address) onlyOwner public {
        rewardContract = Reward(payable(_address));
    }

    // Function to set the payment contract address
    function setPaymentContract(address _address) onlyOwner public {
        paymentContractAddress = _address;
        paymentContract = Payment(_address);
    }

    // Function to approve payment contract
    function approvePaymentContract(uint _amount) onlyOwner public {
        ITContract.approve(paymentContractAddress, _amount);
    }

    // Function to set werepl address
    function setWerepl(address _address) onlyWerepl public {
        wereplAddress = _address;
    }

    // Function to set staking required amount
    function setStakingRequired(uint _amount) onlyWerepl public {
        stakingRequired = _amount;
    }

    // Function to set pass contract address
    function setPassContract(address _address) onlyWerepl public {
        passContract = Pass(_address);
    }

    // Function to set IT contract address
    function setITContract(address _address) onlyOwner public {
        ITContract = IERC20(_address);
    }

    // Function to list a validator
    function listValidator(address _validator) onlyWerepl public {
        require(validators[_validator].status == validatorStatus.unlisted, "Already listed");
        validators[_validator].status = validatorStatus.listed;
        emit ListValidator(_validator);
    }

    // Function to delist a validator
    function delistValidator(address _validator) onlyWerepl public {
        require(validators[_validator].status == validatorStatus.listed, "Not a validator");
        if (validators[_validator].status == validatorStatus.listed) {
            if (ITContract != IT(address(0))) {
                paymentContract.contractPayment(address(this),(stakingRequired*5)/100);
                validators[_validator].ITStaked = validators[_validator].ITStaked - (stakingRequired*5)/100;
            } else {
                validators[_validator].outstandingAmount = validators[_validator].outstandingAmount + (stakingRequired*5)/100;
            }
        }
        validators[_validator].status = validatorStatus.delisted;
        emit DelistValidator(_validator);
    }

    // Function to stake IT tokens
    function stakeIT(uint _amount) public {
        require(validators[msg.sender].status != validatorStatus.unlisted, "Not a validator");
        require((validators[msg.sender].ITStaked + _amount >= stakingRequired - validators[msg.sender].outstandingAmount) || (validators[msg.sender].status == validatorStatus.delisted && _amount >= validators[msg.sender].outstandingAmount), "You should have a minimum IT amount staked.");
        if (validators[msg.sender].outstandingAmount > 0) {
            paymentContract.contractPayment(msg.sender, validators[msg.sender].outstandingAmount);
            validators[msg.sender].outstandingAmount = 0;
        }
        ITContract.transferFrom(msg.sender, address(this), _amount - validators[msg.sender].outstandingAmount);
        validators[msg.sender].ITStaked += _amount - validators[msg.sender].outstandingAmount;
        emit StakeIT(msg.sender, _amount);
    }

    // Function to unstake IT tokens
    function unstakeIT(uint _amount) nonReentrant public {
        require(validators[msg.sender].ITStaked >= _amount, "insufficient funds");
        if (validators[msg.sender].status == validatorStatus.listed) {
            require(validators[msg.sender].ITStaked - _amount >= stakingRequired, "You should have a minimum IT amount staked.");
        }
        ITContract.transfer(msg.sender, _amount);
        validators[msg.sender].ITStaked -= _amount;
        emit UnstakeIT(msg.sender, _amount);
    }

    // Function to validate a proposal
    function validateProposal(string calldata _propId, string calldata _domain, string calldata _TOA, address _proposedby, address _validator) onlyWerepl public {
        require(validators[_validator].status == validatorStatus.listed, "Not a validator");
        require(validators[msg.sender].ITStaked >= stakingRequired, "You should have a minimum IT amount staked.");
        require(proposals[_propId].validated == false, "The proposal has already been validated");
        if (_proposedby != address(0)) {
            uint passId = passContract.passIds(_proposedby);
            (, , uint expiry) = passContract.passDetails(passId);
            if (passId != 0 && block.timestamp < expiry) {
                passContract.entry(passId, _propId, _domain, _TOA, _validator);
            }
        }
        proposal memory newProposal;
        newProposal.domain = _domain;
        newProposal.TOA = _TOA;
        newProposal.validated = true;
        newProposal.validator = _validator;
        newProposal.status = proposalStatus.pending;
        proposals[_propId] = newProposal;
        emit ValidateProposal(_validator, _proposedby, _propId);
    }

    // Function to impose penalty on a validator
    function imposePenalty(address _validator) private {
        require(validators[_validator].status == validatorStatus.listed, "Not a validator");
        if (ITContract != IT(address(0))) {
            paymentContract.contractPayment(address(this), (stakingRequired*1)/100);
            validators[_validator].ITStaked = validators[_validator].ITStaked - (stakingRequired*1)/100;
        } else {
            validators[_validator].outstandingAmount = validators[_validator].outstandingAmount + (stakingRequired*1)/100;   
        }
        if (validators[_validator].penalties == 0) {
            validators[_validator].penalties = 1;
            emit ImposePenalty(_validator, (stakingRequired*1)/100);
        } else if (validators[_validator].lastPenalty + 90 days < block.timestamp) {
            validators[_validator].lastPenalty = block.timestamp;
            validators[_validator].penalties = 1;
            emit ImposePenalty(_validator, (stakingRequired*1)/100);
        } else {
            validators[_validator].penalties++;
            emit ImposePenalty(_validator, (stakingRequired*1)/100);
            if (validators[_validator].penalties == 3) {
                if (ITContract != IT(address(0))) {
                    paymentContract.contractPayment(address(this), (validators[_validator].ITStaked * 20) / 100);
                    validators[_validator].ITStaked = validators[_validator].ITStaked - (validators[_validator].ITStaked / 5);
                } else {
                    validators[_validator].outstandingAmount = validators[_validator].outstandingAmount + validators[_validator].ITStaked / 5;
                }
                validators[_validator].penalties = 0;
                validators[_validator].status = validatorStatus.delisted;
                emit DelistValidator(_validator);
            }
        }
    }

    // Function to approve a proposal
    function approveProposal(string calldata _propId) onlyWerepl public {
        require(proposals[_propId].validated == true, "This proposal has not been validated");
        require(proposals[_propId].status == proposalStatus.pending, "The proposal is already approved or rejected");
        proposals[_propId].status = proposalStatus.approved;
        rewardContract.reward(0, proposals[_propId].validator);
    }

    // Function to reject a proposal
    function rejectProposal(string calldata _propId) onlyWerepl public {
        require(proposals[_propId].validated == true, "This proposal has not been validated");
        require(proposals[_propId].status == proposalStatus.pending, "The proposal is already approved or rejected");
        proposals[_propId].status = proposalStatus.rejected;
        imposePenalty(proposals[_propId].validator);
    }
}

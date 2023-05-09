// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IT.sol";
import "./Pass.sol";
import "./Reward.sol";
import "./Payment.sol";

interface ValidateInterface{
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
    event j(uint);
}

contract Validate is Ownable, ValidateInterface {
  address wereplAddress;
  Pass passContract;  
  IERC20 ITContract;
  Reward rewardContract;
  address paymentContractAddress;
  Payment paymentContract;
  enum validatorStatus {unlisted,listed,delisted}
  struct validator{
    uint ITStaked;
    uint penalties;
    uint lastPenalty;
    validatorStatus status;
  }
  mapping(address=>validator) public validators;
  enum proposalStatus {pending, approved, rejected}
  struct proposal{
    bool validated;
    proposalStatus status;
  }
  mapping(string=>proposal) public proposals;
  bool lock;
    constructor(address _wereplAddress) {
      wereplAddress=_wereplAddress;
    }
modifier onlyWerepl{
  require(msg.sender==wereplAddress,"Unauthorised");
  _;
}
function setRewardContract(address _address) onlyOwner public{
  rewardContract=Reward(payable(_address));
}
function setPaymentContract(address _address) onlyOwner public{
    paymentContractAddress=_address;
  paymentContract=Payment(_address);
}
function approvePaymentContract(uint _amount) onlyOwner public{
  ITContract.approve(paymentContractAddress, _amount);
}
function getValidatorStatus(address _validator) view public returns(bool){
  if(validators[_validator].status==validatorStatus.listed){
    return true;
  }else{
    return false;
  }
}
function setWerepl(address _address) onlyWerepl public{
  wereplAddress=_address;
}
function setPassContract(address _address) onlyWerepl public{
  passContract = Pass(_address);
}
function setITContract(address _address) onlyOwner public{
  ITContract=IERC20(_address);
}
function listValidator(address _address) onlyWerepl public{
  require(validators[_address].status==validatorStatus.unlisted,"Already listed");
  require(validators[_address].ITStaked==0,"Already listed");
  validator memory newValidator;
  newValidator.status=validatorStatus.listed;
  validators[_address]=newValidator;
  emit ListValidator(_address);
}
function stakeIT(uint _amount) public{
    require(validators[msg.sender].status==validatorStatus.listed,"Not a validator");
    emit j(validators[msg.sender].ITStaked+_amount);
    require(validators[msg.sender].ITStaked+_amount>=10000*(10**18),"Your minimum staking should be 10000 IT");
  ITContract.transferFrom(msg.sender, address(this), _amount);
  validators[msg.sender].ITStaked+=_amount;
  emit StakeIT(msg.sender,_amount);
}

function unstakeIT(uint _amount) public{
    require(lock==false);
    require(validators[msg.sender].ITStaked>=_amount,"insufficient funds");
    if(getValidatorStatus(msg.sender)==true){
    require(validators[msg.sender].ITStaked-_amount>=10000*(10**18),"Your minimum staking should be 10000 IT");
    }
    lock=true;
  ITContract.transfer(msg.sender,_amount);
  validators[msg.sender].ITStaked-=_amount;
  lock=false;
  emit UnstakeIT(msg.sender,_amount);
}
   function validateProposal(string memory _propId, string memory _domain, address _proposedby, address _validator) onlyWerepl public{
     require(getValidatorStatus(_validator)==true,"Not a validator");
      require(validators[_validator].ITStaked>=10000*(10**18),"Staked IT are less than 10,000.");
      require(proposals[_propId].validated==false,"The proposal has already been validated");
      uint passId = passContract.passIds(_proposedby);
      (, , ,uint entriesRemaining) = passContract.passDetails(passId);
      if(passId!=0&&entriesRemaining>0){
      passContract.entry(passId,_propId,_domain,_validator);
      }
      proposal memory newProposal;
      newProposal.validated=true;
      newProposal.status=proposalStatus.pending;
      proposals[_propId]=newProposal;
      emit ValidateProposal(_validator,_proposedby,_propId);
   }
function imposePenalty(address _validator) private{
  require(validators[_validator].status==validatorStatus.listed,"Not a validator");
  paymentContract.contractPayment(address(this),100*(10**18));
  validators[msg.sender].ITStaked=validators[msg.sender].ITStaked-100*(10**18);
  if (validators[_validator].penalties == 0) {
  validators[_validator].penalties = 1;
  emit ImposePenalty(msg.sender,100*(10**18));
  } else if (validators[_validator].lastPenalty + 90 days < block.timestamp) {
  validators[_validator].lastPenalty = block.timestamp;
  validators[_validator].penalties = 1;
  emit ImposePenalty(msg.sender,100*(10**18));
  } else {
  validators[_validator].penalties++;
  emit ImposePenalty(msg.sender,100*(10**18));
  if (validators[_validator].penalties == 3) {
  paymentContract.contractPayment(address(this), (validators[_validator].ITStaked * 20) / 100);
  validators[_validator].ITStaked = validators[_validator].ITStaked - (validators[_validator].ITStaked / 5);
  validators[_validator].penalties=0;
  validators[_validator].status=validatorStatus.delisted;
  emit DelistValidator(msg.sender);
}
}
}
   function approveProposal(string memory _propId, address _validator) onlyWerepl public{
     require(proposals[_propId].validated==true,"This proposal has not been validated");
     require(proposals[_propId].status==proposalStatus.pending,"The proposal is already approved or rejected");
     proposals[_propId].status=proposalStatus.approved;
     rewardContract.rewardValidator(_validator);
   }
   
   function rejectProposal(string memory _propId, address _validator) onlyWerepl public{
     require(proposals[_propId].validated==true,"This proposal has not been validated");
     require(proposals[_propId].status==proposalStatus.pending,"The proposal is already approved or rejected");
     proposals[_propId].status=proposalStatus.rejected;
     imposePenalty(_validator);
   }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IT.sol";
import "./Pass.sol";
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
}

contract Validate is Ownable, ValidateInterface {
  address wereplAddress;
  Pass passContract;  
  IERC20 ITContract;
  address paymentContractAddress;
  Payment paymentContract;
  struct validator{
    uint ITStaked;
    uint penalties;
    uint lastPenalty;
    bool active;
  }
  mapping(address=>validator) public validators;
  bool lock;
    constructor(address _wereplAddress) {
      wereplAddress=_wereplAddress;
    }
modifier onlyWerepl{
  require(msg.sender==wereplAddress,"Unauthorised");
  _;
}
function setPaymentContract(address _address) onlyOwner public{
    paymentContractAddress=_address;
  paymentContract=Payment(_address);
}
function approvePaymentContract(uint _amount) onlyOwner public{
  ITContract.approve(paymentContractAddress, _amount);
}
function getStatus(address _address) view public returns(bool){
  return validators[_address].active;
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
  require(validators[_address].active==false&&validators[_address].ITStaked==0,"Already listed");
  validator memory newValidator;
  newValidator.active=true;
  validators[_address]=newValidator;
  emit ListValidator(_address);
}
function stakeIT() public{
    require(validators[msg.sender].active==true,"Not a validator");
    require(validators[msg.sender].ITStaked<10000,"You can only stake a maximum of 10000 IT.");
    uint amount = 10000-validators[msg.sender].ITStaked;
  ITContract.transferFrom(msg.sender, address(this), amount*(10**18));
  validators[msg.sender].ITStaked=10000;
  emit StakeIT(msg.sender,amount);
}

function unstakeIT() public{
    require(lock==false);
  require(validators[msg.sender].active==false,"Your validator account is active");
    require(validators[msg.sender].ITStaked>0," You don't have any IT to unstake");
    lock=true;
  ITContract.transfer(msg.sender,validators[msg.sender].ITStaked*(10**18));
  validators[msg.sender].ITStaked=0;
  lock=false;
  emit UnstakeIT(msg.sender,validators[msg.sender].ITStaked);
}
   function validateProposal(string memory _propId, string memory _domain, address _proposedby, address _validator) onlyWerepl public{
     require(validators[_validator].active==true,"Not a validator");
      require(validators[_validator].ITStaked==10000,"Staked IT are less than 10,000.");
      uint passId = passContract.passIds(_proposedby);
      (, , ,uint entriesRemaining) = passContract.passDetails(passId);
      if(passId!=0&&entriesRemaining>0){
      passContract.entry(passId,_propId,_domain,_validator);
      }
      emit ValidateProposal(_validator,_proposedby,_propId);
   }
function imposePenalty(address _validator) public{
  require(validators[_validator].active==true,"Not a validator");
  paymentContract.makePayment(address(this),100);
  validators[msg.sender].ITStaked=validators[msg.sender].ITStaked-100;
  if (validators[_validator].penalties == 0) {
  validators[_validator].penalties = 1;
  emit ImposePenalty(msg.sender,100);
  } else if (validators[_validator].lastPenalty + 90 days < block.timestamp) {
  validators[_validator].lastPenalty = block.timestamp;
  validators[_validator].penalties = 1;
  emit ImposePenalty(msg.sender,100);
  } else {
  validators[_validator].penalties++;
  emit ImposePenalty(msg.sender,100);
  if (validators[_validator].penalties == 3) {
  paymentContract.makePayment(address(this), (validators[_validator].ITStaked * 20) / 100);
  validators[_validator].ITStaked = validators[_validator].ITStaked - (validators[_validator].ITStaked / 5);
  validators[_validator].penalties=0;
  validators[_validator].active=false;
  emit DelistValidator(msg.sender);
}
}
}
}
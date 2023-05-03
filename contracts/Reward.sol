// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pass.sol";
import "./Validate.sol";

interface RewardInterface{
  // Logged when daily rewards will be minted and distributed.
  event MintAndDistribute(uint amount);
  // Logged when a user will claim their reward.
  event ClaimUserReward(address indexed user, uint amount);
  // Logged when a validator will claim their reward.
  event ClaimValidatorReward(address indexed user, uint amount);
}
contract Reward is Ownable, RewardInterface {
address wereplAddress;
address passContractAddress;
Validate validateContract;
IT ITContract;
bool lock;
constructor(address _wereplAddress){
  wereplAddress=_wereplAddress;
}
mapping(address=>uint) public userReward;
mapping(address=>uint) public validatorReward;
mapping(address=>uint) public userShares;
mapping(address=>uint) public validatorShares;
address[] private usersClaimedShares;
address[] private ValidatorsClaimedShares;
uint public dailySharesClaimedByUsers;
uint public dailySharesClaimedByValidators;
modifier onlyPassContract{
  require(msg.sender==passContractAddress,"Unauthorised");
  _;
}
modifier onlyWerepl{
  require(msg.sender==wereplAddress,"Unauthorised");
  _;
}
function setWerepl(address _address) onlyWerepl public{
  wereplAddress=_address;
}
function setPassContract(address _address) onlyOwner public{
  passContractAddress=_address;
}
function setITContract(address _address) onlyOwner public{
  ITContract = IT(_address);
}
function setValidateContract(address _address) onlyOwner public{
  validateContract=Validate(_address);
}
function rewardUser(address _address, uint _shares) onlyPassContract public{
require(_shares==1||_shares==10,"Invalid share amount");
userShares[_address]=userShares[_address]+_shares;
dailySharesClaimedByUsers=dailySharesClaimedByUsers+_shares;
usersClaimedShares.push(_address);
}
function claimUserReward() public{
  require(lock==false);
  require(userReward[msg.sender]>0,"You don't have any reward to claim");
  lock=true;
  ITContract.transfer(msg.sender, userReward[msg.sender]*(10**18));
  emit ClaimUserReward(msg.sender,userReward[msg.sender]);
  userReward[msg.sender]=0;
  lock=false;
}
function claimValidatorReward() public{
    require(lock==false);
    lock=true;
  require(validatorReward[msg.sender]>0,"You don't have any reward to claim");
  ITContract.transfer(msg.sender, validatorReward[msg.sender]*(10**18));
  emit ClaimValidatorReward(msg.sender,validatorReward[msg.sender]);
  validatorReward[msg.sender]=0;
  lock=false;
}
function rewardValidator(address _address) onlyWerepl public{
  require(validateContract.getStatus(_address)==true,"Not a validator");
validatorShares[_address]=validatorShares[_address]+1;
dailySharesClaimedByValidators=dailySharesClaimedByValidators+1;
ValidatorsClaimedShares.push(_address);
} 
function mintAndDistribute() onlyWerepl public{
    uint mintableAmountForUsers;  
    uint mintableAmountForValidators;
  if(dailySharesClaimedByUsers<250000){
  mintableAmountForUsers = 5*dailySharesClaimedByUsers;
  }
    if(dailySharesClaimedByUsers>=250000){
  mintableAmountForUsers = 25000;
  }
  if(dailySharesClaimedByValidators<25000){
  mintableAmountForValidators = 50*dailySharesClaimedByValidators;
  }
      if(dailySharesClaimedByValidators>=25000){
  mintableAmountForValidators = 25000;
  }
ITContract.reward(mintableAmountForUsers+mintableAmountForValidators);
for(uint i=0; i<usersClaimedShares.length; i++){
  userReward[usersClaimedShares[i]]=mintableAmountForUsers/dailySharesClaimedByUsers*userShares[usersClaimedShares[i]];
  userShares[usersClaimedShares[i]]=0;
}
delete usersClaimedShares;
for(uint i=0; i<ValidatorsClaimedShares.length; i++){
  validatorReward[ValidatorsClaimedShares[i]]=mintableAmountForValidators/dailySharesClaimedByValidators*validatorReward[ValidatorsClaimedShares[i]];
  validatorShares[ValidatorsClaimedShares[i]]=0;
}
delete ValidatorsClaimedShares;
dailySharesClaimedByUsers=0;
dailySharesClaimedByValidators=0;
emit MintAndDistribute(mintableAmountForUsers+mintableAmountForValidators);
}
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Pass.sol";
import "./IT.sol";
interface RewardInterface{
  // Logged when daily rewards will be minted and distributed.
  event MintAndDistribute(uint amount);
  // Logged when a user will claim their reward.
  event ClaimUserReward(address indexed user, uint amount);
  // Logged when a validator will claim their reward.
  event ClaimValidatorReward(address indexed user, uint amount);
}
contract Reward is ReentrancyGuard, Ownable, RewardInterface {
address wereplAddress;
address passContractAddress;
Pass passContract;  
address validateContractAddress;
IT ITContract;
uint public lastMintAndDistribute;
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
modifier onlyValidateContract{
  require(msg.sender==validateContractAddress,"Unauthorised");
  _;
}
function setPassContract(address _address) onlyOwner public{
  passContractAddress=_address;
  passContract = Pass(_address);
}
function setITContract(address _address) onlyOwner public{
  ITContract = IT(_address);
}
function setValidateContract(address _address) onlyOwner public{
  validateContractAddress=_address;
}
function rewardUser(uint _passId) onlyPassContract public{
(address user, , uint expiry) = passContract.passDetails(_passId);
if(block.timestamp<expiry){
userShares[user]=userShares[user]+1;
dailySharesClaimedByUsers=dailySharesClaimedByUsers+1;
usersClaimedShares.push(user);
}
}
function claimUserReward() nonReentrant public{
  require(userReward[msg.sender]>0,"You don't have any reward to claim");
  ITContract.transfer(msg.sender, userReward[msg.sender]);
  userReward[msg.sender]=0;
  emit ClaimUserReward(msg.sender,userReward[msg.sender]);
}
function claimValidatorReward() nonReentrant public{
  require(validatorReward[msg.sender]>0,"You don't have any reward to claim");
  ITContract.transfer(msg.sender, validatorReward[msg.sender]);
  validatorReward[msg.sender]=0;
  emit ClaimValidatorReward(msg.sender,validatorReward[msg.sender]);
}
function rewardValidator(address _address) onlyValidateContract public{
validatorShares[_address]=validatorShares[_address]+1;
dailySharesClaimedByValidators=dailySharesClaimedByValidators+1;
ValidatorsClaimedShares.push(_address);
} 
function mintAndDistribute() onlyWerepl public{
    require(lastMintAndDistribute +  1 days <= block.timestamp, "In one day, only one minting and distribution is allowed.");        
    uint mintableAmountForUsers;  
    uint mintableAmountForValidators;
  if(dailySharesClaimedByUsers<25000){
  mintableAmountForUsers = 50*dailySharesClaimedByUsers*(10**18);
  }
    if(dailySharesClaimedByUsers>=25000){
  mintableAmountForUsers = 25000*(10**18);
  }
  if(dailySharesClaimedByValidators<25000){
  mintableAmountForValidators = 50*dailySharesClaimedByValidators*(10**18);
  }
      if(dailySharesClaimedByValidators>=25000){
  mintableAmountForValidators = 25000*(10**18);
  }
ITContract.reward(mintableAmountForUsers+mintableAmountForValidators);
for(uint i=0; i<usersClaimedShares.length; i++){
  userReward[usersClaimedShares[i]]=userReward[usersClaimedShares[i]]+mintableAmountForUsers/dailySharesClaimedByUsers*userShares[usersClaimedShares[i]];
  userShares[usersClaimedShares[i]]=0;
}
delete usersClaimedShares;
for(uint i=0; i<ValidatorsClaimedShares.length; i++){
  validatorReward[ValidatorsClaimedShares[i]]=validatorReward[ValidatorsClaimedShares[i]]+mintableAmountForValidators/dailySharesClaimedByValidators*validatorShares[ValidatorsClaimedShares[i]];
  validatorShares[ValidatorsClaimedShares[i]]=0;
}
delete ValidatorsClaimedShares;
dailySharesClaimedByUsers=0;
dailySharesClaimedByValidators=0;
lastMintAndDistribute=block.timestamp;
emit MintAndDistribute(mintableAmountForUsers+mintableAmountForValidators);
}
}
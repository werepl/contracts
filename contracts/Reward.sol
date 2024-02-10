// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Pass.sol";
import "./IT.sol";
interface RewardInterface{
  // Logged when a user will claim their reward.
  event ClaimReward(address indexed user, uint amount);
}

contract Reward is ReentrancyGuard, Ownable, RewardInterface {
address passContractAddress;
Pass passContract;  
address validateContractAddress;
IT public ITContract;
struct rewardStruct{
  uint shares;
  bool validatorReward;
  uint dailyRewardPool;
  uint day;
  bool TGE;
  uint timestamp;
}
mapping(address=>rewardStruct[]) private userShares;
address[] unclaimedAddresses;
struct pool{
  uint dailyRewardPool;
  uint dailyRewardPoolToBeUpdated;
  uint updatedAt;
}
pool dailyRewardPool;
mapping(uint=>uint) public dailySharesClaimedByUsers;
mapping(uint=>uint) public dailySharesClaimedByValidators;
  constructor(uint _dailyRewardPool) {
      dailyRewardPool.dailyRewardPool=_dailyRewardPool;
    }
modifier onlyPassOrValidateContract{
  require(msg.sender==passContractAddress||msg.sender==validateContractAddress,"Unauthorised");
  _;
}
modifier onlyValidateContract{
  require(msg.sender==validateContractAddress,"Unauthorised");
  _;
}
function getUserShares(address _address) public view returns(rewardStruct[] memory){
return userShares[_address];
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

function setDailyRewardPool(uint _amount) onlyOwner public{
  pool memory newPool;
  newPool.dailyRewardPool=dailyRewardPool.dailyRewardPool;
  newPool.dailyRewardPoolToBeUpdated=_amount;
  newPool.updatedAt=block.timestamp;
  dailyRewardPool=newPool;
}
function reward(uint _passId, address _validator) onlyPassOrValidateContract public{
 uint currentDay=block.timestamp/1 days;
  rewardStruct memory newReward;
  newReward.shares=1;
  newReward.day=currentDay;
  newReward.timestamp=block.timestamp;
  if(ITContract!=IT(address(0))){
    newReward.TGE=true;
  }
  if(dailyRewardPool.dailyRewardPoolToBeUpdated>0&&block.timestamp/1 days>=(dailyRewardPool.updatedAt/1 days)+1){
    newReward.dailyRewardPool=dailyRewardPool.dailyRewardPoolToBeUpdated;
    dailyRewardPool.dailyRewardPool=dailyRewardPool.dailyRewardPoolToBeUpdated;
    dailyRewardPool.dailyRewardPoolToBeUpdated=0;
  }else{
    newReward.dailyRewardPool=dailyRewardPool.dailyRewardPool;
  }
if(_validator!=address(0)){
newReward.validatorReward=true;
dailySharesClaimedByValidators[currentDay]=dailySharesClaimedByValidators[currentDay]+1;
unclaimedAddresses.push(_validator);
}else{
(address user, , uint expiry) = passContract.passDetails(_passId);
if(block.timestamp<expiry){
userShares[user].push(newReward);
dailySharesClaimedByUsers[currentDay]=dailySharesClaimedByUsers[currentDay]+1;
unclaimedAddresses.push(user);
}
}
}
function calculateUserRewards(address _address) public view returns (uint) {
 uint claimableReward;
    rewardStruct[] memory rewards = userShares[_address];
   for(uint i=0; i<rewards.length;i++){
    uint day=userShares[msg.sender][i].day;
    if(block.timestamp/ 1 days>day){
    uint dailySharesClaimed = rewards[i].validatorReward?dailySharesClaimedByValidators[day]:dailySharesClaimedByUsers[day];
 if(dailySharesClaimed*(10**18)<(rewards[i].dailyRewardPool/2)){
  claimableReward = claimableReward+dailySharesClaimed*((rewards[i].dailyRewardPool/2)*5)/10000;
  }
    if(dailySharesClaimed*(10**18)>=rewards[i].dailyRewardPool) {
      claimableReward=claimableReward+(rewards[i].shares * (rewards[i].dailyRewardPool/2)) / dailySharesClaimed;
  }
    }
  }
  return claimableReward;
}
function calculateRewards() public view returns (uint) {
   uint claimableReward;
   for(uint a=0;a<unclaimedAddresses.length;a++){
    rewardStruct[] memory rewards = userShares[unclaimedAddresses[a]];
   for(uint i=0; i<rewards.length;i++){
    uint day=userShares[msg.sender][i].day;
    if(block.timestamp/ 1 days>day){
    uint dailySharesClaimed = rewards[i].validatorReward?dailySharesClaimedByValidators[day]:dailySharesClaimedByUsers[day];
 if(dailySharesClaimed*(10**18)<(rewards[i].dailyRewardPool/2)){
  claimableReward = claimableReward+dailySharesClaimed*((rewards[i].dailyRewardPool/2)*5)/10000;
  }
    if(dailySharesClaimed*(10**18)>=rewards[i].dailyRewardPool) {
      claimableReward=claimableReward+(rewards[i].shares * (rewards[i].dailyRewardPool/2)) / dailySharesClaimed;
  }
    }
    }
  }
  return claimableReward;
}
function calculateDailyRewardPool() public view returns (uint) {
  if(dailyRewardPool.dailyRewardPoolToBeUpdated>0&&block.timestamp/1 days>=(dailyRewardPool.updatedAt/1 days)+1){
    return dailyRewardPool.dailyRewardPoolToBeUpdated;
  }else{
    return dailyRewardPool.dailyRewardPool;
  }
}
function claimReward() nonReentrant public{
  require(ITContract!=IT(address(0)),"The TGE (Token Generation Event) has not happened yet.");
  uint claimableReward;
  uint beforeTGEReward;
  rewardStruct[] memory rewards = userShares[msg.sender];
   for(uint i=0; i<rewards.length;i++){
    uint day=userShares[msg.sender][i].day;
    if(block.timestamp/ 1 days>day){
    uint dailySharesClaimed = rewards[i].validatorReward?dailySharesClaimedByValidators[day]:dailySharesClaimedByUsers[day];
 if(dailySharesClaimed*(10**18)<(rewards[i].dailyRewardPool/2)){
  if(rewards[i].TGE){
  claimableReward=claimableReward+dailySharesClaimed*((rewards[i].dailyRewardPool/2)*2)/1000;
  }else{
    beforeTGEReward = beforeTGEReward+dailySharesClaimed*((rewards[i].dailyRewardPool/2)*2)/1000;
  }
  }
    if(dailySharesClaimed*(10**18)>=rewards[i].dailyRewardPool) {
        if(rewards[i].TGE){
      claimableReward=claimableReward+(rewards[i].shares * (rewards[i].dailyRewardPool/2)) / dailySharesClaimed;
        }else{
        beforeTGEReward=claimableReward+(rewards[i].shares * (rewards[i].dailyRewardPool/2)) / dailySharesClaimed;
        }
  }
    }
  }
  ITContract.reward(msg.sender,claimableReward,beforeTGEReward);
  delete userShares[msg.sender];
  uint index;
  for(uint a=0;a<unclaimedAddresses.length;a++){
    if(unclaimedAddresses[a]==msg.sender){
      index=a;
      break;
    }
  }      
  for (uint i = index; i < unclaimedAddresses.length - 1; i++){
    unclaimedAddresses[i] = unclaimedAddresses[i+1];
  }
  unclaimedAddresses.pop();
  emit ClaimReward(msg.sender,claimableReward+beforeTGEReward);
}
}
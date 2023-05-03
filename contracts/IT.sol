// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITInterface{
  // Logged when IT will be minted.
  event Mint(uint amount);
  // Logged when IT will be burned.
  event Burn(uint amount);
}

contract IT is ERC20, Ownable, ITInterface{
uint constant initialSupply = 1000000000;
uint constant inflationRate = 3;
uint totalSupplyAtStartOfYear = 0;
address[] public rewardContracts;
    constructor() ERC20("IT", "IT") {
        totalSupplyAtStartOfYear=initialSupply*(10**18);
        _mint(msg.sender, initialSupply*(10**18));
    }
modifier onlyRewardContracts{
bool isRewardContract;
for(uint i=0; i<rewardContracts.length; i++){
if(msg.sender==rewardContracts[i]){
  isRewardContract=true;
}
}
require(isRewardContract==true,"Unauthorised");
_;
}
mapping(uint256 => uint256) private dailyMintedAmount;
modifier inflation(uint256 _rewardAmount) {
_rewardAmount=_rewardAmount*(10**18); 
uint256 currentDay = block.timestamp / 86400;
uint256 maxMintableAmount = totalSupplyAtStartOfYear * inflationRate*10**16 / 365 / (10**18);
require(_rewardAmount > 0, "Amount should be more than 0");
require(_rewardAmount <= maxMintableAmount, "Requested amount exceeds max mintable amount");
require(dailyMintedAmount[currentDay] + _rewardAmount <= maxMintableAmount, "Daily mintable amount exceeded");
_;
dailyMintedAmount[currentDay] += _rewardAmount;
if (block.timestamp >= (totalSupplyAtStartOfYear + 365 days)) {
totalSupplyAtStartOfYear = totalSupply();
}
}
function setRewardContract(address _address) onlyOwner public{
rewardContracts.push(_address);
}
function removeRewardContract(uint _index) onlyOwner public{
delete rewardContracts[_index];
}

function reward(uint _rewardAmount) onlyRewardContracts inflation(_rewardAmount) public{
_mint(msg.sender,_rewardAmount*(10**18));
emit Mint(_rewardAmount);
}
function burn(uint _burnAmount) onlyOwner public{
_burn(msg.sender,_burnAmount*(10**18));
emit Burn(_burnAmount);
}
}
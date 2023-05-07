// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PaymentInterface{
  // Logged when a user will claim their reward.
  event MakePayment(address indexed user, uint amount);
}
contract Payment is Ownable, PaymentInterface{
  IERC20 ITContract;
  address[] public whitelistedContracts;
modifier onlyWhitelistedContracts{
bool isWhitelistedContract;
for(uint i=0; i<whitelistedContracts.length; i++){
if(msg.sender==whitelistedContracts[i]){
  isWhitelistedContract=true;
}
}
require(isWhitelistedContract==true,"Unauthorised");
_;
}
function whitelistContract(address _address) onlyOwner public{
whitelistedContracts.push(_address);
}
  function setITContract(address _address) onlyOwner public{
  ITContract=IERC20(_address);
}
function contractPayment(address _from, uint _amount) onlyWhitelistedContracts public{
  ITContract.transferFrom(_from, address(this), _amount);
  emit MakePayment(_from,_amount);
}
function directPayment(uint _amount) public{
  ITContract.transferFrom(msg.sender, address(this), _amount);
  emit MakePayment(msg.sender,_amount);
}
  function withdrawIT() onlyOwner public{
         ITContract.transfer(msg.sender, ITContract.balanceOf(address(this)));
  }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IT.sol";
interface PaymentInterface{
  // Logged when a user makes a payment.
  event MakePayment(address indexed user, string wereplTxid, uint amount);
}
contract Payment is Ownable, PaymentInterface{
  IT ITContract;
  uint public burnableIT;
  uint public lastBurn;
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

function removeWhitelistedContract(uint _index) onlyOwner public{
delete whitelistedContracts[_index];
}

  function setITContract(address _address) onlyOwner public{
  ITContract=IT(_address);
}
function contractPayment(address _from, uint _amount) onlyWhitelistedContracts public{
  ITContract.transferFrom(_from, address(this), _amount);
  burnableIT+=(_amount*20)/100;
  emit MakePayment(_from,"0",_amount);
}
function directPayment(string memory _wereplTxid ,uint _amount) public{
  ITContract.transferFrom(msg.sender, address(this), _amount);
  burnableIT+=(_amount*20)/100;
  emit MakePayment(msg.sender,_wereplTxid,_amount);
}
  function withdrawIT() onlyOwner public{
         require(ITContract.balanceOf(address(this))-burnableIT>0,"insufficient funds");
         ITContract.transfer(msg.sender, ITContract.balanceOf(address(this))-burnableIT);
  }
    function burnIT() onlyOwner public{
      require(lastBurn +  90 days <= block.timestamp, "In one quarter, only one burn is allowed.");        
      ITContract.burn(burnableIT);
      burnableIT=0;
      lastBurn=block.timestamp;
  }
}
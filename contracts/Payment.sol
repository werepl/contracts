// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IT.sol";
interface PaymentInterface{
  // Logged when a user makes a payment using contracts.
  event ContractPayment(address indexed user, uint amount);
  // Logged when a user makes a payment without contracts.
  event DirectPayment(address indexed user, string wereplTxid, uint ITAmount, uint BNBAmount);
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
  emit ContractPayment(_from,_amount);
}
function directPayment(string memory _wereplTxid ,uint _ITamount) payable public{
  if(_ITamount>0){
  ITContract.transferFrom(msg.sender, address(this), _ITamount);
  burnableIT+=(_ITamount*20)/100;
  }
  emit DirectPayment(msg.sender,_wereplTxid,_ITamount,msg.value);
}
  function withdraw()  onlyOwner public{
         if(ITContract.balanceOf(address(this))-burnableIT>0){
         ITContract.transfer(msg.sender, ITContract.balanceOf(address(this))-burnableIT);
         }
         if(address(this).balance>0){
         (bool success,) = msg.sender.call{value: address(this).balance}("");
         require(success);
         }
  }
    function burnIT() onlyOwner public{
      require(lastBurn +  90 days <= block.timestamp, "In one quarter, only one burn is allowed.");        
      ITContract.burn(burnableIT);
      burnableIT=0;
      lastBurn=block.timestamp;
  }
}
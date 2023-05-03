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
  function setITContract(address _address) onlyOwner public{
  ITContract=IERC20(_address);
}
function makePayment(address _from, uint _amount) public{
  ITContract.transferFrom(_from, address(this), _amount*(10**18));
  emit MakePayment(msg.sender,_amount);
}
  function withdrawIT() onlyOwner public{
         ITContract.transfer(msg.sender, ITContract.balanceOf(address(this)));
  }
}
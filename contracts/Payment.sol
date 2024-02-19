// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IT.sol";

// Interface for Payment contract
interface PaymentInterface {
    // Logged when a whitelisted contract makes a payment.
    event ContractPayment(address indexed user, uint amount);
    // Logged when a user makes a payment.
    event DirectPayment(address indexed user, string wereplTxid, uint ITAmount, uint BNBAmount);
}

// Payment contract
contract Payment is Ownable, PaymentInterface {
    IT ITContract;
    address[] public whitelistedContracts;

    // Modifier to restrict access to whitelisted contracts
    modifier onlyWhitelistedContracts {
        bool isWhitelistedContract;
        for (uint i = 0; i < whitelistedContracts.length; i++) {
            if (msg.sender == whitelistedContracts[i]) {
                isWhitelistedContract = true;
            }
        }
        require(isWhitelistedContract == true, "Unauthorised");
        _;
    }

    // Function to whitelist a contract
    function whitelistContract(address _address) onlyOwner public {
        whitelistedContracts.push(_address);
    }

    // Function to remove a whitelisted contract
    function removeWhitelistedContract(uint _index) onlyOwner public {
        delete whitelistedContracts[_index];
    }

    // Function to set the IT contract address
    function setITContract(address _address) onlyOwner public {
        ITContract = IT(_address);
    }

    // Function to make a payment using a contract
    function contractPayment(address _from, uint _amount) onlyWhitelistedContracts public {
        ITContract.transferFrom(_from, address(this), _amount);
        emit ContractPayment(_from, _amount);
    }

    // Function to make a payment directly
    function directPayment(string calldata _wereplTxid, uint _ITamount) payable public {
        if (_ITamount > 0) {
            ITContract.transferFrom(msg.sender, address(this), _ITamount);
        }
        emit DirectPayment(msg.sender, _wereplTxid, _ITamount, msg.value);
    }

    // Function to withdraw funds
    function withdraw() onlyOwner public {
        if (ITContract.balanceOf(address(this)) > 0) {
            ITContract.transfer(msg.sender, ITContract.balanceOf(address(this)));
        }
        if (address(this).balance > 0) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            require(success);
        }
    }

    // Function to burn IT tokens
    function burnIT(uint _amount) onlyOwner public {
        ITContract.burn(_amount);
    }
}

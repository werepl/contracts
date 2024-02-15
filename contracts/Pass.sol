// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Reward.sol";

interface PassInterface{
  // Logged when the price of pro passes change.
  event PriceChange(uint[2] oldPrice, uint[2] newPrice);
  // Logged when a user mints an pass.
  event Mint(uint indexed passId);
  // Logged when the user renews their pass.
  event Renew(uint indexed passId);
  // Logged when a new entry is added to the pass.
  event NewEntry(uint indexed passId, string indexed propId, address indexed validator);
}
contract Pass is ERC721, ERC721URIStorage, Ownable, PassInterface {
 using Counters for Counters.Counter;
 Counters.Counter private _tokenIds;
address validateContractAddress;
address wereplAddress;
Reward rewardContract;
struct pass {
address owner;
uint entries;
uint expiry;
}
struct passEntry{
string propId;
string domain;
string TOA;
address  validator;
uint    timestamp;
}

mapping(address=>uint) public passIds;
mapping(uint=>pass) public passDetails;
mapping(uint=>passEntry[]) private passEntries;
    constructor(address _wereplAddress)
     ERC721("WereplPass", "Pass") {
              _tokenIds.increment();
              wereplAddress=_wereplAddress;
    }
function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
super._burn(tokenId);
}
 
function tokenURI(uint256 tokenId)
public
view
override(ERC721, ERC721URIStorage)
returns (string memory)
{
return super.tokenURI(tokenId);
}
function _beforeTokenTransfer(
address from, 
address to, 
uint256 tokenId,
uint256 batchSize) internal override virtual {
require(from == address(0) || to == address(0), "Passes are non-transferable");   
super._beforeTokenTransfer(from, to, tokenId, batchSize);  
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

function getPassEntries(uint _passId) public view returns(passEntry[] memory){
return passEntries[_passId];
}
function setValidateContract(address _address) onlyOwner public{
  validateContractAddress=_address;
}
function setRewardContract(address _address) onlyOwner public{
  rewardContract=Reward(payable(_address));
}
    function mint(address _to, string memory _URI) onlyWerepl external
    {
      require(passIds[_to]==0,"Already minted");
          uint tokenId = _tokenIds.current();
         _mint(_to,tokenId);
        _setTokenURI(tokenId, _URI);
        _tokenIds.increment();
         passDetails[tokenId]=pass(_to,0,block.timestamp+365 days);
        passIds[_to]=tokenId;
        emit Mint(tokenId);
    }
    function renew(uint _passId) onlyWerepl external {
        require(balanceOf(passDetails[_passId].owner)!=0,"You don't have pass");
        passDetails[passIds[passDetails[_passId].owner]]=pass(passDetails[_passId].owner,passDetails[_passId].entries,block.timestamp+365 days);
        emit Renew(_passId);
    }
   function entry(uint _passId, string memory _propId ,string memory _domain, string memory _TOA, address _validator) onlyValidateContract public{
  require(balanceOf(passDetails[_passId].owner)!=0&&block.timestamp<passDetails[_passId].expiry,"Don't have pass");
   passDetails[_passId].entries=passDetails[_passId].entries+1;
   passEntry memory newEntry;
   newEntry.propId=_propId;
   newEntry.domain=_domain;
   newEntry.TOA=_TOA;
   newEntry.validator=_validator;
   newEntry.timestamp=block.timestamp;
   passEntries[_passId].push(newEntry);
   rewardContract.reward(_passId,address(0));
   emit NewEntry(_passId,_propId,_validator);
   }
}
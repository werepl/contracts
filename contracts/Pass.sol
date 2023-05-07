// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Reward.sol";
import "./Payment.sol";

interface PassInterface{
  // Logged when the price of pro passes change.
  event ProPassPriceChange(uint oldPrice, uint newPrice);
  // Logged when a user mints an pass.
  event Mint(uint indexed passId,address indexed owner, string passType);
  // Logged when the user renews their pass.
  event Renew(uint indexed passId,address indexed owner);
  // Logged when a new entry is added to the pass.
  event NewEntry(uint indexed passId, string indexed propId, address indexed validator);
}
contract Pass is ERC721, ERC721URIStorage, Ownable, PassInterface {
 using Counters for Counters.Counter;
 Counters.Counter private _tokenIds;
address validateContractAddress;
Reward rewardContract;
Payment paymentContract;
uint proPassPrice;
struct pass {
address owner;
string passType;
uint entriesCompleted;
uint entriesRemaining;
}
struct passEntry{
string propId;
string domain;
address  validator;
uint    timestamp;
}

mapping(address=>uint) public passIds;
mapping(uint=>pass) public passDetails;
mapping(uint=>passEntry[]) private passEntries;
    constructor(uint _proPassPrice)
     ERC721("WereplPass", "Pass") {
              _tokenIds.increment();
              proPassPrice=_proPassPrice;

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
function setPaymentContract(address _address) onlyOwner public{
  paymentContract=Payment(_address);
}
function setProPassPrice(uint _price) onlyOwner public{
  emit ProPassPriceChange(proPassPrice,_price);
  proPassPrice=_price;
}
    function mint(string memory _type) external returns (uint256)
    {
      require(passIds[msg.sender]==0,"Already minted");
  if (keccak256(abi.encodePacked(_type)) != keccak256(abi.encodePacked('basic'))&&keccak256(abi.encodePacked(_type)) != keccak256(abi.encodePacked('pro'))) {
  revert();
  }
   uint tokenId = _tokenIds.current();
  if (keccak256(abi.encodePacked(_type)) == keccak256(abi.encodePacked('basic'))) {
        passDetails[tokenId]=pass(msg.sender,"basic",0,5);
           _mint(msg.sender,tokenId);
           string memory URI = "https://ipfs.io/ipns/k51qzi5uqu5dl60tew1ueo64yp9pzrhgizhaqzipy68c11kqh1ymknjd9pb3ws";
        _setTokenURI(tokenId, URI);
        _tokenIds.increment();
        emit Mint(tokenId,msg.sender,"basic");
        }else{
        paymentContract.contractPayment(msg.sender, proPassPrice);
         _mint(msg.sender,tokenId);
        _setTokenURI(tokenId, Strings.toString(tokenId));
        _tokenIds.increment();
         passDetails[tokenId]=pass(msg.sender,"pro",0,30);
         emit Mint(tokenId,msg.sender,"pro");
        }
        passIds[msg.sender]=tokenId;
        return tokenId;
    }

    function renew()
       external
    {
      require(balanceOf(msg.sender)!=0,"You don't have pass");
        paymentContract.contractPayment(msg.sender, proPassPrice);
        passDetails[passIds[msg.sender]]=pass(msg.sender,"pro",passDetails[passIds[msg.sender]].entriesCompleted,30);
        emit Renew(passIds[msg.sender],msg.sender);
    }
   function entry(uint _passId, string memory _propId ,string memory _domain, address _validator) onlyValidateContract public{
   passDetails[_passId].entriesCompleted=passDetails[_passId].entriesCompleted+1;
   passDetails[_passId].entriesRemaining=passDetails[_passId].entriesRemaining-1;
   passEntry memory newEntry;
   newEntry.propId=_propId;
   newEntry.domain=_domain;
   newEntry.validator=_validator;
   newEntry.timestamp=block.timestamp;
passEntries[_passId].push(newEntry);
  if (keccak256(abi.encodePacked(passDetails[_passId].passType)) == keccak256(abi.encodePacked('pro'))) {
    rewardContract.rewardUser(_passId);
  }else{
        rewardContract.rewardUser(_passId);  
  }
  emit NewEntry(_passId,_propId,_validator);
   }
}
const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");

async function main() {
  const IT = await ethers.getContractFactory("IT");
  const ITcontract = await IT.deploy();
  const Reward = await ethers.getContractFactory("Reward");
  const RewardContract = await Reward.deploy("0x2B402F4aec180Fb4188Df7a703d3861f0137855B");
  const Pass = await ethers.getContractFactory("Pass");
  const PassContract = await Pass.deploy(10);
  const Validate = await ethers.getContractFactory("Validate");
  const ValidateContract = await Validate.deploy("0x2B402F4aec180Fb4188Df7a703d3861f0137855B");
  const Payment = await ethers.getContractFactory("Payment");    
  const PaymentContract = await Payment.deploy();
  fs.writeFileSync(path.resolve("contractAddresses.json"), JSON.stringify({IT:ITcontract.address,Reward:RewardContract.address,Pass:PassContract.address,Validate:ValidateContract.address,Payment:PaymentContract.address}), (err) => {});
  console.log("done!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

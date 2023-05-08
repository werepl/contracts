const fs = require("fs");
const path = require("path");
const { ethers } = require("hardhat");
const contracts = JSON.parse(fs.readFileSync(path.resolve("contractAddresses.json")));
async function main() {
  const IT = await ethers.getContractFactory("IT");
  const ITContract = await IT.attach(contracts.IT);
  const Reward = await ethers.getContractFactory("Reward");
  const RewardContract = await Reward.attach(contracts.Reward);
  const Pass = await ethers.getContractFactory("Pass");
  const PassContract = await Pass.attach(contracts.Pass);
  const Validate = await ethers.getContractFactory("Validate");
  const ValidateContract = await Validate.attach(contracts.Validate);
  const Payment = await ethers.getContractFactory("Payment");    
  const PaymentContract = await Payment.attach(contracts.Payment);
  await ITContract.setRewardContract(contracts.Reward);
  await RewardContract.setITContract(contracts.IT);
  await RewardContract.setPassContract(contracts.Pass);
  await RewardContract.setValidateContract(contracts.Validate);
  await PassContract.setRewardContract(contracts.Reward);
  await PassContract.setValidateContract(contracts.Validate);
  await PassContract.setPaymentContract(contracts.Payment);
  await ValidateContract.setITContract(contracts.IT);
  await ValidateContract.setRewardContract(contracts.Reward);
  await ValidateContract.setPassContract(contracts.Pass);
  await ValidateContract.setPaymentContract(contracts.Payment);
  await ValidateContract.approvePaymentContract("10000000000000000000000");
  await PaymentContract.setITContract(contracts.IT);
  await PaymentContract.whitelistContract(contracts.Pass);
  await PaymentContract.whitelistContract(contracts.Validate);
  console.log("done!")
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

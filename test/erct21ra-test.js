const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BigNumber } = require("ethers");

const parseEther = ethers.utils.parseEther;

let RA_NFT;
let owner, account02, account03;
let contract;
let deployTimestamp;

let refundEndtime;
let isRefundActive;
let returnAddress;

const REFUND_TIME_ZERO = 0;
const REFUND_TIME = 60 * 60 * 24; // 1 day

const MINT_PRICE_ZERO = 0;
const MINT_PRICE = "0.1";

// TODO:
// 1. refund correctly when mint multiple token
// 2. should not withdraw when return active

beforeEach(async () => {
  [owner, account02, account03] = await ethers.getSigners();

  // Set the initial ETH balance
  await ethers.provider.send("hardhat_setBalance", [
    account02.address,
    parseEther("1").toHexString().replace("0x0", "0x"), // 1 ether
  ]);

  // Set the initial ETH balance
  await ethers.provider.send("hardhat_setBalance", [
    account03.address,
    parseEther("1").toHexString().replace("0x0", "0x"), // 1 ether
  ]);

  RA_NFT = await ethers.getContractFactory("ERC721RA_NFT");
});

describe("Test settings: ", function () {
  it("Should store return data correctly ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    refundEndtime = await contract.refundEndTime();
    isRefundActive = await contract.isRefundActive();
    returnAddress = await contract.returnAddress();

    expect(refundEndtime).to.eq(REFUND_TIME + deployTimestamp);
    expect(isRefundActive).to.eq(true);
    expect(returnAddress).to.eq(owner.address);
  });

  it("Should store correct price, when mint multiple token ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    // Mint a token from account02
    let tx = await contract
      .connect(account02)
      .mint(1, { value: parseEther(MINT_PRICE) });

    let receipt = await tx.wait();
    let tokenId01 = receipt.logs[0].topics[3];

    // Check price paid stored in contract
    let pricePaid01 = await contract.pricePaid(tokenId01);
    let priceExpected = BigNumber.from(parseEther(MINT_PRICE));
    expect(pricePaid01).to.eq(priceExpected);

    // Mint 2 tokens from account02
    tx = await contract
      .connect(account02)
      .mint(2, { value: parseEther(MINT_PRICE) });

    receipt = await tx.wait();
    let tokenId02 = receipt.logs[0].topics[3];
    let tokenId03 = receipt.logs[1].topics[3]; //get tokenId from event logs

    // Check price paid stored in contract
    let pricePaid02 = await contract.pricePaid(tokenId02);
    let pricePaid03 = await contract.pricePaid(tokenId03);
    priceExpected = BigNumber.from(parseEther(MINT_PRICE)).div(2);
    expect(pricePaid02).to.eq(priceExpected);
    expect(pricePaid03).to.eq(priceExpected);
  });
});

describe("Test Refund: ", function () {
  it("Should refund for one token ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    let contractEthBal = await ethers.provider.getBalance(contract.address);
    let acc02EthBal = await ethers.provider.getBalance(account02.address);

    // Mint a token from account02
    let tx = await contract
      .connect(account02)
      .mint(1, { value: parseEther(MINT_PRICE) });

    // Check contract balance aftermint
    expect(contractEthBal).to.eq(0);
    contractEthBal = await ethers.provider.getBalance(contract.address);
    expect(contractEthBal).to.eq(parseEther(MINT_PRICE));

    // Calculate gas used
    let receipt = await tx.wait();
    let tokenId = receipt.logs[0].topics[3]; //get tokenId from event logs
    let gasUsed = receipt.cumulativeGasUsed;
    let gasPrice = receipt.effectiveGasPrice;
    let ethUsed = gasUsed.mul(gasPrice);

    // Check new ETH balance of account02 after mint
    let acc02NewEthBal = await ethers.provider.getBalance(account02.address);
    let diffBal = acc02EthBal.sub(parseEther(MINT_PRICE)).sub(ethUsed);
    expect(acc02NewEthBal).to.eq(diffBal);

    // Check token of return address and account02
    let ownerBal = await contract.balanceOf(owner.address);
    let bal02 = await contract.balanceOf(account02.address);
    expect(ownerBal).to.eq(0);
    expect(bal02).to.eq(1);

    // refund the token
    tx = await contract.connect(account02).refund(tokenId);
    receipt = await tx.wait(); //get tokenId from event logs
    gasUsed = receipt.cumulativeGasUsed;
    gasPrice = receipt.effectiveGasPrice;
    ethUsed = gasUsed.mul(gasPrice);

    // Check the new token balance
    ownerBal = await contract.balanceOf(owner.address);
    bal02 = await contract.balanceOf(account02.address);
    expect(ownerBal).to.eq(1);
    expect(bal02).to.eq(0);

    // Check the contract ETH balance again
    contractEthBal = await ethers.provider.getBalance(contract.address);
    expect(contractEthBal).to.eq(0);
  });

  it("Should not refund for zero price ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    // Mint a token from account02 with zero price
    let tx = await contract
      .connect(account02)
      .mint(1, { value: MINT_PRICE_ZERO });

    let receipt = await tx.wait();
    let tokenId = receipt.logs[0].topics[3]; //get tokenId from event logs

    // Should be reverted with error
    await expect(
      contract.connect(account02).refund(tokenId)
    ).to.be.revertedWith("RefundZeroAmount()");
  });

  it("Should not refund for zero return time ...", async function () {
    contract = await RA_NFT.deploy(REFUND_TIME_ZERO);
    await contract.deployed();

    isRefundActive = await contract.isRefundActive();
    expect(isRefundActive).to.eq(false);

    // Mint a token from account02
    let tx = await contract
      .connect(account02)
      .mint(1, { value: parseEther(MINT_PRICE) });

    let receipt = await tx.wait();
    let tokenId = receipt.logs[0].topics[3]; //get tokenId from event logs

    // Should be reverted with error
    await expect(
      contract.connect(account02).refund(tokenId)
    ).to.be.revertedWith("RefundIsNotActive()");
  });

  it("Should not refund token after you transfer to some one else ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    // Mint a token from account02
    let tx = await contract
      .connect(account02)
      .mint(1, { value: parseEther(MINT_PRICE) });
    let receipt = await tx.wait();
    let tokenId = receipt.logs[0].topics[3]; //get tokenId from event logs

    await contract
      .connect(account02)
      ["safeTransferFrom(address,address,uint256)"](
        account02.address,
        account03.address,
        tokenId
      );
    let bal02 = await contract.balanceOf(account02.address);
    let bal03 = await contract.balanceOf(account03.address);
    expect(bal02).to.eq(0);
    expect(bal03).to.eq(1);

    // Should be reverted with error
    await expect(
      contract.connect(account02).refund(tokenId)
    ).to.be.revertedWith("RefundCallerNotOwner()");
  });

  it("Should refund if acquired from the secondary sale ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    // Mint a token from account02
    let tx = await contract
      .connect(account02)
      .mint(1, { value: parseEther(MINT_PRICE) });
    let receipt = await tx.wait();
    let tokenId = receipt.logs[0].topics[3]; //get tokenId from event logs

    // Transfer token from account 02 to 03
    await contract
      .connect(account02)
      ["safeTransferFrom(address,address,uint256)"](
        account02.address,
        account03.address,
        tokenId
      );
    let ownerBal = await contract.balanceOf(owner.address);
    let bal02 = await contract.balanceOf(account02.address);
    let bal03 = await contract.balanceOf(account03.address);
    expect(ownerBal).to.eq(0);
    expect(bal02).to.eq(0);
    expect(bal03).to.eq(1);

    // Check account03 ETH balance
    let acc03EthBal = await ethers.provider.getBalance(account03.address);

    tx = await contract.connect(account03).refund(tokenId);
    receipt = await tx.wait(); //get tokenId from event logs
    gasUsed = receipt.cumulativeGasUsed;
    gasPrice = receipt.effectiveGasPrice;
    ethUsed = gasUsed.mul(gasPrice);

    // Check if account03 can return
    ownerBal = await contract.balanceOf(owner.address);
    bal02 = await contract.balanceOf(account02.address);
    bal03 = await contract.balanceOf(account03.address);
    expect(ownerBal).to.eq(1);
    expect(bal02).to.eq(0);
    expect(bal03).to.eq(0);

    // Check if account03 receive the ETH
    let diffBal = acc03EthBal.add(parseEther(MINT_PRICE)).sub(ethUsed);
    let acc03NewBal = await ethers.provider.getBalance(account03.address);
    expect(acc03NewBal).to.eq(diffBal);
  });

  it("Should be able change the return address ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    // Mint 2 tokens from account02
    let tx = await contract
      .connect(account02)
      .mint(2, { value: parseEther(MINT_PRICE) });

    let receipt = await tx.wait();
    let tokenId01 = receipt.logs[0].topics[3];
    let tokenId02 = receipt.logs[1].topics[3]; //get tokenId from event logs

    // Check the new token balance
    let ownerBal = await contract.balanceOf(owner.address);
    let bal02 = await contract.balanceOf(account02.address);
    let bal03 = await contract.balanceOf(account03.address);
    expect(ownerBal).to.eq(0);
    expect(bal02).to.eq(2);
    expect(bal03).to.eq(0);

    // Return one token to the owner
    tx = await contract.connect(account02).refund(tokenId01);
    receipt = await tx.wait();
    ownerBal = await contract.balanceOf(owner.address);
    bal02 = await contract.balanceOf(account02.address);
    bal03 = await contract.balanceOf(account03.address);
    expect(ownerBal).to.eq(1);
    expect(bal02).to.eq(1);
    expect(bal03).to.eq(0);

    // Change the return address to account03
    await contract.setReturnAddress(account03.address);
    tx = await contract.connect(account02).refund(tokenId02);
    receipt = await tx.wait();
    ownerBal = await contract.balanceOf(owner.address);
    bal02 = await contract.balanceOf(account02.address);
    bal03 = await contract.balanceOf(account03.address);
    expect(ownerBal).to.eq(1);
    expect(bal02).to.eq(0);
    expect(bal03).to.eq(1);
  });
});

describe("Test Gas: ", function () {
  it("Mint ERC721RA ...", async function () {
    deployTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
    contract = await RA_NFT.deploy(REFUND_TIME + deployTimestamp);
    await contract.deployed();

    await contract.connect(account02).mint(1);
    await contract.connect(account02).mint(5);
    await contract.connect(account02).mint(10);
  });
});

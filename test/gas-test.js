const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test ERC721RA", function () {
  it("Test Minting ...", async function () {
    const RaNft = await ethers.getContractFactory("ERC721RA_NFT");
    const raNft = await RaNft.deploy(100000000000, true, "{Some_Address}");
    await raNft.deployed();

    const mintOneTx = await raNft.mintERC721RA(1);

    const mintTenTx = await raNft.mintERC721RA(10);
  });
});

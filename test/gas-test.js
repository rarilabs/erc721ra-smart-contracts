const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test Gas", function () {
  it("Test ERC721RA ...", async function () {
    const RaNft = await ethers.getContractFactory("ERC721RA_NFT");
    const raNft = await RaNft.deploy(100000000000);
    await raNft.deployed();

    await raNft.mint(10);
  });
});

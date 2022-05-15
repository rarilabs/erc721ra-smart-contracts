const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Test ERC721RA", function () {
  it("Test Minting ...", async function () {
    const RaNft = await ethers.getContractFactory("ERC721RA_NFT");
    const raNft = await RaNft.deploy(
      100,
      true,
      "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
    );
    await raNft.deployed();

    const mintOneTx = await raNft.mintERC721RA(1);

    const mintTenTx = await raNft.mintERC721RA(10);
  });
});

describe("Test ERC721A", function () {
  it("Test Minting ...", async function () {
    const ANFT = await ethers.getContractFactory("ERC721A_NFT");
    const aNft = await ANFT.deploy();
    await aNft.deployed();

    const mintOneTx = await aNft.mintERC721A(1);

    const mintTenTx = await aNft.mintERC721A(10);
  });
});

// describe("Greeter", function () {
//   it("Should return the new greeting once it's changed", async function () {
//     const Greeter = await ethers.getContractFactory("Greeter");
//     const greeter = await Greeter.deploy("Hello, world!");
//     await greeter.deployed();

//     expect(await greeter.greet()).to.equal("Hello, world!");

//     const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

//     // wait until the transaction is mined
//     await setGreetingTx.wait();

//     expect(await greeter.greet()).to.equal("Hola, mundo!");
//   });
// });

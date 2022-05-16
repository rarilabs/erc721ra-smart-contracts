![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra-banner.png)

# ERC721RA - refundable and gas optimized NFT

![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra.png)

## What is ERC721RA?

ERC721RA is an improved NFT standard for ERC721 with significant gas saving for multiple minting and refund implementation.

For more information please visit [erc721ra.org](https://erc721ra.org). Follow us on twitter for [@ERC721RA](https://twitter.com/rec721ra) the latest updates. Join our [Github](https://github.com/erc721ra) project to collaborate.

**Rari Labs is not liable for any outcome of using ERC721RA**

## Gas Comparison ERC721RA vs ERC721A

```
·--------------------------------------|----------------------------|-------------|----------------------------·
|         Solc version: 0.8.7          ·  Optimizer enabled: false  ·  Runs: 200  ·  Block limit: 6718946 gas  │
·······································|····························|·············|·····························
|  Methods                                                                                                     │
·················|·····················|·············|··············|·············|··············|··············
|  Contract      ·  Method             ·  Min        ·  Max         ·  Avg        ·  # calls     ·  usd (avg)  │
·················|·····················|·············|··············|·············|··············|··············
|  ERC721A_NFT   ·  mint_1x_ERC721A    ·      57326  ·       91526  ·      60746  ·          10  ·          -  │
·················|·····················|·············|··············|·············|··············|··············
|  ERC721A_NFT   ·  mint_10x_ERC721A   ·      74965  ·      109165  ·      78074  ·          11  ·          -  │
·················|·····················|·············|··············|·············|··············|··············
|  ERC721RA_NFT  ·  mint_1x_ERC721RA   ·      60057  ·      77157   ·      61612  ·          11  ·          -  │
·················|·····················|·············|··············|·············|··············|··············
|  ERC721RA_NFT  ·  mint_10x_ERC721RA  ·      77862  ·       94962  ·      79417  ·          11  ·          -  │
·················|·····················|·············|··············|·············|··············|··············
|  Deployments                         ·                                          ·  % of limit  ·             │
·······································|·············|··············|·············|··············|··············
|  ERC721A_NFT                         ·          -  ·           -  ·    2144788  ·      31.9 %  ·          -  │
·······································|·············|··············|·············|··············|··············
|  ERC721RA_NFT                        ·          -  ·           -  ·    3024696  ·        45 %  ·          -  │
·--------------------------------------|-------------|--------------|-------------|--------------|-------------·

```

## Get Started

Install Hardhat

```
yarn add hardhat

```

Install following to run the sample project

```
yarn add @nomiclabs/hardhat-waffle ethereum-waffle chai @nomiclabs/hardhat-ethers ethers @nomiclabs/hardhat-etherscan hardhat-gas-reporter solidity-coverage @openzeppelin/contracts
```

## Usage

```
pragma solidity ^0.8.7;

import "./ERC721RA.sol";

contract Rari is ERC721RA {
  constructor() ERC721RA("Rari", "RARI") {}

  function mint(uint256 amount) external payable {
    _safeMint(_msgSender(), amount);
  }

  function refund(uint256 tokenId) external {
      _refund(_msgSender(), tokenId);
  }
}

```

# ERC721RA - refundable and gas optimized NFT


![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra-small.png)


## What is ERC721RA?

ERC721RA is an improved NFT standard for ERC721 with significant gas saving for multiple minting and refund implementation.

For more information please visit [erc721ra.org](https://erc721ra.org). Follow us on twitter for [@ERC721RA](https://twitter.com/rec721ra) the latest updates. Join our [Github](https://github.com/erc721ra) project to collaborate.

**Rari Labs is not liable for any outcome of using ERC721RA**


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


![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra-banner.png)

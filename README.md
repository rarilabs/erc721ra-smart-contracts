# ERC721RA (v1.0 Beta) - refundable and gas optimized NFT

![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra-small.png)

## What is ERC721RA?

ERC721RA is an improved implementation of ERC721A with refundability and gas saving. It gives NFT owners freedom to return minted NFTs and get refund within a given time.

The goal of this project is to encourage the adoption of ERC721RA NFT and improve creators credibility.

For more information please visit [erc721ra.org](https://erc721ra.org). Follow us on twitter for [@ERC721RA](https://twitter.com/erc721ra) the latest updates. Join our [Github](https://github.com/erc721ra) project to collaborate.

ERC721RA was initially created by WIL ZEE from Rari Labs for the NFT social 3.0 project.

Rari Labs is not liable for any outcome of using ERC721RA

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

## Contact

**Check [Contributors List](https://github.com/ERC721RA/.github/blob/main/profile/README.md)**

**Join ERC721RA as a contributor: [Apply Now](https://forms.gle/32uiJ6d7e8McddaK6)**

## License

Distribution under the MIT License.

![ERC721RA](https://raw.githubusercontent.com/rarilabs/ERC721RA/main/assets/erc721ra-banner.png)

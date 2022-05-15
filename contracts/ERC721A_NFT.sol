/***
 * SPDX-License-Identifier: MIT
 * Creator: Rari Labs  
 * Author: Will Qian
 */
pragma solidity ^0.8.7;

import "erc721a/contracts/ERC721A.sol";

contract ERC721A_NFT is ERC721A {
  constructor() ERC721A("ERC721A_NFT", "ANFT") {}

  function mintERC721A(uint256 amount) external payable {
    _safeMint(_msgSender(), amount);
  }
}
/***
 *  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 *   ░░███████╗░██████╗░░░█████╗░░███████╗░░█████╗░░░░██╗░██████╗░░░█████╗░░░
 *   ░░██╔════╝░██╔══██╗░██╔══██╗░░╚══██╔╝░██╔══██╗░████║░██╔══██╗░██╔══██╗░░
 *   ░░██████╗░░██████╔╝░██║░░╚═╝░░░░██╔╝░░╚═╝███╔╝░░░██║░██████╔╝░███████║░░
 *   ░░██╔═══╝░░██╔══██╗░██║░░██╗░░░██╔╝░░░░███╔═╝░░░░██║░██╔══██╗░██╔══██║░░
 *   ░░███████╗░██║░░██║░╚█████╔╝░░░██║░░░░███████╗░░░██║░██║░░██║░██║░░██║░░
 *   ░░╚══════╝░╚═╝░░╚═╝░░╚════╝░░░░╚═╝░░░░╚══════╝░░░╚═╝░╚═╝░░╚═╝░╚═╝░░╚═╝░░
 *  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 *
 * SPDX-License-Identifier: MIT
 * Creator: Rari Labs  
 * Author: Will Qian
 * Version: ERC721RA Smart Contracts v1.0
 *
 * ERC721RA is an improved implementation of ERC721A with refundability and gas optimization. 
 * The goal is to give NFT owners freedom to return the NFTs and get refund.
 * 
 */
pragma solidity >=0.8.4 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

error ApprovalCallerNotOwnerNorApproved();
error ApproveToCaller();
error ApprovalToCurrentOwner();
error MintZeroAmount();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error QueryForTokenNotExist();
error RefundIsNotActive();
error RefundTokenHasBeenBurned();
error RefundCallerNotOwner();
error RefundHasAlreadyBeenMade();
error RefundNotSucceed();
error WithdrawWhenRefundIsActive();
error WithdrawNotSucceed();
error TransactToZeroAddress();

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension. Built to optimize for lower gas during batch mints.
 */
contract ERC721RA is Context, ERC165, IERC721, IERC721Metadata, Ownable {
    using Address for address;
    using Strings for uint256;

    // Token ownership to track token 
    struct TokenData {
        // Keeps track of the start time of ownership with minimal overhead for tokenomics.
        uint256 startTimestamp;
        // The address of the owner.
        address addr;
        // Whether the token has been burned.
        bool burned;
        // Track refund information of each token. 
        // Token can be returned even they're not owned by minter.
        // Only allowed to refund once
        // Keeps track of the price paid by minter
        uint256 pricePaid;
        // Whether token has been refunded
        bool refunded;
    }

    // Owner data to track against token balance
    struct OwnerData {
        // Token balance
        uint256 balance;
        // Number of tokens minted
        uint256 numberMinted;
        // Number of tokens burned
        uint256 numberBurned;
        // Number of tokens refunded
        uint256 numberRefunded;
    }

    // The tokenId of the next token to be minted.
    uint256 internal _currentIndex;

    // The number of tokens burned.
    uint256 internal _burnCounter;

    // The number of tokens burned.
    uint256 internal _refundCounter;

    // The refund end timestamp
    uint256 private _refundEndTime;

    // Whether the refund is enabled
    bool private _refundEnabled;

    // The return address to transfer token to
    address private _returnAddress;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See _ownerOf implementation for details.
    mapping(uint256 => TokenData) internal _owners;

    // Mapping owner address to address data
    mapping(address => OwnerData) private _ownerData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_, uint256 refundEndTime_, bool refundEnabled_, address returnAddress_) {
        _name = name_;
        _symbol = symbol_;

        _refundEndTime = refundEndTime_;
        _refundEnabled = refundEnabled_;
        _returnAddress = returnAddress_;

        _currentIndex = _startTokenId();
    }

    /**
     * @dev To change the starting tokenId, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Burned tokens are calculated here, use _totalMinted() if you want to count just minted tokens.
     */
    function totalSupply() external view returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than _currentIndex - _startTokenId() times
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /**
     * @dev Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view returns (uint256) {
        // Counter underflow is impossible as _currentIndex does not decrement,
        // and it is initialized to _startTokenId()
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) external view override returns (uint256) {
        return _ownerData[owner].balance;
    }

    /**
     * @dev Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return _ownerData[owner].numberMinted;
    }

    /**
     * @dev Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return _ownerData[owner].numberBurned;
    }

    /**
     * @dev Returns the auxillary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _numberRefunded(address owner) internal view returns (uint256) {
        return _ownerData[owner].numberRefunded;
    }

    /**
     * @dev Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function _ownerOf(uint256 tokenId) internal view returns (TokenData memory) {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr && curr < _currentIndex) {
                TokenData memory ownership = _owners[curr];
                if (!ownership.burned) {
                    if (ownership.addr != address(0)) {
                        return ownership;
                    }
                    // Invariant:
                    // There will always be an ownership that has an address and is not burned
                    // before an ownership that does not have an address and is not burned.
                    // Hence, curr will not underflow.
                    while (true) {
                        curr--;
                        ownership = _owners[curr];
                        if (ownership.addr != address(0)) {
                            return ownership;
                        }
                    }
                }
            }
        }
        revert QueryForTokenNotExist();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _ownerOf(tokenId).addr;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert QueryForTokenNotExist();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) external override {
        address owner = ERC721RA.ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        if (!_exists(tokenId)) revert QueryForTokenNotExist();

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == _msgSender()) revert ApproveToCaller();

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        _transfer(from, to, tokenId);
        if (to.isContract() && !_checkContractOnERC721Received(from, to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _startTokenId() <= tokenId && tokenId < _currentIndex && !_owners[tokenId].burned;
    }

    /**
     * Equivalent to `_safeMint(to, amount, '')`.
     */
    function _safeMint(address to, uint256 amount) internal {
        _safeMint(to, amount, "");
    }

    /**
     * @dev Safely mints `amount` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement 
     *   {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `amount` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 amount, bytes memory _data) internal {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert TransactToZeroAddress();
        if (amount == 0) revert MintZeroAmount();

        _beforeTokenTransfers(address(0), to, startTokenId, amount);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + amount > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + amount > 1.2e77 (2**256) - 1
        unchecked {
            _ownerData[to].balance += amount;
            _ownerData[to].numberMinted += amount;

            _owners[startTokenId].addr = to;
            _owners[startTokenId].startTimestamp = block.timestamp;
            _owners[startTokenId].pricePaid = msg.value / amount;

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + amount;

            if (to.isContract()) {
                do {
                    emit Transfer(address(0), to, updatedIndex);
                    if (!_checkContractOnERC721Received(address(0), to, updatedIndex++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (updatedIndex != end);
                // Reentrancy protection
                if (_currentIndex != startTokenId) revert();
            } else {
                do {
                    emit Transfer(address(0), to, updatedIndex++);
                } while (updatedIndex != end);
            }
            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, amount);
    }

    /**
     * @dev Mints `amount` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `amount` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 amount) internal {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert TransactToZeroAddress();
        if (amount == 0) revert MintZeroAmount();

        _beforeTokenTransfers(address(0), to, startTokenId, amount);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + amount > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + amount > 1.2e77 (2**256) - 1
        unchecked {
            _ownerData[to].balance += amount;
            _ownerData[to].numberMinted += amount;

            _owners[startTokenId].addr = to;
            _owners[startTokenId].startTimestamp = block.timestamp;
            _owners[startTokenId].pricePaid = msg.value / amount;

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + amount;

            do {
                emit Transfer(address(0), to, updatedIndex++);
            } while (updatedIndex != end);

            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, amount);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) private {
        TokenData memory prevOwnership = _ownerOf(tokenId);

        if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();

        bool isApprovedOrOwner = (_msgSender() == from ||
            isApprovedForAll(from, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        if (to == address(0)) revert TransactToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, from);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _ownerData[from].balance -= 1;
            _ownerData[to].balance += 1;

            TokenData storage currSlot = _owners[tokenId];
            currSlot.addr = to;
            currSlot.startTimestamp = block.timestamp;

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            TokenData storage nextSlot = _owners[nextTokenId];
            if (nextSlot.addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId != _currentIndex) {
                    nextSlot.addr = from;
                    nextSlot.startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Equivalent to `_burn(tokenId, false)`.
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        TokenData memory prevOwnership = _ownerOf(tokenId);

        address from = prevOwnership.addr;

        if (approvalCheck) {
            bool isApprovedOrOwner = (_msgSender() == from ||
                isApprovedForAll(from, _msgSender()) ||
                getApproved(tokenId) == _msgSender());

            if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        }

        _beforeTokenTransfers(from, address(0), tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, from);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            OwnerData storage ownerData = _ownerData[from];
            ownerData.balance -= 1;
            ownerData.numberBurned += 1;

            // Keep track of who burned the token, and the timestamp of burning.
            TokenData storage currSlot = _owners[tokenId];
            currSlot.addr = from;
            currSlot.startTimestamp = block.timestamp;
            currSlot.burned = true;

            // If the ownership slot of tokenId+1 is not explicitly set, that means the burn initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            TokenData storage nextSlot = _owners[nextTokenId];
            if (nextSlot.addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId != _currentIndex) {
                    nextSlot.addr = from;
                    nextSlot.startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, address(0), tokenId);
        _afterTokenTransfers(from, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            _burnCounter++;
        }
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * emit a {Approval} event.
     */
    function _approve(address to, uint256 tokenId, address owner) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkContractOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
            return retval == IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * startTokenId - the first token id to be transferred
     * amount - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     * And also called after one token has been burned.
     *
     * startTokenId - the first token id to be transferred
     * amount - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 amount) internal virtual {}

    /**
     * @dev Set the return address
     */
    function setReturnAddress(address to) external onlyOwner {
        _returnAddress = to;
    }

    /**
     * @dev Get the return address 
     */
    function returnAddress() external view returns (address) {
        return _returnAddress;
    }

    /**
     * @dev Check if refund enabled 
     */
    function refundEnabled() internal view returns (bool) {
        return _refundEnabled;
    }

    /**
     * @dev Get the refund end time
     */
    function refundEndTime() internal view returns (uint256) {
        return _refundEndTime;
    }

    /**
     * @dev Check if refund is enabled and has not ended
     */
    function isRefundActive() public view returns (bool) {
        return _refundEnabled && _refundEndTime > block.timestamp;
    }

    /**
     * @dev Refund the current owner of the token
     */
    function _refund(address to, uint256 tokenId) internal {
        if (!isRefundActive()) revert RefundIsNotActive();
        if (to == address(0)) revert TransactToZeroAddress();

        if (_msgSender() != ownerOf(tokenId)) revert RefundCallerNotOwner();
        if (_owners[tokenId].burned) revert RefundTokenHasBeenBurned();
        if (_owners[tokenId].refunded) revert RefundHasAlreadyBeenMade();

        _beforeTokenTransfers(_msgSender(), _returnAddress, tokenId, 1);

        uint256 refundAmount = _owners[tokenId].pricePaid;

        _owners[tokenId].refunded = true;
        _ownerData[ownerOf(tokenId)].numberRefunded += 1;
        _refundCounter++;

        safeTransferFrom(_msgSender(), _returnAddress, tokenId);

        (bool success, ) = to.call{ value: refundAmount }("");
        if (!success) revert RefundNotSucceed();

        emit Transfer(_msgSender(), _returnAddress, tokenId);
        _afterTokenTransfers(_msgSender(), _returnAddress, tokenId, 1);
    }


    /**
     * @dev Can only withdraw after when the refund is inactive
     */
    function _withdraw(address to) internal onlyOwner {
        if (isRefundActive()) revert WithdrawWhenRefundIsActive();
        if (to == address(0)) revert TransactToZeroAddress();

        (bool success, ) = to.call{ value: address(this).balance }("");

        if (!success) revert WithdrawNotSucceed();
    }

}
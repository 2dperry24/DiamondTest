// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721Receiver} from "../interfaces/IERC721Receiver.sol";
import {IERC721Metadata} from "../interfaces/IERC721Metadata.sol";

import {LibStrings} from "../libraries/LibStrings.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC721Errors} from "../interfaces/IERC721Errors.sol";
import {LibContext} from "../libraries/LibContext.sol";

import {LibSafeERC20} from "../libraries/LibSafeERC20.sol";
import {IERC20} from "../interfaces/IERC20.sol";

import {AppStorage, Bull} from "../AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

import {ReentrancyGuard} from "../ReentrancyGuard.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC-721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */

contract MintingBullsFacet is ReentrancyGuard {
    using LibStrings for uint256;
    using LibSafeERC20 for IERC20;

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev An `owner`'s token query was out of bounds for `index`.
     *
     * NOTE: The owner being `address(0)` indicates a global out of bounds index.
     */
    error ERC721OutOfBoundsIndex(address owner, uint256 index);

    /**
     * @dev Batch mint is not allowed.
     */
    error ERC721EnumerableForbiddenBatchMint();

    //
    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert IERC721Errors.ERC721InvalidOwner(address(0));
        }

        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, LibStrings.toString(tokenId)) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.baseURI;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, LibContext.msgSender());
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(LibContext.msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        if (to == address(0)) {
            revert IERC721Errors.ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, LibContext.msgSender());
        if (previousOwner != from) {
            revert IERC721Errors.ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC-721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.owners[tokenId];
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.tokenApprovals[tokenId];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(
        address owner,
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        return spender != address(0) && (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if `spender` does not have approval from the provided `owner` for the given token or for all its assets
     * the `spender` for the specific `tokenId`.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(
        address owner,
        address spender,
        uint256 tokenId
    ) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert IERC721Errors.ERC721NonexistentToken(tokenId);
            } else {
                revert IERC721Errors.ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            AppStorage storage s = LibAppStorage.diamondStorage();
            s.balances[account] += value;
        }
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert IERC721Errors.ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert IERC721Errors.ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        if (to == address(0)) {
            revert IERC721Errors.ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert IERC721Errors.ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC-721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address auth
    ) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address auth,
        bool emitEvent
    ) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert IERC721Errors.ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (operator == address(0)) {
            revert IERC721Errors.ERC721InvalidOperator(operator);
        }

        AppStorage storage s = LibAppStorage.diamondStorage();
        s.operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert IERC721Errors.ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(LibContext.msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert IERC721Errors.ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    // ERC721 Enumerable Functions

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        if (index >= balanceOf(owner)) {
            revert ERC721OutOfBoundsIndex(owner, index);
        }

        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return s.allTokens[index];
    }

    /**
     * @dev Combined update function for ERC721 and ERC721Enumerable.
     *
     * This function integrates the transfer, mint, and burn logic from the standard ERC721
     * implementation with the additional token tracking logic required by ERC721Enumerable.
     * It is designed to ensure that the enumerable data structures are correctly updated in
     * sync with ownership changes. This integrated approach is necessary for a Diamond
     * architecture where multiple facets need to interact seamlessly and consistently.
     *
     * - For standard ERC721 transfers, the function updates token balances and clears
     *   approvals.
     * - For minting (transferring from the zero address) and burning (transferring to the
     *   zero address), it updates the total supply and the token ownership mapping.
     * - The ERC721Enumerable logic adds or removes tokens from the owner's enumeration
     *   list and updates the total list of tokens, maintaining a consistent and enumerable
     *   list of tokens and their owners.
     *
     * The function includes checks for authorization and emits the necessary Transfer event.
     * It is meant to be used internally in the ERC721 facet of the Diamond.
     *
     * @param to The address to transfer the token to, or receive the minted token.
     * @param tokenId The ID of the token being transferred or minted/burned.
     * @param auth An optional address to authorize the transfer. If non-zero, it must be
     *             either the owner of the token or an approved operator.
     * @return The address of the previous owner of the token.
     */

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal returns (address) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the standard ERC721 update logic
        if (from != address(0)) {
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                s.balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                s.balances[to] += 1;
            }
        }

        s.owners[tokenId] = to;

        // Emit the Transfer event
        emit Transfer(from, to, tokenId);

        // Execute the ERC721Enumerable specific logic
        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }

        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }

        return from;
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 length = balanceOf(to) - 1;
        s.ownedTokens[to][length] = tokenId;
        s.ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.allTokensIndex[tokenId] = s.allTokens.length;
        s.allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 lastTokenIndex = balanceOf(from);
        uint256 tokenIndex = s.ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownedTokens[from][lastTokenIndex];

            s.ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            s.ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete s.ownedTokensIndex[tokenId];
        delete s.ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 lastTokenIndex = s.allTokens.length - 1;
        uint256 tokenIndex = s.allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = s.allTokens[lastTokenIndex];

        s.allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        s.allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete s.allTokensIndex[tokenId];
        s.allTokens.pop();
    }

    // Minting Logic

    event MintedBull(address indexed minter, uint256 tokenId, uint256 mintCost, uint256 aum, uint256 grains, uint256 pillars, uint256 sheets, uint256 cubes);

    function mintBull(
        uint256 _rarity,
        address _addressToMintTo,
        uint256 _quantity
    ) external nonReentrant() {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (!s.mintLive) {
            revert("Minting is not Live");
        }
        if (_rarity < 0 || _rarity > 6) {
            revert("Rarity not within acceptable range");
        }
        if (_quantity != 1) {
            revert("You can't only mint one per transacation");
        }

        uint256 _mintCost = s.rarityProperties[_rarity].mintCost;

        // // Transfer usdc
        // IERC20(s.usdcTokenContract).safeTransferFrom(_addressToMintTo, address(this), _mintCost);

        uint256 tokenId = s.rarityProperties[_rarity].currentIndex;

        if (tokenId > s.rarityProperties[_rarity].lastIndex) {
            revert("This Tier is sold out");
        }

        _safeMint(_addressToMintTo, tokenId);
        s.rarityProperties[_rarity].currentIndex++;

        // After minting successfully, add the NFT index to the array
        s.mintedBullIndices.push(tokenId);

        // Update contract balances
        uint256 aumAmount = (_mintCost * 90) / 100;

        s.aum += aumAmount;
        s.vaultHoldingBalance += aumAmount;
        s.coreTeamBalance += _mintCost - aumAmount;

        // Initialize or update the Bull data
        Bull storage bull = s.bulls[tokenId];
        bull.rarity = _rarity;

        // Allocate Salt Grains to Minted Bull
        uint256 totalGrains;

        if (_rarity == 0) {
            bull.cubes += 3; // Allocate 2 Cubes to the tokenId
            bull.sheets += 1; // Allocate 7 Sheets to the tokenId
            bull.pillars += 1; // Allocate 7 Pillar to the tokenId
            bull.grains += 6; // Allocate 7 Grains to the tokenId
            totalGrains += 3116;
        } else if (_rarity == 1) {
            bull.cubes += 1; // Allocate 2 Cubes to the tokenId
            bull.sheets += 2; // Allocate 7 Sheets to the tokenId
            bull.pillars += 3; // Allocate 7 Pillar to the tokenId
            bull.grains += 3; // Allocate 7 Grains to the tokenId
            totalGrains += 1233;
        } else if (_rarity == 2) {
            bull.sheets += 8; // Allocate 7 Sheets to the tokenId
            bull.pillars += 7; // Allocate 7 Pillar to the tokenId
            bull.grains += 7; // Allocate 7 Grains to the tokenId
            totalGrains += 877;
        } else if (_rarity == 3) {
            bull.sheets += 5; // Allocate 7 Sheets to the tokenId
            bull.pillars += 8; // Allocate 7 Pillar to the tokenId
            bull.grains += 3; // Allocate 7 Grains to the tokenId
            totalGrains += 583;
        } else if (_rarity == 4) {
            bull.sheets += 4; // Allocate 7 Sheets to the tokenId
            bull.pillars += 1; // Allocate 7 Pillar to the tokenId
            bull.grains += 1; // Allocate 7 Grains to the tokenId
            totalGrains += 411;
        } else if (_rarity == 5) {
            bull.sheets += 2; // Allocate 7 Sheets to the tokenId
            bull.pillars += 3; // Allocate 7 Pillar to the tokenId
            bull.grains += 3; // Allocate 7 Grains to the tokenId
            totalGrains += 233;
        } else if (_rarity == 6) {
            bull.sheets += 1; // Allocate 7 Sheets to the tokenId
            bull.pillars += 1; // Allocate 7 Pillar to the tokenId
            bull.grains += 6; // Allocate 7 Grains to the tokenId
            totalGrains += 116;
        }

        // Emit event with relevant bull data
        emit MintedBull(_addressToMintTo, tokenId, s.rarityProperties[_rarity].mintCost, s.aum, bull.grains, bull.pillars, bull.sheets, bull.cubes);
    }

    // paper.xyz check for minting
    function checkClaimEligibility(uint256 _rarity, uint256 _quantity) external view returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (!s.mintLive) {
            return "Minting is not live";
        } else if (_quantity != 1) {
            return "Can only mint 1 NFT per Tx";
        } else if (s.rarityProperties[_rarity].currentIndex > s.rarityProperties[_rarity].lastIndex) {
            return "Rarity is sold out";
        } else {
            return "";
        }
    }

    // event NftMintedOtc(uint256 tokenId, uint256 rarity, uint256 grains, uint256 pillars, uint256 sheets, uint256 cubes);

    // function mintOtc(
    //     uint256 _rarity,
    //     uint256 grains,
    //     uint256 pillars,
    //     uint256 sheets,
    //     uint256 cubes
    // ) external onlyProcurementWallet {
    //     AppStorage storage s = LibAppStorage.diamondStorage();

    //     if (_rarity < 0 || _rarity > 6) {
    //         revert("Rarity not within acceptable range");
    //     }

    //     if (msg.sender != s.procurementWallet) {
    //         revert("Must be the correct wallet address");
    //     }

    //     uint256 tokenId = s.rarityProperties[_rarity].currentIndex;
    //     if (tokenId > s.rarityProperties[_rarity].lastIndex) {
    //         revert("This Tier is sold out");
    //     }
    //     _safeMint(msg.sender, tokenId);
    //     s.rarityProperties[_rarity].currentIndex++;

    //     // Initialize or update the Bull data
    //     Bull storage bull = s.bulls[tokenId];
    //     bull.rarity = _rarity;
    //     bull.grains = grains;
    //     bull.pillars = pillars;
    //     bull.sheets = sheets;
    //     bull.cubes = cubes;

    //     emit NftMintedOtc(tokenId, _rarity, grains, pillars, sheets, cubes);
    // }

  

    // IERC2981
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address, uint256 royaltyAmount) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        _tokenId; //silence solc warning
        royaltyAmount = (_salePrice * 5) / 100; // 5%
        return (s.royaltiesWallet, royaltyAmount);
    }










    function test10(address _addressToPullFrom ) external nonReentrant() {
        
        AppStorage storage s = LibAppStorage.diamondStorage();
        
        IERC20 usdcContract = IERC20(s.usdcTokenContract);
        LibSafeERC20.safeTransferFrom(usdcContract, _addressToPullFrom, address(this), 10 * 10 ** 6);

    }

}

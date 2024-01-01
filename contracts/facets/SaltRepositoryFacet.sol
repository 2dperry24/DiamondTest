// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IERC20} from "../interfaces/IERC20.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {AppStorage, Modifiers} from "../AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSafeERC20} from "../libraries/LibSafeERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {ReentrancyGuard} from "../ReentrancyGuard.sol";

contract SaltRepositoryFacet is ReentrancyGuard {
    using LibSafeERC20 for IERC20;

    function getSaltGrainPurchasePrice(
        uint256 _grains,
        uint256 _pillars,
        uint256 _sheets,
        uint256 _cubes
    ) public view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 totalCost = 0;

        totalCost += _grains * s.grainCost;
        totalCost += _pillars * s.pillarCost;
        totalCost += _sheets * s.sheetCost;
        totalCost += _cubes * s.cubeCost;

        return totalCost;
    }

    /**
    * @dev Allows a user to purchase salt grains in various forms (grains, pillars, sheets, cubes) for a specific NFT.
    *
    * This function calculates the total cost of the salt grains based on the quantities of each form and their respective costs.
    * It then ensures that the caller is the owner of the specified NFT.

    * The USDC approval works like this: approve saltVaultBulls contract for the USDC from the msg.sender
    *
    * Note:
    * - The function is marked `nonReentrant` to prevent reentrancy attacks.
    * - It's essential that the user has sufficient USDC balance and has set an adequate allowance for this contract.
    * - The function ensures ownership of the NFT to maintain the integrity of the transaction.
    *
    * @param _grains The number of salt grains to purchase.
    * @param _pillars The number of salt pillars to purchase.
    * @param _sheets The number of salt sheets to purchase.
    * @param _cubes The number of salt cubes to purchase.
    * @param nftTokenId The ID of the NFT for which the salt grains are being purchased.
    */

    function purchaseSaltGrains(
        uint256 nftTokenId,
        uint256 _grains,
        uint256 _pillars,
        uint256 _sheets,
        uint256 _cubes
    ) public nonReentrant() {
        AppStorage storage s = LibAppStorage.diamondStorage();

        // Ensure the caller owns the NFT
        require(s.owners[nftTokenId] == msg.sender, "You do not own this Bull");

        uint256 totalBaseGrains; // Total grains before applying bonus
        uint256 totalCost;

        totalCost += _grains * s.grainCost;
        totalCost += _pillars * s.pillarCost;
        totalCost += _sheets * s.sheetCost;
        totalCost += _cubes * s.cubeCost;

        totalBaseGrains += _grains * s.grainCount;
        totalBaseGrains += _pillars * s.pillarCount;
        totalBaseGrains += _sheets * s.sheetCount;
        totalBaseGrains += _cubes * s.cubeCount;

        // Perform the USDC transfer from the payer to this contract
        IERC20(s.usdcTokenContract).safeTransferFrom(msg.sender, address(this), totalCost);

        // Update the Bull's properties based on the passed parameters
        s.bulls[nftTokenId].grains += s.grainCount;
        s.bulls[nftTokenId].pillars += s.pillarCount;
        s.bulls[nftTokenId].sheets += s.sheetCount;
        s.bulls[nftTokenId].cubes += s.cubeCount;

        // uint256 bonusGrains = _calculateBonusAmount(totalGrains);
        // bull.bonusGrains += bonusGrains;

        // Update contract balances
        s.coreTeamBalance += (totalCost * 10) / 100;
        s.vaultHoldingBalance = (totalCost * 90) / 100;
        s.aum += (totalCost * 90) / 100;

        // emit SaltCountUpdated(payer, tokenId, totalCost, grains, pillars, sheets, cubes, bonusGrains);
    }
}

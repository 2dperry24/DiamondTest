// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {IERC721} from "../interfaces/IERC721.sol";
import {AppStorage, Modifiers} from "../AppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSafeERC20} from "../libraries/LibSafeERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";


contract InfoGetterFacet  {


    AppStorage internal s;


    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
  
        uint256 ownerTokenCount = s.balances[_owner];

        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = s.ownedTokens[_owner][i];
        }
        return tokenIds;
    }



    function getBullInformation(uint256 _index) external view returns (uint256, uint256, uint256, uint256, uint256,uint256) {
        return (s.bulls[_index].rarity, s.bulls[_index].grains, s.bulls[_index].pillars, s.bulls[_index].sheets, s.bulls[_index].cubes, s.bulls[_index].totalSaltContributions );
    }



    function getMintCost(uint256 rarity) external view returns (uint256 cost) {
        
        return s.rarityProperties[rarity].mintCost;
    }



    function getMintStatus() external view returns (bool) {
        return s.mintLive;
    }


    // function getPausedStatus() external view returns (address) {
    //     AppStorage storage s = LibAppStorage.diamondStorage();
    //     return s.;
    // }





    function getUsdcContractAddress() external view returns (address) {
        return s.usdcTokenContract;
    }



    function getSaltVaultTokenAddress() external view returns (address) {
        return s.saltVaultTokenContract;
    }


    function getCoreTeamWalletAddress() external view returns (address) {
        return s.coreTeamWallet;
    }


    function getRoyaltiesWalletAddress() external view returns (address) {
        return s.royaltiesWallet;
    }


    function getProcurementWalletAddress() external view returns (address) {
        return s.procurementWallet;
    }


    function getBullRarityInformation(uint256 rarity) external view returns (uint256, uint256, uint256, uint256, uint256) {
        
        return (s.rarityProperties[rarity].rarity, s.rarityProperties[rarity].mintCost, s.rarityProperties[rarity].rewardMultiplier, s.rarityProperties[rarity].currentIndex, s.rarityProperties[rarity].lastIndex );
    }




    /**
     * @dev Return the total price for the mint transaction if still available and return 0 if not allowed.
    */
    function getCostAndMintEligibility(uint256 _rarity) public view returns (uint256) {


        if (s.rarityProperties[_rarity].currentIndex > s.rarityProperties[_rarity].lastIndex || !s.mintLive) {
            return 0;
        }

        uint256 transactionCost = s.rarityProperties[_rarity].mintCost;
        return transactionCost;
    }



}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
*
* Implementation of a diamond.
/******************************************************************************/

import {AppStorage} from "../AppStorage.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import { IDiamondLoupe } from "../interfaces/IDiamondLoupe.sol";
import { IDiamondCut } from "../interfaces/IDiamondCut.sol";
import { IERC173 } from "../interfaces/IERC173.sol";
import { IERC165 } from "../interfaces/IERC165.sol";


// It is expected that this contract is customized if you want to deploy your diamond
// with data from a deployment script. Use the init function to initialize state variables
// of your diamond. Add parameters to the init funciton if you need to.

contract DiamondInit {    

    // You can add parameters to this function in order to pass in 
    // data to set your own state variables
    function init() external {
        // adding ERC165 data
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;


        AppStorage storage s = LibAppStorage.diamondStorage();
        // rarity Multipliers
        s.rarityProperties[0].rarity = 0;
        s.rarityProperties[1].rarity = 1;
        s.rarityProperties[2].rarity = 2;
        s.rarityProperties[3].rarity = 3;
        s.rarityProperties[4].rarity = 4;
        s.rarityProperties[5].rarity = 5;
        s.rarityProperties[6].rarity = 6;

        // rarity Multipliers
        s.rarityProperties[0].rewardMultiplier = 300;
        s.rarityProperties[1].rewardMultiplier = 200;
        s.rarityProperties[2].rewardMultiplier = 175;
        s.rarityProperties[3].rewardMultiplier = 150;
        s.rarityProperties[4].rewardMultiplier = 130;
        s.rarityProperties[5].rewardMultiplier = 115;
        s.rarityProperties[6].rewardMultiplier = 100;


        // rarity Cost USDC
        s.rarityProperties[0].mintCost = 2500 * 10 ** 6;
        s.rarityProperties[1].mintCost = 1000 * 10 ** 6;
        s.rarityProperties[2].mintCost = 750 * 10 ** 6;
        s.rarityProperties[3].mintCost = 500 * 10 ** 6;
        s.rarityProperties[4].mintCost = 350 * 10 ** 6;
        s.rarityProperties[5].mintCost = 200 * 10 ** 6;
        s.rarityProperties[6].mintCost = 100 * 10 ** 6;
    

        // Starting Index 
        s.rarityProperties[0].currentIndex = 1;
        s.rarityProperties[1].currentIndex = 51;
        s.rarityProperties[2].currentIndex = 501;
        s.rarityProperties[3].currentIndex = 2001;
        s.rarityProperties[4].currentIndex = 4001;
        s.rarityProperties[5].currentIndex = 6001;
        s.rarityProperties[6].currentIndex = 8001;

        // Ending Index
        s.rarityProperties[0].lastIndex = 50;
        s.rarityProperties[1].lastIndex = 500;
        s.rarityProperties[2].lastIndex = 2000;
        s.rarityProperties[3].lastIndex = 4000;
        s.rarityProperties[4].lastIndex = 6000;
        s.rarityProperties[5].lastIndex = 8000;
        s.rarityProperties[6].lastIndex = 10000;


        // where each bonus changes based on AUM 
        s.bonusDetails.bonusCapStage1 = 100000 * 10**6;
        s.bonusDetails.bonusCapStage2 = 250000 * 10**6;
        s.bonusDetails.bonusCapStage3 = 500000 * 10**6;
        s.bonusDetails.bonusCapStage4 = 750000 * 10**6;
        s.bonusDetails.bonusCapStage5 = 1000000 * 10**6;

        // represents the bonus % out of 100; 10 is 10%
        s.bonusDetails.stage1Bonus = 10;
        s.bonusDetails.stage2Bonus = 8;
        s.bonusDetails.stage3Bonus = 6;
        s.bonusDetails.stage4Bonus = 4;
        s.bonusDetails.stage5Bonus = 2;

        s.baseExtension = ".json";
        s.name = "Salt Vault Bulls";
        s.symbol = "SVB";


        // Initialize allowed compounding rates
        for (uint256 i = 0; i <= 10; i++) {
            s.allowedCompoundingRates[i * 10] = true; // 0, 10, 20, ..., 100
        }




        // Salt Repository
        s.grainCost = 1 * 10**6;
        s.pillarCost = 9 * 10**6;
        s.sheetCost = 85 * 10**6;
        s.cubeCost = 800 * 10**6;
        s.grainCount = 1;
        s.pillarCount = 10;
        s.sheetCount = 100;
        s.cubeCount = 1000;
    


     

        // add your own state variables 
        // EIP-2535 specifies that the `diamondCut` function takes two optional 
        // arguments: address _init and bytes calldata _calldata
        // These arguments are used to execute an arbitrary function using delegatecall
        // in order to set state variables in the diamond during deployment or an upgrade
        // More info here: https://eips.ethereum.org/EIPS/eip-2535#diamond-interface 
    }


}

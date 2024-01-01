// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IDiamondCut.sol";


////////////////
//// Vaults ////
////////////////
struct Vault {
    string name;
    uint256 totalSalt;
    uint256 totalRewardPoints;
    uint256 withdrawableAmount;
    uint256 disperableProfitAmount;
    uint256 lifetimeRewardAmount; // total rewards over life of vault
    address walletAddress;
    mapping(uint256 => uint256) depositedSaltAmount; // NFT ID => salt grain count deposited into this vault
    mapping(uint256 => uint256) nftVaultCompoundingRate; // NFT ID -> Compounding Rate
    mapping(uint256 => uint256) nftRewardPoints; // NFT ID -> Reward Points   This gets deleted every rewarding session
    mapping(uint256 => uint256) continuousMonthsCompounding; //  Token ID => Number of continuous months 100% compounding
    mapping(uint256 => bool) bonusEligibleForVaultDeposit; // Token ID => Bonus Eligibility Flag
}


struct RarityProperties {
    uint256 rarity;
    uint256 mintCost;
    uint256 rewardMultiplier; // Multiplier scaled by 100 to avoid decimals
    uint256 currentIndex;
    uint256 lastIndex;
}

///////////////////
//// Bull Info ////
///////////////////
struct Bull {
    uint256 rarity;
    uint256 grains;
    uint256 pillars;
    uint256 sheets;
    uint256 cubes;
    uint256 bonusGrains;
    uint256 totalSaltContributions; // Total salt contributions across all vaults
}

struct StartupBonus {
    uint256 bonusCapStage1;
    uint256 bonusCapStage2;
    uint256 bonusCapStage3;
    uint256 bonusCapStage4;
    uint256 bonusCapStage5;
    uint256 stage1Bonus;
    uint256 stage2Bonus;
    uint256 stage3Bonus;
    uint256 stage4Bonus;
    uint256 stage5Bonus;
}

struct AppStorage {

    // ====== wallets ===== //
    // address gapSlot;
    address usdcTokenContract;
    address saltVaultTokenContract;
    address coreTeamWallet;
    address royaltiesWallet;
    address procurementWallet;
    // ==================== //

    // ==================== //
    Vault[] vaults;
    mapping(uint256 => bool) allowedCompoundingRates;
    mapping(address => uint256) rewardBalancesForNFTOwners;
    string baseURI;
    string baseExtension;
    uint256 coreTeamBalance;
    uint256 vaultHoldingBalance;
    uint256 totalRewardBalance;
    uint256 vaultCouncilBalance;
    uint256 allPayoutAmount;
    bool mintLive;
    bool paperMintLive;
    bool paused;
    mapping(address => bool) ecosystemApprovedCaller;
    mapping(uint256 => RarityProperties) rarityProperties;
    mapping(uint256 => Bull) bulls;
    uint256[] mintedBullIndices;
    uint256 vaultCouncilCount;
    uint256[] vaultCouncil;
    mapping(uint256 => bool) indexInVaultCouncil;
    uint256 aum;
    uint256 grainCost;
    uint256 grainCount;
    uint256 pillarCost;
    uint256 pillarCount;
    uint256 sheetCost;
    uint256 sheetCount;
    uint256 cubeCost;
    uint256 cubeCount;
    StartupBonus bonusDetails;
    address Owner;
    bool dataInitializedToStart;
    // ======== ERC721 NFT information ===========

    // Token name Salt Vault Bulls
    string name;
    // Token symbol SVB
    string symbol;
    // Mapping from token ID to owner address
    mapping(uint256 => address) owners;
    // Mapping owner address to token count
    mapping(address => uint256) balances;
    // Mapping from token ID to approved address
    mapping(uint256 => address) tokenApprovals;
    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) operatorApprovals;
    //

    // ======== ERC721 Enumeration extentsion ===========

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) ownedTokens;
    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) ownedTokensIndex;
    // Array with all token ids, used for enumeration
    uint256[] allTokens;
    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) allTokensIndex;
    //=================================================================
    //


}

contract Modifiers {
    AppStorage internal s;


     modifier onlyProcurementWallet() {
        require(s.procurementWallet == msg.sender, "Caller is not the owner");
        _;
    }
}

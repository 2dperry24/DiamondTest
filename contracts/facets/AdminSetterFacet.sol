// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import {IERC721} from "../interfaces/IERC721.sol";
import {AppStorage} from "../AppStorage.sol";
import "../libraries/LibDiamond.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibSafeERC20} from "../libraries/LibSafeERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";


contract AdminSetterFacet {

    AppStorage internal s;


    event SetMintStatus(bool mintState, address indexed setter);

    function setMintStatus(bool status) external {
        LibDiamond.enforceIsContractOwner();

        if (s.usdcTokenContract == address(0) || s.saltVaultTokenContract == address(0) || s.coreTeamWallet == address(0) || s.royaltiesWallet == address(0) || s.procurementWallet == address(0)) {
            revert("Addresses must be set first");
        }


        s.mintLive = status;
        
        emit SetMintStatus(status, msg.sender);
    }

    function setAddresses(address _usdcTokenContract, address _saltVaultTokenContract, address _coreTeamWallet, address _royaltiesWallet, address _procurementWallet ) external  {

        LibDiamond.enforceIsContractOwner();

        s.usdcTokenContract = _usdcTokenContract;
        s.saltVaultTokenContract = _saltVaultTokenContract;
        s.coreTeamWallet = _coreTeamWallet;
        s.royaltiesWallet = _royaltiesWallet;
        s.procurementWallet = _procurementWallet;
   
    }

}

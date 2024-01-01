// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Import all of AppStorage to give importers of LibAppStorage access to {Account}, etc.
import "../AppStorage.sol";

/**
 * @title LibAppStorage
 * @author Pepper
 * @notice Allows libaries to access SVB state.
 */
library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }



    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x >= 0 ? x : -x);
    }
}

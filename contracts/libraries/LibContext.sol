// SPDX-License-Identifier: MIT
// Converted from OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol) to a library

pragma solidity ^0.8.0;

/**
 * @dev Library providing information about the current execution context,
 * including the sender of the transaction and its data. While these are generally
 * available via msg.sender and msg.data, they should not be accessed in such a
 * direct manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application is concerned).
 */
library LibContext {
    function msgSender() internal view returns (address) {
        return msg.sender;
    }

    function msgData() internal pure returns (bytes calldata) {
        return msg.data;
    }
}

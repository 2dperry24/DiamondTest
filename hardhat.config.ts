import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "hardhat-contract-sizer"

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.8.13",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        hardhat: {
            accounts: {
                count: 50, // Number of accounts
            },
        },
        // Other network configurations...
    },
    // Additional configurations...
}

export default config

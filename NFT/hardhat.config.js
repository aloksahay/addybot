require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    mantle: {
      url: "https://rpc.mantle.xyz",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 5000
    },
    mantleTest: {
      url: "https://rpc.testnet.mantle.xyz",
      accounts: [process.env.PRIVATE_KEY], 
      chainId: 5001
    },
    mantleSepolia: {
      url: "https://rpc.sepolia.mantle.xyz",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 5003,
      verify: {
        etherscan: {
          apiUrl: "https://explorer.sepolia.mantle.xyz"
        }
      }
    }
  },
  etherscan: {
    apiKey: {
      mantleSepolia: "PLACEHOLDER" // Mantle doesn't need a real API key
    },
    customChains: [
      {
        network: "mantleSepolia",
        chainId: 5003,
        urls: {
          apiURL: "https://explorer.sepolia.mantle.xyz/api",
          browserURL: "https://explorer.sepolia.mantle.xyz"
        }
      }
    ]
  }
}; 
import { HardhatUserConfig } from "hardhat/config";
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");
require("dotenv").config();
import "@nomicfoundation/hardhat-verify";

const INFURA_API_KEY = process.env.INFURA_API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      evmVersion: "london",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    mode_testnet: {
      url: "https://sepolia.mode.network",
      chainId: 919,
      accounts: [process.env.PRIVATE_KEY as string], //BE VERY CAREFUL, DO NOT PUSH THIS TO GITHUB
    },
    mode_mainnet: {
      url: "https://mainnet.mode.network",
      chainId: 34443,
      accounts: [process.env.WALLET_PRIVATE_KEY as string], //BE VERY CAREFUL, DO NOT PUSH THIS TO GITHUB
      gas: 9300000,
    },
    arbitrumSepolia: {
      url: "https://sepolia-rollup.arbitrum.io/rpc",
      chainId: 421614,
      accounts: [process.env.TESTNET_WALLET_PRIVATE_KEY as string],
      gas: 9000000,
      gasPrice: 300000000,
    },
    ethereum_mainnet: {
      chainId: 1,
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
    },
    linea_mainnet: {
      chainId: 59144,
      url: `https://linea-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
    },
    arbitrumOne: {
      chainId: 42161,
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
      gasPrice: 300000000,
      gas: 9300000,
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      chainId: 97,
      gasPrice: 1000000000,
      accounts: [process.env.PRIVATE_KEY as string],
    },
    bsc_mainnet: {
      chainId: 56,
      url: "https://bsc-dataseed.bnbchain.org/",
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
      gasPrice: 3200000000,
      gas: 6000000,
    },
    polygon: {
      chainId: 137,
      url: "https://polygon-rpc.com/",
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
      gas: 6000000,
    },
    avalanche: {
      chainId: 43114,
      url: "https://api.avax.network/ext/bc/C/rpc",
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
      gasPrice: 30000000000,
    },

    sepolia: {
      chainId: 11155111,
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
    },
    // for mainnet
    base_mainnet: {
      chainId: 8453,
      url: "https://mainnet.base.org",
      accounts: [process.env.WALLET_PRIVATE_KEY as string],
      gasPrice: 100000000,
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      bsc: process.env.BSCSCAN_API_KEY,
      arbitrumSepolia: process.env.ARBISCAN_API_KEY,
      linea_mainnet: process.env.LINEASCAN_API_KEY,
      snowtrace: "snowtrace",
      polygon: process.env.POLYGONSCAN_API_KEY,
      mode_mainnet: "abc88",
      mode_main: "modescan",
    },
    customChains: [
      {
        network: "linea_mainnet",
        chainId: 59144,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://lineascan.build",
        },
      },
      {
        network: "snowtrace",
        chainId: 43114,
        urls: {
          apiURL:
            "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan",
          browserURL: "https://snowtrace.io",
        },
      },
      {
        network: "mode_mainnet",
        chainId: 34443,
        urls: {
          apiURL: "https://explorer.mode.network/api",
          browserURL: "https://explorer.mode.network/",
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  namedAccounts: {
    deployer: {
      default: 0,
    },
    operator: {
      default: 1,
    },
  },
};

export default config;

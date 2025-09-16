import { http, createConfig } from 'wagmi'
import { localhost, hardhat } from 'wagmi/chains'
import { getDefaultConfig } from '@rainbow-me/rainbowkit'

// 定义本地开发链
const localhostChain = {
  ...localhost,
  id: 31337,
  name: 'Localhost',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
    },
  },
}

export const config = getDefaultConfig({
  appName: 'DeSci Platform',
  projectId: process.env.REACT_APP_WALLETCONNECT_PROJECT_ID || '2f5a2fd16e1b4cb387a4c8b3e9f7d6e1', // 使用环境变量或默认开发ID
  chains: [localhostChain],
  transports: {
    [localhostChain.id]: http(),
  },
})
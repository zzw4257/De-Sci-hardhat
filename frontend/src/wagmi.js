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
  projectId: 'your-project-id', // 从 WalletConnect Cloud 获取
  chains: [localhostChain],
  transports: {
    [localhostChain.id]: http(),
  },
})
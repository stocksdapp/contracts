const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();

module.exports = {
  networks: {
    ropsten: {
      provider: function() {
        return new HDWalletProvider(`${process.env.MNEMONIC}`, `https://ropsten.infura.io/v3/${process.env.INFURA_ID}`)
      },
      // confirmations: 2,
      network_id: 3,
      skipDryRun: true
    },
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*"
    }
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  verify: {
    preamble: 'Testnet contracts preamble'
  },
  api_keys: {
    etherscan: process.env.ETHERSCAN_API_KEY
  },
  compilers: {
    solc: {
      version: '0.6.10'
    }
  }
};

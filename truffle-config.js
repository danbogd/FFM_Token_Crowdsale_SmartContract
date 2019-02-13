/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a 
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() { 
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>') 
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */

const HDWalletProvider = require("truffle-hdwallet-provider")
const mnemonic = "your safe words"
const provider = function () {
  return new HDWalletProvider(mnemonic, "https://ropsten.infura.io/v3/...")
}
const PrivateKeyProvider = require("truffle-privatekey-provider");
const privateKey = '';

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    test: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 5000000
    },
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*",
      gas: 5000000
    },
    ropsten: {
      provider: new PrivateKeyProvider(privateKey, "https://ropsten.infura.io/..."),
      network_id: 3,
      gas: 4500000,
      gasPrice: 20000000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};

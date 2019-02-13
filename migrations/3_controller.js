const FilesFMToken = artifacts.require("FilesFMToken");
const FilesFMTokenController = artifacts.require("FilesFMTokenController");

module.exports = function (deployer, network, accounts) {
    if (network === 'ropsten') {
        deployer.deploy(FilesFMTokenController, FilesFMToken.address)
            .then(() => FilesFMToken.deployed())
            .then(token => token.transferOwnership(FilesFMTokenController.address))
            .then(() => FilesFMTokenController.deployed())
            .then(controller => controller.initialize());
    }
}
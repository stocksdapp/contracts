const S = artifacts.require("S");
const STO = artifacts.require("STO");

module.exports = function(deployer) {
  //small initial supply of 1k
  deployer.deploy(STO, "1000000000000000000000", []).then(function() {
    return deployer.deploy(S);
  });
};

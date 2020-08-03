const S = artifacts.require("S");
const SToken = artifacts.require("SToken");

module.exports = function(deployer) {
  deployer.deploy(SToken, "100000000000000000000000000").then(function() {
    return deployer.deploy(S);
  });
};

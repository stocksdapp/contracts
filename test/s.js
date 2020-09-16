const constants = require('./consts.js');
const utils = require('./utils.js');

const SToken = artifacts.require("SToken");
const S = artifacts.require("S");
const DAItokenAddress = "0xc2118d4d90b274016cB7a54c03EF52E6c537D957";
const LINKtokenAddress = "0x20fe562d797a42dcb3399062ae9546cd06f63280";
let exchangeAddress;
const oracleAddress = "0xd3d4f566b8e0de2dcde877b1954c2d759cc395a6";
const tickerJobId = web3.utils.fromAscii("51df1946d454408b90f15530d35c134a");

contract('SToken', (accounts) => {
  it('Setup: set exchange in token, token in exchange, oracle', async () => {
    //boilerplate
    const STokenInstance = await SToken.deployed();
    const SInstance = await S.deployed();
    const balance = await STokenInstance.balanceOf.call(accounts[0]);
    const tokenAddress = STokenInstance.address.toString();
    exchangeAddress = SInstance.address.toString();
    await SInstance.setSToken(tokenAddress, { from: accounts[0] });
    const stokenInS = await SInstance.SToken.call();
    await SInstance.setDAIToken(DAItokenAddress, { from: accounts[0] });
    await STokenInstance.setExchange(exchangeAddress, { from: accounts[0] });
    await SInstance.setOracle(oracleAddress, true, { from: accounts[0] });
    const DAI_token = await SInstance.DAI_token.call();
    //log
    console.log("exchange address is", exchangeAddress);
    console.log("token address is", tokenAddress);
    //checks
    assert.equal(stokenInS.valueOf().toString(), tokenAddress, "failed to set token address");
    assert.equal(DAI_token.valueOf().toString(), DAItokenAddress, "failed to set DAI address");
    assert.equal(balance.toString(),
      web3.utils.toWei("100", 'mether'),
      "unexpected value in the first account");
  });
  it('Approvals', async () => {
    const DAIContract = new web3.eth.Contract(constants.DAIABI, DAItokenAddress);
    await DAIContract.methods.approve(exchangeAddress, web3.utils.toWei("99999999999", 'tether')).send({ from: accounts[0] });
    await DAIContract.methods.approve(exchangeAddress, web3.utils.toWei("99999999999", 'tether')).send({ from: accounts[1] });
  });
  it('Send some LINK to cover price of all requests', async () => {
    //boilerplate
    const LINKContract = new web3.eth.Contract(constants.LINKABI, LINKtokenAddress);
    await LINKContract.methods.transfer(exchangeAddress, web3.utils.toWei("10", 'ether')).send({ from: accounts[0] });
    const balance = await LINKContract.methods.balanceOf(exchangeAddress).call({ from: accounts[0] });
    //checks
    assert.equal(balance.toString(),
      web3.utils.toWei("10", 'ether'),
      "sending link to exchange failed");
  });
  it('Set up a new dsellerage offer for TSLA', async () => {
    //boilerplate
    const SInstance = await S.deployed();

    async function newOffer(price, collateral, ticker, sCollateral, cut, afkHours, ms) {
      await SInstance.createDsellerOffer(price, collateral, ticker, web3.utils.fromAscii(ticker),
        web3.utils.toWei(sCollateral, 'ether'),
        cut, utils.getAfkHours(afkHours), ms, { from: accounts[0] });
    }
    //same thing from remix
    //2000, 50, "TSLA", "0x54534c41", 50000000000000000000, 105, [], 0
    await newOffer(2000, 50, "TSLA", "50", 105, [], 0);
    //more trades that won't be accepted
    await newOffer(3000, 100, "MSFT", "20", 110, [], 0,);
    await newOffer(3000, 200, "GOOG", "20", 111, [1, 2], 0);
    await newOffer(3000, 200, "TSLA", "20", 111, [], 0);
    await newOffer(5000, 200, "CSCO", "20", 111, [], 0);
    await newOffer(5000, 200, "AVEO", "25", 111, [], 0);
    await newOffer(5000, 200, "AXAS", "20", 111, [], 0);
    const resTrade = await SInstance.trades.call(0);
    assert.equal(resTrade.seller, accounts[0], "failed to create the offer");
  });
  it('Send some Stokens to cover request price', async () => {
    //boilerplate
    const STokenInstance = await SToken.deployed();
    await STokenInstance.transfer(accounts[1], web3.utils.toWei("1000", 'ether'), { from: accounts[0] });
    const balance = await STokenInstance.balanceOf.call(accounts[1]);
    //checks
    assert.equal(balance.toString(),
      web3.utils.toWei("1000", 'ether'),
      "pay-for-request transfer failed");
  });
  it('Accept dseller offer', async function() {
    //boilerplate
    const SInstance = await S.deployed();
    await SInstance.
      acceptDsellerOffer(0, 100, web3.utils.toWei("50", 'ether'), 105,
        oracleAddress, tickerJobId, web3.utils.toWei("1", 'ether'),
        { from: accounts[1] });
    setTimeout(async () => {
      const resTrade = await SInstance.trades.call(0);
      const tradeIsActive = await SInstance.getTradeIsActive.call(0);
      //logs
      console.log("accepted trade state is", resTrade);
      //checks
      assert.equal(resTrade.buyer, accounts[1], "failed to create the offer");
      assert.equal(tradeIsActive, true, "failed to activate the trade");
    }, 120000)
  });
  //this should be optimized
});


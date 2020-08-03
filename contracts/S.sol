// SPDX-License-Identifier: UNLICENSED
// Absolutely Proprietary Code

pragma solidity 0.6.10;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.6/vendor/SafeMath.sol";
import "./DateTime.sol";


// import "https://github.com/smartcontractkit/chainlink/evm-contracts/src/v0.6/ChainlinkClient.sol";
// import "https://github.com/smartcontractkit/chainlink/evm-contracts/src/v0.6/vendor/SafeMath.sol";
// import "https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary/blob/master/contracts/BokkyPooBahsDateTimeLibrary.sol";

abstract contract ERC20Token {
    function transferFrom(address from, address to, uint value) public virtual;
    function transfer(address recipient, uint256 amount) public virtual;
    function balanceOf(address account) external view virtual returns (uint256);
    function stakedOf(address _user) public view virtual returns (uint256);
    function dividendsOf(address _user) public view virtual returns (uint256);
    function totalStaked() public view virtual returns (uint256);
    function totalUnlockedSupply() public view virtual returns (uint256);
    function transferFromEx(address from, address to, uint value) public virtual;
}



contract S is ChainlinkClient {
using BokkyPooBahsDateTimeLibrary for uint;

 struct TradeMeta {
    uint256 lastPrice;
    bytes32 linkRequestId;
    uint256 durationCap;
    uint256 acceptedAt;
 }

  struct Trade {
    string ticker;
    uint256 initPrice;
    address buyer;
    address seller;
    uint amountStock;
    uint256 fundsBuyer;
    bool isClosed;
    uint256 priceCreationReqTimeout;
  }

  // data
  mapping(address => uint256[]) public addressTrades;
  mapping(bytes32 => uint256) public linkRequestIdToTrade;
  Trade[] public trades;
  TradeMeta[] public tradesMeta;

  // struct array workaround - trade showcase - public tradeInfo
  bytes32[] trades_ticker;
  uint256[] trades_dsellerPercentage;
  uint256[] trades_maxAmountStock;
  uint256[] trades_minAmountStock;
  bool[] trades_isActive;
  bool[] trades_isCancelled;
  uint256[] trades_fundsSeller;
  uint8[17][] afkHours;


  uint256 public oraclePaymentDefault;
  uint256 public linkToS;
  address public owner;
  address public DAI_token;
  address public SToken;
  uint256 public divPool;
  mapping(address => bool) public oracles;


  // events
  event TradeClosed(uint256 tradeID, uint256 price);
  event TradeConfirmed(uint256 tradeID, uint256 price);
  event RequestTradeClosed(uint256 tradeID);
  event OfferCreated(string ticker, uint256 maxAmountStock, uint256 minAmountStock,
                     uint256 dsellerOfferPrice, address dseller);
  event OfferAccepted(uint256 tradeID);
  event OfferCancelled(uint256 tradeID);
  event DaiDivsClaimed(address claimer);


  constructor() public {
    owner = msg.sender;
    setPublicChainlinkToken();
    //switch it for mainnet
    oraclePaymentDefault = LINK;
    linkToS = 0;
  }

  // functions (administration)
  function setPayment(uint256 _linkAmount, uint256 _linkToS) public
  {
    require(msg.sender == owner);
    oraclePaymentDefault = _linkAmount;
    linkToS = _linkToS;
  }

  function setDAIToken(address _token) public
  {
    //0xc2118d4d90b274016cB7a54c03EF52E6c537D957 for testnet
    require(msg.sender == owner);
    DAI_token = _token;
  }

 function setSToken(address _token) public
  {
    require(msg.sender == owner);
    SToken = _token;
  }

  function setOracle(address _oracle, bool _isCertified) public
  {
    //0xd3d4f566b8e0de2dcde877b1954c2d759cc395a6 for testnet
    require(msg.sender == owner);
    oracles[_oracle] = _isCertified;

  }

  // functions (UI)

  function createDsellerOffer(uint256 _maxAmountStock, uint256 _minAmountStock,
                             string memory _ticker, bytes32 _tickerBytes,
                             uint256 _fundsSeller, uint256 _dsellerPercentage,
                             uint8[17] memory _afkHours, uint256 _durationCap) public
  {
    trades.push(Trade(_ticker, 0, address(0x0), msg.sender, 0, 0, false, 0));
    tradesMeta.push(TradeMeta(0,0, _durationCap, 0));
    afkHours.push(_afkHours);
    trades_ticker.push(_tickerBytes);
    trades_maxAmountStock.push(_maxAmountStock);
    trades_minAmountStock.push(_minAmountStock);
    trades_dsellerPercentage.push(_dsellerPercentage);
    //
    trades_isActive.push(false);
    trades_isCancelled.push(false);
    //
    addressTrades[msg.sender].push(trades.length-1);
    //excess should be withdrawable
    ERC20Token DAI = ERC20Token(DAI_token);
    DAI.transferFrom(msg.sender, address(this), _fundsSeller);
    trades_fundsSeller.push(_fundsSeller);
    emit OfferCreated(_ticker, _maxAmountStock, _minAmountStock, _dsellerPercentage, msg.sender);
  }

  function cancelDsellerOffer(uint256 _tradeID) public
  {
    require(!trades_isActive[_tradeID], "Trade already active");
    require(!trades[_tradeID].isClosed, "Trade already closed");
    require(!trades_isCancelled[_tradeID], "Trade has been cancelled");
    require(trades[_tradeID].seller == msg.sender);
    require(trades[_tradeID].priceCreationReqTimeout == 0 || trades[_tradeID].priceCreationReqTimeout < block.timestamp);
    trades_isCancelled[_tradeID] = true;
    ERC20Token DAI = ERC20Token(DAI_token);
    DAI.transfer( msg.sender, trades_fundsSeller[_tradeID]);
    trades_fundsSeller[_tradeID] = 0;
    emit OfferCancelled(_tradeID);
  }

  function ceil(uint a, uint m) view private  returns (uint ) {
    return ((a + m - 1) / m) * m;
  }

  function acceptDsellerOffer(uint256 _tradeID, uint256 _amountStock, uint256 _fundsSeller,
                             uint256 dsellerPercentage,
                             address _oracle, bytes32 _jobId,
                             uint256 _oraclePayment) public
  {
    require(!trades_isActive[_tradeID], "Trade already active");
    require(!trades[_tradeID].isClosed, "Trade already closed");
    require(!trades_isCancelled[_tradeID], "Trade has been cancelled");
    require(trades[_tradeID].seller != msg.sender, "Same party");
    require(trades[_tradeID].priceCreationReqTimeout == 0 || trades[_tradeID].priceCreationReqTimeout < block.timestamp, "Trade has not expired");
    require(trades_fundsSeller[_tradeID] == _fundsSeller, "Funds moved");
    require(trades_dsellerPercentage[_tradeID] == dsellerPercentage, "Percentage changed");
    require(trades_minAmountStock[_tradeID] <= _amountStock, "Under min stock amount");
    require(trades_maxAmountStock[_tradeID] >= _amountStock, "Over max stock amount");
    //send price req
    require(oracles[_oracle], "Incorrect oracle address");
    uint8[17] memory _afkHours = afkHours[_tradeID];
    uint256 currentHour = BokkyPooBahsDateTimeLibrary.getHour(block.timestamp);
    for (uint i=0; i<_afkHours.length; i++) {
      if (_afkHours[i] == currentHour) {
        revert("Entering at AFK hour");
      }
    }
    uint256 payment;
    if (_oraclePayment > oraclePaymentDefault) {
      payment = oraclePaymentDefault;
    } else {
      payment = _oraclePayment;
    }
    if (linkToS != 0) {
      fundWithLinkOrS(payment);
    }
    Chainlink.Request memory req = buildChainlinkRequest(_jobId, address(this), this._acceptDsellerOffer.selector);
    req.add("ticker", trades[_tradeID].ticker);
    bytes32 reqId = sendChainlinkRequestTo(_oracle, req, payment);
    linkRequestIdToTrade[reqId] = _tradeID;
    //end sendpricereq
    trades[_tradeID].buyer = msg.sender;
    //set up 1 hour security timeout to prevent trade acceptance overwrite,
    //and refuse fulfillments that come after timeout deadline
    trades[_tradeID].priceCreationReqTimeout = block.timestamp.add(3600);
    //ceil to remove fractional trading
    trades[_tradeID].amountStock = ceil(_amountStock, 1000);
    addressTrades[msg.sender].push(_tradeID);
    emit OfferAccepted(_tradeID);
  }

function _acceptDsellerOffer(bytes32 _requestId, uint256 _price)
  public
  recordChainlinkFulfillment(_requestId)
{
  uint256 tradeID = linkRequestIdToTrade[_requestId];
  Trade memory trade = trades[tradeID];
  require(!trades_isActive[tradeID], "Trade already active");
  require(!trade.isClosed, "Trade already closed");
  require(!trades_isCancelled[tradeID], "Trade has been cancelled");
  require(trade.priceCreationReqTimeout > block.timestamp, "Request expired");
  //second div for fractional trading
  uint256 presentValueBuyer = trade.amountStock.mul(_price.mul(trades_dsellerPercentage[tradeID]).div(100).div(1000));
  trades[tradeID].fundsBuyer = presentValueBuyer;
  ERC20Token DAI = ERC20Token(DAI_token);
  DAI.transferFrom(trade.buyer, address(this), presentValueBuyer);
  trades_isActive[tradeID] = true;
  tradesMeta[tradeID].acceptedAt = block.timestamp;
  trades[tradeID].initPrice = _price;
  trades[tradeID].priceCreationReqTimeout = 0;
  emit TradeConfirmed(tradeID, _price);
}

function fundWithLinkOrS(uint256 linkPayment) public {
  ERC20Token ST = ERC20Token(SToken);
  uint256 sBalance = ST.balanceOf(msg.sender);
  uint256 sPayment = linkPayment.mul(linkToS).div(100);
  if (sBalance >= sPayment) {
    //S burned
    ST.transferFromEx(msg.sender, address(this), sPayment);
  } else {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transferFrom(msg.sender, address(this), linkPayment));
  }
}

function closeTrade(uint256 _tradeID, address _oracle, bytes32 _jobId,
                    uint256 _oraclePayment) public
{
  require(trades_isActive[_tradeID], "Trade is not active");
  require(!trades[_tradeID].isClosed, "Trade already closed");
  require(oracles[_oracle], "Incorrect oracle address");
  bool calledByBuyer = trades[_tradeID].buyer == msg.sender;
  bool calledBySeller = trades[_tradeID].seller == msg.sender;
  if (!calledByBuyer && !calledBySeller) {
    revert("Not a party");
  }
  if (calledBySeller &&
     (tradesMeta[_tradeID].acceptedAt.add(tradesMeta[_tradeID].durationCap) > block.timestamp ||
      tradesMeta[_tradeID].durationCap == 0)) {
    revert("Seller timelock pending");
  }
  uint8[17] memory _afkHours = afkHours[_tradeID];
  uint256 currentHour = BokkyPooBahsDateTimeLibrary.getHour(block.timestamp);
  for (uint i=0; i<_afkHours.length; i++) {
            if (_afkHours[i] == currentHour) {
               revert("Closing at AFK hour");
      }
  }
  uint256 payment;
  if (_oraclePayment > oraclePaymentDefault) {
    payment = oraclePaymentDefault;
  } else {
    payment = _oraclePayment;
  }
  if (linkToS != 0) {
    fundWithLinkOrS(payment);
  }
  trades[_tradeID].priceCreationReqTimeout = block.timestamp.add(3600);
  Chainlink.Request memory req = buildChainlinkRequest(_jobId, address(this), this._closeTrade.selector);
  req.add("ticker", trades[_tradeID].ticker);
  bytes32 reqId = sendChainlinkRequestTo(_oracle, req, payment);
  linkRequestIdToTrade[reqId] = _tradeID;
  emit RequestTradeClosed(_tradeID);
}


function _closeTrade(bytes32 _requestId, uint256 _price)
  public
  recordChainlinkFulfillment(_requestId)
{
  uint256 tradeID = linkRequestIdToTrade[_requestId];
  Trade memory trade = trades[tradeID];
  uint256 presentValue = trade.amountStock.mul(_price).div(1000);
  uint256 initValue = trade.amountStock.mul(trade.initPrice.mul(trades_dsellerPercentage[tradeID]).div(100)).div(1000);
  uint256 sendToBuyer;
  uint256 sendToSeller;
  if (presentValue > initValue) {
      uint256 buyerProfit = presentValue.sub(initValue);
      //imperative pattern
      //capping due to undercollateralization
      if (buyerProfit > trades_fundsSeller[tradeID]) {
        buyerProfit = trades_fundsSeller[tradeID];
      }
      uint256 buyerProfitShare = buyerProfit.mul(95).div(100);
      divPool = divPool.add(buyerProfit.mul(5).div(100));
      sendToBuyer = trade.fundsBuyer.add(buyerProfitShare);
      sendToSeller = trades_fundsSeller[tradeID].sub(buyerProfit);
  }
  if (presentValue <= initValue) {
      uint256 sellerProfit = initValue.sub(presentValue);
      sendToSeller = trades_fundsSeller[tradeID].add(sellerProfit);
      sendToBuyer = trade.fundsBuyer.sub(sellerProfit);
  }
  trades_fundsSeller[tradeID] = 0;
  trades[tradeID].fundsBuyer = 0;
  ERC20Token DAI = ERC20Token(DAI_token);
  if (sendToSeller > 0) {
         DAI.transfer(trade.seller, sendToSeller);
  }
  if (sendToBuyer > 0) {
         DAI.transfer(trade.buyer, sendToBuyer);
  }
  trades[tradeID].isClosed = true;
  tradesMeta[tradeID].lastPrice = _price;
  tradesMeta[tradeID].linkRequestId = _requestId;
  trades[tradeID].priceCreationReqTimeout = 0;
  emit TradeClosed(tradeID, _price);
}

  function daiDividends(address _forHolder) public view returns (uint256)
  {
      uint256 totalOpenPool = divPool;
      ERC20Token ST = ERC20Token(SToken);
      uint256 userSDividends = ST.dividendsOf(_forHolder);
      uint256 totalUnlocked = ST.totalUnlockedSupply();
      return totalOpenPool.mul(userSDividends).div(totalUnlocked);
  }

  function claimDaiDividends(address _forHolder, uint256 _dividends) public
  {
    require(msg.sender == SToken);
    ERC20Token DAI = ERC20Token(DAI_token);
    ERC20Token ST = ERC20Token(SToken);
    uint256 totalOpenPool = divPool;
    uint256 totalUnlocked = ST.totalUnlockedSupply();
    uint256 divsDue = totalOpenPool.mul(_dividends).div(totalUnlocked);
    divPool = divPool.sub(divsDue);
    DAI.transfer(_forHolder, divsDue);
    emit DaiDivsClaimed(msg.sender);
  }
   //direct access functions
   function getTradePublic(uint256 i) public view returns (bytes32, uint256, uint256, uint256, bool, bool, uint256 ){
     return(trades_ticker[i], trades_dsellerPercentage[i], trades_maxAmountStock[i],
            trades_minAmountStock[i], trades_isActive[i], trades_isCancelled[i], trades_fundsSeller[i] );
   }

    function tradesLength() public view returns( uint256 ){
        return trades.length;
    }

  function getAfkHoursForTrade(uint256 _tradeID) public view returns (uint8[17] memory )
  {
     return afkHours[_tradeID];
  }

    function getTradeTickers() public view returns( bytes32[] memory){
        return trades_ticker;
    }

    function getTradeDsellerPercentage() public view returns( uint256[] memory){
        return trades_dsellerPercentage;
    }

    function getTradeMaxAmountStock() public view returns( uint256[] memory){
        return trades_maxAmountStock;
    }

    function getTradeMinAmountStock() public view returns( uint256[] memory){
        return trades_minAmountStock;
    }

    function getTradeIsActive() public view returns( bool[] memory){
        return trades_isActive;
    }

    function getTradeIsCancelled() public view returns( bool[] memory){
        return trades_isCancelled;
    }

    function getTradeFundsSeller() public view returns( uint256[] memory){
        return trades_fundsSeller;
    }

    function getAddressTrades(address _of) public view returns( uint256[] memory){
        return addressTrades[_of];
    }
}

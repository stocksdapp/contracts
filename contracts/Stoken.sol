// SPDX-License-Identifier: UNLICENSED
// Absolutely Proprietary Code

pragma solidity ^0.6.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/56de324afea13c4649b00ca8c3a3e3535d532bd4/contracts/token/ERC20/ERC20.sol";

contract Stoken is ERC20 {
    //data
    address public sExchange;
    address public exchangeAdmin;
    struct Staker {
        uint256 staked;
        int256 stakeQuantShare;
    }
    struct Info {
        uint256 totalUnlockedSupply;
        uint256 lockUntil;
        uint256 totalStaked;
        mapping(address => Staker) stakers;
        uint256 stakeQuant;
        address admin;
    }
    uint256 constant private TX_DECIMALS = 2**64;
    uint256 constant private BURN_RATE = 11;
    Info private info;

    //events
    event Stake(address owner, uint256 tokens);
    event Unstake(address owner, uint256 tokens);
    event DividendsClaim(address owner, uint256 tokens);

    constructor(uint256 initialSupply) ERC20("STOCKSD", "STOCKSD") public {
        _mint(msg.sender, initialSupply);
        info.totalUnlockedSupply = initialSupply;
        exchangeAdmin = msg.sender;
    }

    function setExchange(address exchange) public
    {
        require(msg.sender == exchangeAdmin);
        sExchange = exchange;
    }

    function setAdmin(address _admin) public
    {
        require(msg.sender == exchangeAdmin);
        exchangeAdmin = _admin;
    }

    function setAdminLock(uint256 timestamp) public
    {
        require(msg.sender == exchangeAdmin);
        info.lockUntil = timestamp;
    }

    function increaseAdminLocked(uint256 _amount) public
    {
        require(msg.sender == exchangeAdmin);
        info.totalUnlockedSupply = info.totalUnlockedSupply.sub(_amount);
        _transfer(msg.sender, address(this), _amount);
    }

    function moveAdminUnlocked(uint256 _amount) public
    {
        require(msg.sender == exchangeAdmin);
        require(block.timestamp > info.lockUntil);
        require(_amount <= (totalSupply().sub(info.totalUnlockedSupply)));
        info.totalUnlockedSupply = info.totalUnlockedSupply.add(_amount);
        _transfer(address(this), msg.sender, _amount);
    }

    function stakedOf(address _user) public view returns (uint256) {
        return info.stakers[_user].staked;
    }

    function dividendsOf(address _user) public view returns (uint256) {
        return uint256(int256(info.stakeQuant * info.stakers[_user].staked) -
        info.stakers[_user].stakeQuantShare) / TX_DECIMALS;
    }

    function totalStaked() public view returns (uint256) {
        return info.totalStaked;
    }

    function totalUnlockedSupply() public view returns (uint256) {
        return info.totalUnlockedSupply;
    }

    function stake(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount);
        require(stakedOf(msg.sender).add(_amount) >= 1);
        info.totalStaked = info.totalStaked.add(_amount);
        _transfer(msg.sender, address(this), _amount);
        info.stakers[msg.sender].staked = info.stakers[msg.sender].staked.add(_amount);
        info.stakers[msg.sender].stakeQuantShare += int256(_amount * info.stakeQuant);
        emit Stake(msg.sender, _amount);
    }


    function unstake(uint256 _amount) public {
        require(stakedOf(msg.sender) >= _amount);
        uint256 _burnedAmount = _amount.mul(BURN_RATE).div(100);
        uint256 tmpPerToken = _burnedAmount.mul(TX_DECIMALS).div(info.totalStaked);
        info.totalStaked = info.totalStaked.sub(_amount, "sub1");
        info.stakeQuant = info.stakeQuant.add(tmpPerToken);
        _transfer(address(this), msg.sender, _amount.sub(_burnedAmount));
        info.stakers[msg.sender].staked = info.stakers[msg.sender].staked.sub(_amount, "sub3");
        info.stakers[msg.sender].stakeQuantShare -= int256(_amount * info.stakeQuant);
        emit Unstake(msg.sender, _amount);
    }

    function dividendsClaim() external returns (uint256) {
        uint256 _dividends = dividendsOf(msg.sender);
        require(_dividends >= 0);
        info.stakers[msg.sender].stakeQuantShare += int256(_dividends * TX_DECIMALS);
        _transfer(address(this), msg.sender, _dividends);
        SExchange exchangeI = SExchange(sExchange);
        exchangeI.claimDaiDividends(msg.sender, _dividends);
        emit DividendsClaim(msg.sender, _dividends);
        return _dividends;
    }

    function transferFromEx(address _from, address _to, uint256 _amount) public
    {
        require(msg.sender == sExchange);
        _transfer(_from, _to, _amount);
    }
}

abstract contract SExchange {
    function claimDaiDividends(address _forHolder, uint256 _dividends) public virtual;
}

pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FilesFMToken.sol";
import "./TokenRecoverable.sol";
import "./ERC777TokenScheduledTimelock.sol";


contract FilesFMTokenController is ERC777TokenScheduledTimelock, TokenRecoverable {
    using SafeMath for uint256;

    struct MintScheduleItem {
        uint256 amount;
        uint256 till;
    }

    address public tokenMinter;
    MintScheduleItem[] public mintingSchedule;
    uint256 public currentItem = 0;
    address public tokenTransferOwnershipMaster = "";
    bool public tokenTransferOwnershipEnabled = false;

    event TokenTransferOwnershipEnabled();

    modifier canMint() {
        require(mintingSchedule.length > 0, "Contract not initialized");
        require(msg.sender == owner || msg.sender == tokenMinter, "Only owner or token minter can mint tokens");
        _;
    }

    constructor(address _token) public ERC777TokenScheduledTimelock(_token) {}

     function initialize() public {
        require(mintingSchedule.length == 0);
        require(FilesFMToken(token).owner() == address(this));

        uint256 firstYearAmount = uint256(1703000000e18).sub(FilesFMToken(token).totalSupply());
        mintingSchedule.push(MintScheduleItem({ amount: firstYearAmount, till: 1577836800 })); // 01-01-2020
        mintingSchedule.push(MintScheduleItem({ amount: 1572000000e18, till: 1609459200 })); // 01-01-2021
        mintingSchedule.push(MintScheduleItem({ amount: 2148400000e18, till: 1640995200 })); // 01-01-2022
        mintingSchedule.push(MintScheduleItem({ amount: 2148400000e18, till: 1672531200 })); // 01-01-2023
        mintingSchedule.push(MintScheduleItem({ amount: 2428200000e18, till: 1704067200 })); // 01-01-2024
        mintingSchedule.push(MintScheduleItem({ amount: 0, till: ~uint256(0) }));
    }

    function setTokenMinter(address _tokenMinter) public onlyOwner {
        tokenMinter = _tokenMinter;
    }

    function renounceOwnership() public onlyOwner {
        tokenMinter = address(0);
        super.renounceOwnership();
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        tokenMinter = address(0);
        super.transferOwnership(_newOwner);
    }

    function proxyRecoverTokens(ERC20Basic _token, address _to, uint256 _amount) public onlyOwner {
        FilesFMToken(token).recoverTokens(_token, _to, _amount);
    }

    function transferTokenOwnership(address _newOwner) public onlyOwner {
        require(tokenTransferOwnershipEnabled == true, "Token Ownership Transfer is locked");
        FilesFMToken(token).transferOwnership(_newOwner);
    }

    function enableTokenTransferOwnership() public {
        require(msg.sender == tokenTransferOwnershipMaster, "Not a Token Ownership Transfer Master");
        tokenTransferOwnershipEnabled = true;
        emit TokenTransferOwnershipEnabled();
    }

    /** PROXYING METHODS FOR TOKEN */
    function disableERC20() public onlyOwner {
        FilesFMToken(token).disableERC20();
    }

    function enableERC20() public onlyOwner {
        FilesFMToken(token).enableERC20();
    }

    function mint(address _tokenHolder, uint256 _amount, bytes _operatorData) public canMint {
        ensureCurrentSchedule();
        require(mintingSchedule[currentItem].amount >= _amount, "Not enough tokens");
        mintingSchedule[currentItem].amount = mintingSchedule[currentItem].amount.sub(_amount);
        FilesFMToken(token).mint(_tokenHolder, _amount, _operatorData);
    }

    function mintToken(address _tokenHolder, uint256 _amount) public canMint {
        ensureCurrentSchedule();
        require(mintingSchedule[currentItem].amount >= _amount, "Not enough tokens");
        mintingSchedule[currentItem].amount = mintingSchedule[currentItem].amount.sub(_amount);
        FilesFMToken(token).mintToken(_tokenHolder, _amount);
    }

    function mintTokens(address[] _tokenHolders, uint256[] _amounts) public canMint {
        ensureCurrentSchedule();
        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            total = total.add(_amounts[i]);
        }
        require(mintingSchedule[currentItem].amount >= total, "Not enough tokens");
        mintingSchedule[currentItem].amount = mintingSchedule[currentItem].amount.sub(total);
        FilesFMToken(token).mintTokens(_tokenHolders, _amounts);
    }

    function mintTimelockedTokens(address[] _tokenHolders, uint256[] _amounts, uint256 _lockUntil) public canMint {
        require(_tokenHolders.length > 0 && _tokenHolders.length <= 100);
        require(_tokenHolders.length == _amounts.length);
        ensureCurrentSchedule();
        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            total = total.add(_amounts[i]);
        }
        require(mintingSchedule[currentItem].amount >= total, "Not enough tokens");
        mintingSchedule[currentItem].amount = mintingSchedule[currentItem].amount.sub(total);
        for (uint256 j = 0; j < _amounts.length; j++) {
            FilesFMToken(token).mint(address(this), _amounts[j], '');
            scheduleTimelock(_tokenHolders[j], _amounts[j], _lockUntil);
        }
    }

    function permitTransfers() public onlyOwner {
        FilesFMToken(token).permitTransfers();
    }

    function setThrowOnIncompatibleContract(bool _throwOnIncompatibleContract) public onlyOwner {
        FilesFMToken(token).setThrowOnIncompatibleContract(_throwOnIncompatibleContract);
    }

    function permitBurning(bool _enable) public onlyOwner {
        FilesFMToken(token).permitBurning(_enable);
    }

    function completeDefaultOperators() public onlyOwner {
        FilesFMToken(token).completeDefaultOperators();
    }

    function setTokenBag(address _tokenBag) public onlyOwner {
        FilesFMToken(token).setTokenBag(_tokenBag);
    }

    function addDefaultOperator(address _operator) public onlyOwner {
        FilesFMToken(token).addDefaultOperator(_operator);
    }

    function removeDefaultOperator(address _operator) public onlyOwner {
        FilesFMToken(token).removeDefaultOperator(_operator);
    }

    function ensureCurrentSchedule() internal {
        MintScheduleItem storage item = mintingSchedule[currentItem];
        while (item.till < now) {
            MintScheduleItem storage lastItem = mintingSchedule[mintingSchedule.length - 1]; 
            lastItem.amount = lastItem.amount.add(item.amount); // move all unsold tokens to last stage
            item.amount = 0;
            currentItem = currentItem.add(1);
            item = mintingSchedule[currentItem];
        }
    }
}
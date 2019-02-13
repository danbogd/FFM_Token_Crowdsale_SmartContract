pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./erc777/contracts/ERC777ERC20BaseToken.sol";
import "./erc777/contracts/ERC777TokensRecipient.sol";
import "./TokenRecoverable.sol";
import "./ECRecovery.sol";


contract FilesFMToken is TokenRecoverable, ERC777ERC20BaseToken {
    using SafeMath for uint256;
    using ECRecovery for bytes32;

    string private constant name_ = "Files.fm Token";
    string private constant symbol_ = "FFM";
    uint256 private constant granularity_ = 1;
    
    mapping(bytes => bool) private signatures;
    address public tokenMinter;
    address public tokenBag;
    bool public throwOnIncompatibleContract = true;
    bool public burnEnabled = false;
    bool public transfersEnabled = false;
    bool public defaultOperatorsComplete = false;

    event TokenBagChanged(address indexed oldAddress, address indexed newAddress, uint256 balance);
    event DefaultOperatorAdded(address indexed operator);
    event DefaultOperatorRemoved(address indexed operator);
    event DefaultOperatorsCompleted();

    /// @notice Constructor to create a token
    constructor() public ERC777ERC20BaseToken(name_, symbol_, granularity_, new address[](0)) {
    }

    modifier canTransfer(address from, address to) {
        require(transfersEnabled || from == tokenBag || to == tokenBag);
        _;
    }

    modifier canBurn() {
        require(burnEnabled);
        _;
    }

    modifier hasMintPermission() {
        require(msg.sender == owner || msg.sender == tokenMinter, "Only owner or token minter can mint tokens");
        _;
    }

    modifier canManageDefaultOperator() {
        require(!defaultOperatorsComplete, "Default operator list is not editable");
        _;
    }

    /// @notice Disables the ERC20 interface. This function can only be called
    ///  by the owner.
    function disableERC20() public onlyOwner {
        mErc20compatible = false;
        setInterfaceImplementation("ERC20Token", 0x0);
    }

    /// @notice Re enables the ERC20 interface. This function can only be called
    ///  by the owner.
    function enableERC20() public onlyOwner {
        mErc20compatible = true;
        setInterfaceImplementation("ERC20Token", this);
    }

    function send(address _to, uint256 _amount, bytes _userData) public canTransfer(msg.sender, _to) {
        super.send(_to, _amount, _userData);
    }

    function operatorSend(
        address _from, 
        address _to, 
        uint256 _amount, 
        bytes _userData, 
        bytes _operatorData) public canTransfer(_from, _to) {
        super.operatorSend(_from, _to, _amount, _userData, _operatorData);
    }

    function transfer(address _to, uint256 _amount) public erc20 canTransfer(msg.sender, _to) returns (bool success) {
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public erc20 canTransfer(_from, _to) returns (bool success) {
        return super.transferFrom(_from, _to, _amount);
    }

    /* -- Mint And Burn Functions (not part of the ERC777 standard, only the Events/tokensReceived call are) -- */
    //
    /// @notice Generates `_amount` tokens to be assigned to `_tokenHolder`
    ///  Sample mint function to showcase the use of the `Minted` event and the logic to notify the recipient.
    /// @param _tokenHolder The address that will be assigned the new tokens
    /// @param _amount The quantity of tokens generated
    /// @param _operatorData Data that will be passed to the recipient as a first transfer
    function mint(address _tokenHolder, uint256 _amount, bytes _operatorData) public hasMintPermission {
        doMint(_tokenHolder, _amount, _operatorData);
    }

    function mintToken(address _tokenHolder, uint256 _amount) public hasMintPermission {
        doMint(_tokenHolder, _amount, "");
    }

    function mintTokens(address[] _tokenHolders, uint256[] _amounts) public hasMintPermission {
        require(_tokenHolders.length > 0 && _tokenHolders.length <= 100);
        require(_tokenHolders.length == _amounts.length);

        for (uint256 i = 0; i < _tokenHolders.length; i++) {
            doMint(_tokenHolders[i], _amounts[i], "");
        }
    }

    /// @notice Burns `_amount` tokens from `_tokenHolder`
    ///  Sample burn function to showcase the use of the `Burned` event.
    /// @param _amount The quantity of tokens to burn
    function burn(uint256 _amount, bytes _holderData) public canBurn {
        super.burn(_amount, _holderData);
    }

    function permitTransfers() public onlyOwner {
        require(!transfersEnabled);
        transfersEnabled = true;
    }

    function setThrowOnIncompatibleContract(bool _throwOnIncompatibleContract) public onlyOwner {
        throwOnIncompatibleContract = _throwOnIncompatibleContract;
    }

    function permitBurning(bool _enable) public onlyOwner {
        burnEnabled = _enable;
    }

    function completeDefaultOperators() public onlyOwner canManageDefaultOperator {
        defaultOperatorsComplete = true;
        emit DefaultOperatorsCompleted();
    }

    function setTokenMinter(address _tokenMinter) public onlyOwner {
        tokenMinter = _tokenMinter;
    }

    function setTokenBag(address _tokenBag) public onlyOwner {
        uint256 balance = mBalances[tokenBag];
        
        if (_tokenBag == address(0)) {
            require(balance == 0, "Token Bag balance must be 0");
        } else if (balance > 0) {
            doSend(msg.sender, tokenBag, _tokenBag, balance, "", "", false);
        }

        emit TokenBagChanged(tokenBag, _tokenBag, balance);
        tokenBag = _tokenBag;
    }
    
    function renounceOwnership() public onlyOwner {
        tokenMinter = address(0);
        super.renounceOwnership();
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        tokenMinter = address(0);
        super.transferOwnership(_newOwner);
    }

    /// @notice sends tokens using signature to recover token sender
    /// @param _to the address of the recepient
    /// @param _amount tokens to send
    /// @param _fee amound of tokens which goes to msg.sender
    /// @param _data arbitrary user data
    /// @param _nonce value to protect from replay attacks
    /// @param _sig concatenated r,s,v values
    /// @return `true` if the token transfer is success, otherwise should fail
    function sendWithSignature(address _to, uint256 _amount, uint256 _fee, bytes _data, uint256 _nonce, bytes _sig) public returns (bool) {
        doSendWithSignature(_to, _amount, _fee, _data, _nonce, _sig, true);
        return true;
    }

    /// @notice transfers tokens in ERC20 compatible way using signature to recover token sender
    /// @param _to the address of the recepient
    /// @param _amount tokens to transfer
    /// @param _fee amound of tokens which goes to msg.sender
    /// @param _data arbitrary user data
    /// @param _nonce value to protect from replay attacks
    /// @param _sig concatenated r,s,v values
    /// @return `true` if the token transfer is success, otherwise should fail
    function transferWithSignature(address _to, uint256 _amount, uint256 _fee, bytes _data, uint256 _nonce, bytes _sig) public returns (bool) {
        doSendWithSignature(_to, _amount, _fee, _data, _nonce, _sig, false);
        return true;
    }

    function addDefaultOperator(address _operator) public onlyOwner canManageDefaultOperator {
        require(_operator != address(0), "Default operator cannot be set to address 0x0");
        require(mIsDefaultOperator[_operator] == false, "This is already default operator");
        mDefaultOperators.push(_operator);
        mIsDefaultOperator[_operator] = true;
        emit DefaultOperatorAdded(_operator);
    }

    function removeDefaultOperator(address _operator) public onlyOwner canManageDefaultOperator {
        require(mIsDefaultOperator[_operator] == true, "This operator is not default operator");
        uint256 operatorIndex;
        uint256 count = mDefaultOperators.length;
        for (operatorIndex = 0; operatorIndex < count; operatorIndex++) {
            if (mDefaultOperators[operatorIndex] == _operator) {
                break;
            }
        }
        if (operatorIndex + 1 < count) {
            mDefaultOperators[operatorIndex] = mDefaultOperators[count - 1];
        }
        mDefaultOperators.length = mDefaultOperators.length - 1;
        mIsDefaultOperator[_operator] = false;
        emit DefaultOperatorRemoved(_operator);
    }

    function doMint(address _tokenHolder, uint256 _amount, bytes _operatorData) private {
        require(_tokenHolder != address(0), "Cannot mint to address 0x0");
        requireMultiple(_amount);

        mTotalSupply = mTotalSupply.add(_amount);
        mBalances[_tokenHolder] = mBalances[_tokenHolder].add(_amount);

        callRecipient(msg.sender, address(0), _tokenHolder, _amount, "", _operatorData, false);

        emit Minted(msg.sender, _tokenHolder, _amount, _operatorData);
        if (mErc20compatible) { emit Transfer(address(0), _tokenHolder, _amount); }
    }

    function doSendWithSignature(address _to, uint256 _amount, uint256 _fee, bytes _data, uint256 _nonce, bytes _sig, bool _preventLocking) private {
        require(_to != address(0));
        require(_to != address(this)); // token contract does not accept own tokens

        require(signatures[_sig] == false);
        signatures[_sig] = true;

        bytes memory packed;
        if (_preventLocking) {
            packed = abi.encodePacked(address(this), _to, _amount, _fee, _data, _nonce);
        } else {
            packed = abi.encodePacked(address(this), _to, _amount, _fee, _data, _nonce, "ERC20Compat");
        }

        address signer = keccak256(packed)
            .toEthSignedMessageHash()
            .recover(_sig); // same security considerations as in Ethereum TX
        
        require(signer != address(0));
        require(transfersEnabled || signer == tokenBag || _to == tokenBag);

        uint256 total = _amount.add(_fee);
        require(mBalances[signer] >= total);

        doSend(msg.sender, signer, _to, _amount, _data, "", _preventLocking);
        if (_fee > 0) {
            doSend(msg.sender, signer, msg.sender, _fee, "", "", _preventLocking);
        }
    }

    /// @notice Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
    ///  May throw according to `_preventLocking`
    /// @param _from The address holding the tokens being sent
    /// @param _to The address of the recipient
    /// @param _amount The number of tokens to be sent
    /// @param _userData Data generated by the user to be passed to the recipient
    /// @param _operatorData Data generated by the operator to be passed to the recipient
    /// @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
    ///  implementing `ERC777TokensRecipient`.
    ///  ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
    ///  functions SHOULD set this parameter to `false`.
    function callRecipient(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes _userData,
        bytes _operatorData,
        bool _preventLocking
    ) internal {
        address recipientImplementation = interfaceAddr(_to, "ERC777TokensRecipient");
        if (recipientImplementation != 0) {
            ERC777TokensRecipient(recipientImplementation).tokensReceived(
                _operator, _from, _to, _amount, _userData, _operatorData);
        } else if (throwOnIncompatibleContract && _preventLocking) {
            require(isRegularAddress(_to));
        }
    }
}
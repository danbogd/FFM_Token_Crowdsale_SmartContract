# Files.fm Token Smart Contract

## Testing

Before running test suite you need to start `ganache-cli` with the following command

`ganache-cli -a 200 -e 1000000`

After that start test suite with `truffle test` or `npm test` in a separate terminal session.

## Deployment

1. Recheck token name and symbol in FilesFMToken.sol (lines 14, 15).
2. Deploy token smart contract using `truffle migrate` or manually by using some other tool (for example https://myetherwallet.com)

## Token functionality

* Files.fm Token is ERC777 token and is fully ERC20 compatible 

* Tokens can be minted using `mintToken()` function for single address minting or using `mintTokens()` function for batched minting. Batch size is limited to maximum of 100 addresses

* Tokens cannot be minted to zero address (0x0)

* When using `mintTokens()` function, one must be ensured that passed arrays lengths have the same length

* Tokens can be minted only by token contract owner or special account called `tokenMinter` which can be set using `setTokenMinter()` function. `setTokenMinter()` function can be called only by token contract owner

* Token contract forbids token transfers until token transfers are not enabled

* Token transfers can be enabled with `permitTransfers()` function call, which can be called only by token contract owner and it can be called only once.

* After calling `permitTransfers()` function token transfers are unlocked and cannot be locked again

* Token supports token recovery if somebody, accidentially transfers tokens to the token contract address. Owner can call `recoverTokens(ERC20Basic token, address to, uint256 amount)` function where:
  * `token` - token contract address
  * `to` - the address where tokens will be transfer
  * `amount` - amount of tokens to recover

* When token ownership is transfered or renounced `tokenMinter` address is reset to `0x0` address

* ERC777 standard does not allow sending tokens to incompatible contracts. However, `throwOnIncompatibleContract` flag is present in token contract to overload this behavior, if some issues will arise. This flag can be set (or reset) using `setThrowOnIncompatibleContract()` function, which can be called only by contract token owner.

* Token contract supports so-called *Etherless transfers*. Etherless transfers can be done using `sendWithSignature()` or `transferWithSignature()` function calls

  * `sendWithSignature()` uses ERC777 `send()` function and does not allow sending tokens to non-compatible contracts, unless `throwOnIncompatibleContract` is set to  `false`
  * `transferWithSignature()` uses standard ERC20 `transfer()` function and allows sending tokens to non-compatible contracts. Additional flag `ERC20Compat` must be added to signature, in that way the tx submitter cannot push the signature to the wrong function.

* Token contract supports special address called `tokenBag`. Token bag can be set only by the owner using ­`setTokenBag()` function call. Token allows transfers from and to this address despite `transfersEnabled` flag. Token Bag cannot be reset to address `0x0` until current token bag has balance 0. Token contract sends balance of the current token bag to the new token bag on `setTokenBag()` function call.
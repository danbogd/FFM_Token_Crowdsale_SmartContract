pragma solidity 0.4.24;

import { ERC777Token } from "./erc777/contracts/ERC777Token.sol";
import { ERC777TokensRecipient } from "./erc777/contracts/ERC777TokensRecipient.sol";
import { Ownable } from "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { ERC820Implementer } from "./eip820/contracts/ERC820Implementer.sol";


contract ERC777TokenScheduledTimelock is ERC820Implementer, ERC777TokensRecipient, Ownable {
    using SafeMath for uint256;

    ERC777Token public token;
    uint256 public totalLocked;

    struct Timelock {
        uint256 till;
        uint256 amount;
    }

    mapping(address => Timelock[]) public schedule;

    event Timelocked(address indexed to, uint256 amount, uint256 until);
    event Released(address indexed to, uint256 amount);

    constructor(address _token) public {
        setInterfaceImplementation("ERC777TokensRecipient", address(this));
        address tokenAddress = interfaceAddr(_token, "ERC777Token");
        require(tokenAddress != address(0));
        token = ERC777Token(tokenAddress);
    }

    function () public payable {
        release(msg.sender);
        if (msg.value > 0) {
            msg.sender.transfer(msg.value);
        }
    }

    function release(address beneficiary) public {
        Timelock[] storage timelocks = schedule[beneficiary];
        uint256 tokens = 0;
        uint256 till;
        uint256 n = timelocks.length;
        uint256 i = n;
        while (i > 0) {
            i--;
            Timelock storage timelock = timelocks[i];
            till = timelock.till;
            if (till <= now) {
                tokens = tokens.add(timelock.amount);
                n--;
                if (i != n) {
                    timelocks[i] = timelocks[n];
                }
            }
        }
        timelocks.length = n;
        if (tokens == 0) return;

        totalLocked = totalLocked.sub(tokens);
        token.send(beneficiary, tokens, '');
        emit Released(beneficiary, tokens);
    }
    
    function tokensReceived(address, address, address, uint256, bytes, bytes) public {}

    function getScheduledTimelockCount(address _beneficiary) public view returns (uint256) {
        return schedule[_beneficiary].length;
    }

    function getBalance(address holder) public view returns (uint256) {
        Timelock[] storage timelocks = schedule[holder];
        uint256 tokens = 0;
        uint256 n = timelocks.length;
        for (uint256 i = 0; i < n; i++) {
            Timelock storage timelock = timelocks[i];
            if (timelock.till <= now) {
                tokens = tokens.add(timelock.amount);
            }
        }
        return tokens;
    }

    function getTotalBalance(address holder) public view returns (uint256) {
        Timelock[] storage timelocks = schedule[holder];
        uint256 tokens = 0;
        uint256 n = timelocks.length;
        for (uint256 i = 0; i < n; i++) {
            tokens = tokens.add(timelocks[i].amount);
        }
        return tokens;
    }

    function scheduleTimelock(address _beneficiary, uint256 _lockTokenAmount, uint256 _lockTill) internal {
        require(_beneficiary != address(0));
        require(_lockTokenAmount > 0);
        require(_lockTill > now);
        require(token.balanceOf(address(this)) >= totalLocked.add(_lockTokenAmount));
        totalLocked = totalLocked.add(_lockTokenAmount);

        schedule[_beneficiary].push(Timelock({ till: _lockTill, amount: _lockTokenAmount }));
        emit Timelocked(_beneficiary, _lockTokenAmount, _lockTill);
    }
}
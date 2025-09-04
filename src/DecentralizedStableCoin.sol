// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* Layout of the contract file: */
// version
// imports
// interfaces, libraries, contract

// Inside Contract:
// Errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/** 
 @title Decentralized StableCoin (aka DSC)
 @author Paolo Montecchiani
 @notice This contract is a prototype for a decentralized stablecoin system.

 This contract will be governed by the DSCEngine contract.
 This contract will be just the ERC20 implementation of our stablecoin system
*/

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

error DecentralizedStableCoin__BurnAmountExceedsBalance();
error DecentralizedStableCoin__AmountLessOrEqualToZero();

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0)
            revert DecentralizedStableCoin__AmountLessOrEqualToZero();
        if (balance < _amount)
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_amount <= 0)
            revert DecentralizedStableCoin__AmountLessOrEqualToZero();
        _mint(_to, _amount);
        return true;
    }
}

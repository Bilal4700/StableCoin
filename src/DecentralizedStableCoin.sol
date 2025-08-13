// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
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

pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DecentralizedStableCoin
 * @author Muhammad Bilal
 * @dev This contract implements a decentralized stablecoin.
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 * Collateral: BTC and ETH
 *
 * This is the contract meant to be governed by DSCEngine. This contract is just the ERC20 implementation of our stablecoin.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustBeGreaterThanZero();
    error DecentralizedStableCoin__InsufficientBalance();
    error DecentralizedStableCoin__NotToAddressZero();

    constructor()
        ERC20("Decentralized Stable Coin", "DSC")
        Ownable(msg.sender)
    {}

    /**
     * @dev Mints `amount` of tokens to the `to` address.
     * Only the owner can call this function.
     */

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeGreaterThanZero();
        }
        if (_amount > balance) {
            revert DecentralizedStableCoin__InsufficientBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotToAddressZero();
        }

        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustBeGreaterThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}

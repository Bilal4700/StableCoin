// SPDX-License-Identifier: MIT

// Have our invariants

// Invariants Eg in our project
// 1. Total supply of stablecoin should be less than or equal to the total collateral value
// 2. Getter View functions should never revert

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployEngine} from "../../script/DeployDSCEngine.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OpenInvariantTest is StdInvariant, Test {
    DeployEngine deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig helperConfig;
    address weth;
    address usdc;

    function setUp() public {
        // Set up your test environment

        deployer = new DeployEngine();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (weth, usdc,,,) = helperConfig.activeNetworkConfig();
        targetContract(address(dscEngine));
    }

    function invariant_protocol_must_have_more_collateral_than_total_supply() public view {
        // Get the total supply of the stablecoin
        uint256 totalSupply = dsc.totalSupply();
        // Get the total collateral value in the DSCEngine
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(usdc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getTokenPriceInUsd(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getTokenPriceInUsd(usdc, totalWbtcDeposited);

        console.log("Total Supply: ", totalSupply);
        console.log("Total WETH Value: ", wethValue);
        console.log("Total WBTC Value: ", wbtcValue);
        // Assert that the total collateral value is greater than or equal to the total supply
        assert(wethValue + wbtcValue >= totalSupply); // i am doing >= because i want to ensure the protocol is always overcollateralized and right now the contract has 0 total supply
    }
}

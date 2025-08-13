// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployEngine} from "../../script/DeployDSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    DeployEngine public deployer;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public USER;
    address public weth;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        USER = makeAddr("USER");
        deployer = new DeployEngine();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (weth,, ethUsdPriceFeed,,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    /////////////////////////////
    //      Price Tests        //
    /////////////////////////////

    function testGetTokenPriceInUsdForAnvil() public view {
        uint256 ethAmount = 15 ether;
        // 15 * 2000 = 30000
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscEngine.getTokenPriceInUsd(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    ///////////////////////////////////////
    //      Deposit Collateral Tests     //
    ///////////////////////////////////////
    function testRevertsIfCollateralIsZeroForAnvil() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}

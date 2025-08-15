// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployEngine} from "../../script/DeployDSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    DeployEngine public deployer;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public USER;
    address public weth;
    address public wbtc;
    address public wbtcUsdPriceFeed;
    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    function setUp() public {
        USER = makeAddr("USER");
        deployer = new DeployEngine();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (weth, wbtc, ethUsdPriceFeed, wbtcUsdPriceFeed,) = helperConfig.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////////////////
    //      Constructor Tests        //
    ///////////////////////////////////
    address[] tokenAddresses;
    address[] priceFeeds;

    function testRevertsIfTokenAddressesDoNotMatch() public {
        tokenAddresses.push(weth);
        tokenAddresses.push(wbtc);
        priceFeeds.push(ethUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressShouldBeEqualToPriceFeedAddressInLength.selector);
        new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
    }

    /////////////////////////////
    //      Price Tests        //
    /////////////////////////////

    function testgetTokenAmountFromUsd() public view {
        uint256 usdAmount = 30000e18;
        // 30000 / 2000 = 15
        uint256 expectedEth = 15 ether;
        uint256 actualEth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualEth, expectedEth);
    }

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

    function testRevertsWithUnapprovedCollateral() public {
        vm.startPrank(USER);
        ERC20Mock token45 = new ERC20Mock();
        token45.approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert();
        dscEngine.depositCollateral(address(token45), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testDepositCollateralAndGetAccountInformation() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedCollateralValue = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(AMOUNT_COLLATERAL, expectedCollateralValue);
    }

    function testCanDepositCollateralWithoutMinting() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (amountCollateral * (uint256(price) * dscEngine.getAdditionalFeedPrecision())) / dscEngine.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);

        vm.expectRevert();
        dscEngine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }
}

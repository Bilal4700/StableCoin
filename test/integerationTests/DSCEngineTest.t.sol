// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployEngine} from "../../script/DeployDSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {MockFailedMintDSC} from "../Mocks/MockFailedMintDsc.sol";

contract DSCEngineTest is Test {
    DSCEngine public dscEngine;
    DecentralizedStableCoin public dsc;
    DeployEngine public deployer;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public wbtcUsdPriceFeed;
    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() public {
        deployer = new DeployEngine();
        (dsc, dscEngine, helperConfig) = deployer.run();
        (weth, wbtc, ethUsdPriceFeed, wbtcUsdPriceFeed,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE); // Add this line to mint to user as well
    }

    ///////////////////////////////////
    //      Modifiers                //
    ///////////////////////////////////

    modifier depositCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
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
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        vm.startPrank(user);
        ERC20Mock token45 = new ERC20Mock();
        token45.approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert();
        dscEngine.depositCollateral(address(token45), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateralAndGetAccountInformation() public depositCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(user);
        uint256 expectedCollateralValue = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(AMOUNT_COLLATERAL, expectedCollateralValue);
    }

    function testCanDepositCollateralWithoutMinting() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(user);
        uint256 expectedCollateralValue = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, 0);
        assertEq(AMOUNT_COLLATERAL, expectedCollateralValue);
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

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    //         mintDsc Tests         //
    ///////////////////////////////////

    // The Mock file used fails in Mint
    function testRevertsIfMintFails() public {
        MockFailedMintDSC mockFailedDSC = new MockFailedMintDSC();
        address[] memory tokens = new address[](2);
        tokens[0] = weth;
        tokens[1] = wbtc;
        address[] memory feeds = new address[](2);
        feeds[0] = ethUsdPriceFeed;
        feeds[1] = wbtcUsdPriceFeed;

        DSCEngine engineWithMock = new DSCEngine(tokens, feeds, address(mockFailedDSC));
        mockFailedDSC.transferOwnership(address(engineWithMock)); // Transfer ownership to DSCEngine

        vm.startPrank(user);
        ERC20Mock(weth).approve(address(engineWithMock), amountCollateral);
        engineWithMock.depositCollateral(weth, amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engineWithMock.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(weth, amountCollateral);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositCollateral {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (amountCollateral * (uint256(price) * dscEngine.getAdditionalFeedPrecision())) / dscEngine.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor =
            dscEngine.calculateHealthFactor(amountToMint, dscEngine.getTokenPriceInUsd(weth, amountCollateral));

        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorIsBelowMinimum.selector, expectedHealthFactor)
        );
        dscEngine.mintDsc(amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositCollateral {
        vm.prank(user);
        dscEngine.mintDsc(amountToMint);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    function testIfMintAmountIsGreaterThanCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateral(weth, amountCollateral);

        // Calculate amount that would break health factor
        // 10 ETH * $2000 = $20,000 collateral
        // Max mintable = $20,000 * 50% = $10,000 DSC
        // Let's try to mint $15,000 DSC (more than allowed)
        uint256 tooMuchToMint = 15000 ether;

        uint256 expectedHealthFactor =
            dscEngine.calculateHealthFactor(tooMuchToMint, dscEngine.getTokenPriceInUsd(weth, amountCollateral));

        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__HealthFactorIsBelowMinimum.selector, expectedHealthFactor)
        );
        dscEngine.mintDsc(tooMuchToMint);
        vm.stopPrank();
    }

    ///////////////////////////////////
    //         burnDsc Tests         //
    ///////////////////////////////////

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        dscEngine.burnDsc(1);
    }

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscEngine), amountCollateral);
        dscEngine.depositCollateralAndMintDsc(weth, amountCollateral, amountToMint);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        dsc.approve(address(dscEngine), amountToMint);
        dscEngine.burnDsc(amountToMint);
        vm.stopPrank();

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    //     redeemCollateral Tests    //
    ///////////////////////////////////

    function testRevertsIfTransferFails() public {}

    function testRevertsIfRedeemAmountIsZero() public {}

    function testCanRedeemCollateral() public depositCollateral {}

    function testEmitCollateralRedeemedWithCorrectArgs() public depositCollateral {}

    ///////////////////////////////////
    // redeemCollateralForDsc Tests  //
    ///////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedDsc {}

    function testCanRedeemDepositedCollateral() public {}

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {}

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {}
}

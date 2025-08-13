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

import "./IDSCEngine.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/*
 * @title DSCEngine
 * @author Muhammad Bilal
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is IDSCEngine, ReentrancyGuard {
    //////////////////////////
    // Errors               //
    //////////////////////////

    error DSCEngine__HealthFactorIsBelowMinimum(uint256 userHealthFactor);
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressShouldBeEqualToPriceFeedAddressInLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();

    //////////////////////////
    // Type Variables       //
    //////////////////////////

    //////////////////////////
    // State Variables      //
    //////////////////////////

    uint256 private constant MINIMUM_HEALTH_FACTOR = 1;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Additional precision for price feeds to avoid rounding errors
    uint256 private constant PRECISION = 1e18;
    mapping(address token => address priceFeed) public s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 totalDscMinted) public s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    //////////////////////////
    // Events               //
    //////////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    //////////////////////////
    // Modifiers            //
    //////////////////////////

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) revert DSCEngine__NeedsMoreThanZero();
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeed[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //////////////////////////
    // Functions            //
    //////////////////////////

    constructor(address[] memory tokenAddresses, address[] memory priceFeeds, address dscAddress) {
        if (tokenAddresses.length != priceFeeds.length) {
            revert DSCEngine__TokenAddressShouldBeEqualToPriceFeedAddressInLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeed[tokenAddresses[i]] = priceFeeds[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //////////////////////////
    // External Functions   //
    //////////////////////////

    /**
     * @notice Deposits collateral and mints DSC in a single transaction
     * @dev This function combines depositing collateral and minting DSC for gas efficiency
     */
    function depositCollateralForDsc() external override {}

    /**
     * @param collateralToken The address of the collateral token being deposited
     * @param amountCollateral The amount of collateral tokens to deposit
     * @notice Deposits collateral tokens to back DSC
     * @notice Follow CEI (Checks-Effects-Interactions)
     * @dev Collateral must be approved tokens (BTC, ETH) to maintain system stability
     */
    function depositCollateral(address collateralToken, uint256 amountCollateral)
        external
        override
        moreThanZero(amountCollateral)
        isAllowedToken(collateralToken)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][collateralToken] += amountCollateral;
        // Logic to transfer collateral from user to this contract
        emit CollateralDeposited(msg.sender, collateralToken, amountCollateral);
        i_dsc.mint(msg.sender, amountCollateral);
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice Redeems collateral and burns DSC in a single transaction
     * @dev This function combines burning DSC and redeeming collateral for gas efficiency
     */
    function redeemCollateralForDsc() external override {}

    /**
     * @notice Redeems collateral tokens from the system
     * @dev User must maintain proper collateralization ratio after redemption
     */
    function redeemCollateral() external override {}

    /**
     * @notice Mints DSC tokens backed by deposited collateral
     * @notice They must have more collateral than the amount of DSC being minted
     * @notice Follow CEI (Checks-Effects-Interactions)
     * @param amountDscToMint The amount of DSC to mint
     * @param collateralToken The address of the collateral token being used
     * @dev User must have sufficient collateral to maintain health factor above threshold
     */
    function mintDsc(uint256 amountDscToMint, address collateralToken)
        external
        override
        moreThanZero(amountDscToMint)
        nonReentrant
    {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, amountDscToMint);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * @notice Burns DSC tokens to improve collateralization ratio
     * @dev Burning DSC reduces debt and improves user's health factor
     */
    function burnDsc() external override {}

    /**
     * @notice Liquidates an undercollateralized position
     * @dev Allows liquidators to pay off user's debt and claim their collateral at a discount
     */
    function liquidate() external override {}

    /**
     * @notice Calculates the health factor of a user's position
     * @param user The address of the user to check
     * @return The health factor (scaled by 1e18). Below 1e18 means undercollateralized
     * @dev Health factor = (collateral value * liquidation threshold) / debt value
     */
    function getHealthFactor(address user) external view override returns (uint256) {}

    //////////////////////////////////////
    // Private and Internal Functions   //
    //////////////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) internal view returns (uint256) {
        // Returns how close a user is to liquidation
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / 100;
        return collateralAdjustedForThreshold * PRECISION / totalDscMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // Check Health Factor (collateral value * liquidation threshold) / debt value
        // Revert if the health factor is below 1
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBelowMinimum(userHealthFactor);
        }
    }
    //////////////////////////////////////
    // Public and View Functions        //
    //////////////////////////////////////

    function getAccountCollateralValue(address user) internal view returns (uint256 collateralValueInUsd) {
        // Get the total collateral value in USD for a user

        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 tokenAmount = s_collateralDeposited[user][token];
            collateralValueInUsd += getTokenPriceInUsd(token, tokenAmount);
        }
        return collateralValueInUsd;
    }

    function getTokenPriceInUsd(address token, uint256 amount) public view returns (uint256) {
        // Get the price of a token in USD
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        // Convert to uint256 and scale by 1e18 for precision
        return (uint256(price) * amount * ADDITIONAL_FEED_PRECISION) / PRECISION;
    }
}

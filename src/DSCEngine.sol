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
    error DSCEngine__HealthFactorIsOk(uint256 startingHealthFactor);
    error DSCEngine__HealthFactorNotImproved();

    //////////////////////////
    // Type Variables       //
    //////////////////////////

    //////////////////////////
    // State Variables      //
    //////////////////////////

    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Additional precision for price feeds to avoid rounding errors
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% liquidation bonus
    mapping(address token => address priceFeed) public s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 totalDscMinted) public s_DSCMinted;
    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    //////////////////////////
    // Events               //
    //////////////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

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
     * @param collateralToken The address of the collateral token being deposited
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DSC to mint
     */
    function depositCollateralAndMintDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToMint)
        external
        override
    {
        depositCollateral(collateralToken, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice Redeems collateral and burns DSC in a single transaction
     * @dev This function combines burning DSC and redeeming collateral for gas efficiency
     * @param collateralToken The address of the collateral token to redeem
     * @param amountCollateral The amount of collateral to redeem
     * @param amountDscToBurn The amount of DSC to burn
     */
    function redeemCollateralForDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToBurn)
        external
        override
    {
        burnDsc(amountDscToBurn);
        redeemCollateral(collateralToken, amountCollateral);
    }

    /**
     * @notice Redeems collateral tokens from the system
     * @dev User must maintain proper collateralization ratio after redemption
     * @param collateralToken The address of the collateral token being redeemed
     * @param amountCollateral The amount of collateral to redeem
     */
    function redeemCollateral(address collateralToken, uint256 amountCollateral)
        public
        override
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, collateralToken, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    /**
     * @notice Burns DSC tokens to improve collateralization ratio
     * @dev Burning DSC reduces debt and improves user's health factor
     */

    function burnDsc(uint256 amount) public override moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates an undercollateralized position
     * @notice Liquidators can pay off the user's debt and claim their collateral at a discount
     * @notice You can partially liquidate a user's position
     * @notice Works only when over-collateralized
     * @dev Allows liquidators to pay off user's debt and claim their collateral at a discount
     * @dev Follow CEI (Checks-Effects-Interactions)
     * @dev Liquidators can only liquidate positions that are undercollateralized
     * @dev Liquidators will recieve 10% of the user's collateral
     * @param collateral The address of the collateral token to liquidate
     * @param user The address of the user whose position is being liquidated
     * @param debtToCover The amount of debt to cover
     */
    // For example someone got $50 worth of DSC and their collateral is worth $75 which is below threshold
    // Liquidators can pay off the $50 DSC and claim some $75 collateral at a discount or
    // They will get paid user collateral + bonus
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        override
        moreThanZero(debtToCover)
    {
        uint256 startingHealthFactor = _healthFactor(user);
        if (startingHealthFactor >= MINIMUM_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsOk(startingHealthFactor);
        }

        /**
         * We Want to burn their DSC debt
         * And take their collateral
         * for Example
         * USER: $140 collateral and $100 Dsc
         * LIQUIDATOR: $100 to cover debt and burn it
         * LIQUIDATOR: recieved 10% Oover $140 worth of collateral
         * LIQUIDATOR: $154 worth of collateral recieved
         */
        uint256 TokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        uint256 bonusCollateral = (TokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = TokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnDsc(debtToCover, user, msg.sender);
        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor < startingHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender); // Check liquidator's health factor
    }

    /**
     * @notice Calculates the health factor of a user's position
     * @param user The address of the user to check
     * @return The health factor (scaled by 1e18). Below 1e18 means undercollateralized
     * @dev Health factor = (collateral value * liquidation threshold) / debt value
     */
    function getHealthFactor(address user) external view override returns (uint256) {
        return _healthFactor(user);
    }

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
    /**
     * @notice Redeems collateral from a user's account low-level
     * @param from The address of the user to redeem collateral from
     * @param to The address to send the redeemed collateral to
     * @param collateralToken The address of the collateral token to redeem
     * @param amountCollateral The amount of collateral to redeem
     */

    function _redeemCollateral(address from, address to, address collateralToken, uint256 amountCollateral) private {
        s_collateralDeposited[from][collateralToken] -= amountCollateral;
        emit CollateralRedeemed(from, to, collateralToken, amountCollateral);
        bool success = IERC20(collateralToken).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        _revertIfHealthFactorIsBroken(msg.sender); // Doing this at the end to ensure all state changes are made before checking health factor and to save gas
    }
    /**
     * @notice Burns DSC tokens from a user's account low-level
     * @param amountDscToBurn The amount of DSC to burn
     * @param onBehalfOf The address of the user whose DSC is being burned
     * @param dscfrom The address to transfer the DSC from
     */

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscfrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscfrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
        _revertIfHealthFactorIsBroken(onBehalfOf);
    }

    //////////////////////////////////////
    // Public and View Functions        //
    //////////////////////////////////////

    function getTokenAmountFromUsd(address collateral, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[collateral]);
        (, int256 price,,,) = priceFeed.latestRoundData();

        // Convert to uint256 and scale by 1e18 for precision
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @param collateralToken The address of the collateral token being deposited
     * @param amountCollateral The amount of collateral tokens to deposit
     * @notice Deposits collateral tokens to back DSC
     * @notice Follow CEI (Checks-Effects-Interactions)
     * @dev Collateral must be approved tokens (BTC, ETH) to maintain system stability
     */
    function depositCollateral(address collateralToken, uint256 amountCollateral)
        public
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
     * @notice Mints DSC tokens backed by deposited collateral
     * @notice They must have more collateral than the amount of DSC being minted
     * @notice Follow CEI (Checks-Effects-Interactions)
     * @param amountDscToMint The amount of DSC to mint
     * @dev User must have sufficient collateral to maintain health factor above threshold
     */
    function mintDsc(uint256 amountDscToMint) public override moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_dsc.mint(msg.sender, amountDscToMint);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

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

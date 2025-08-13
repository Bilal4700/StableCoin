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
import {DecentralizedStableCoin} from "./DecenteralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressShouldBeEqualToPriceFeedAddressInLength();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();

    //////////////////////////
    // State Variables      //
    //////////////////////////

    mapping(address token => address priceFeed) public s_priceFeed;
    mapping(address user => mapping(address token => uint256 amount)) public s_collateralDeposited;
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
     * @param amount The amount of DSC to mint
     * @param collateralToken The address of the collateral token being used
     * @dev User must have sufficient collateral to maintain health factor above threshold
     */
    function mintDsc(uint256 amount, address collateralToken) external override {}

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
}

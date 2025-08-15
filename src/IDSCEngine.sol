// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title IDSCEngine Interface
 * @author Muhammad Bilal
 * @dev Interface for the DSC Engine that manages the decentralized stablecoin system
 *
 * This interface defines the core functions for:
 * - Depositing and redeeming collateral
 * - Minting and burning DSC tokens
 * - Liquidating undercollateralized positions
 * - Checking user health factors
 */
interface IDSCEngine {
    function depositCollateralAndMintDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToMint)
        external;

    function depositCollateral(address collateralToken, uint256 amountCollateral) external;

    function redeemCollateralForDsc(address collateralToken, uint256 amountCollateral, uint256 amountDscToBurn)
        external;

    function redeemCollateral(address collateralToken, uint256 amountCollateral) external;

    function mintDsc(uint256 amountDscToMint) external;

    function burnDsc(uint256 amount) external;

    function liquidate(address collateral, address user, uint256 debtToCover) external;

    function getHealthFactor(address user) external view returns (uint256);
}

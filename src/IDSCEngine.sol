// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IDSCEngine {
    function depositCollateralForDsc() external;

    function redeemCollateralForDsc() external;

    function burnDsc() external;

    function liquidate() external;

    function getHealthFactor(address user) external view returns (uint256);
}

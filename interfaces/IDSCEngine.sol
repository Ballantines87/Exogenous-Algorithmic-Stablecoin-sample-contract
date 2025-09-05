// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDSCEngine {
    function depositCollateralAndMintDsc() external payable;

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external;

    function redeemCollateral() external;

    function redeemCollateralForDsc() external;

    function mintDsc(uint256 amountDscToMint) external;

    // allows to burn DSC to reduce debt
    function burnDsc() external;

    // function that other users can call to remove people's positions if undercollateralized and save the protocol
    // the liquidators will pay back the DSC debt and get the liquidated user's collateral at a discount
    function liquidate() external;

    // allows people to see how close to liquidation people are to the liquidation threshold
    function getHealthFactor(address user) external view returns (uint256);
}

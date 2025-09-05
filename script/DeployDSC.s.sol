// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public helperConfig;

    address[] public collateralTokenAddresses;
    address[] public priceFeedAddresses;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address wbtcContractAddress;
    address wethContractAddress;
    uint256 deployerKey;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        helperConfig = new HelperConfig();

        (
            wethUsdPriceFeed,
            wbtcUsdPriceFeed,
            wethContractAddress,
            wbtcContractAddress,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        collateralTokenAddresses = [wethContractAddress, wbtcContractAddress];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast();
        dsc = new DecentralizedStableCoin();
        dscEngine = new DSCEngine(
            collateralTokenAddresses,
            priceFeedAddresses,
            address(dsc)
        );

        vm.stopBroadcast();
        return (dsc, dscEngine);
    }
}

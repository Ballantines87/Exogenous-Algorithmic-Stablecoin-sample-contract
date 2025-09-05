// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address wethContractAddress;
        address wbtcContractAddress;
        uint256 deployerKey;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 30000e8;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public returns (NetworkConfig memory) {
        return
            NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                wethContractAddress: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
                wbtcContractAddress: 0x0F892c2988F620Ad27ABf876b74A9B1b4888E7Ac,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator wethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        ); // decimals, initialAnswer in price feed
        MockV3Aggregator wbtcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );

        ERC20Mock wethMock = new ERC20Mock(
            "Wrapped Ether",
            "WETH",
            msg.sender,
            1000e8
        );
        ERC20Mock wbtcMock = new ERC20Mock(
            "Wrapped Bitcoin",
            "WBTC",
            msg.sender,
            1000e8
        );
        vm.stopBroadcast();

        console.log(
            "WETH Price Feed deployed to %s",
            address(wethUsdPriceFeed)
        );
        console.log(
            "WBTC Price Feed deployed to %s",
            address(wbtcUsdPriceFeed)
        );
        console.log("WETH deployed to %s", address(wethMock));
        console.log("WBTC deployed to %s", address(wbtcMock));

        return
            NetworkConfig({
                wethUsdPriceFeed: address(wethUsdPriceFeed),
                wbtcUsdPriceFeed: address(wbtcUsdPriceFeed),
                wethContractAddress: address(wethMock),
                wbtcContractAddress: address(wbtcMock),
                deployerKey: vm.envUint("DEFAULT_ANVIL_KEY")
            });
    }
}

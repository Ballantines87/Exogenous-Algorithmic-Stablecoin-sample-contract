// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/* Layout of the contract file: */
// version
// imports
// interfaces, libraries, contract

// Inside Contract:
// Errors
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

/** 
 @title DSCEngine (aka Decentralized StableCoin Engine)
 @author Paolo Montecchiani
 The system is designed to be as minimal as possible and have the tokens maintain a 1 token == $1 peg.

 This stablecoin has the properties of:
    - Exogenous Collateral (only accepts external tokens as collateral, never its own)
    - Dollar Pegged
    - Algorithmically Stable (not backed by any asset, but maintains the peg via algorithmic mechanisms)

 It is similar to DAI if DAI had no governance, no fees, and was backed only by wBTC and wETH.

 Our DSC system should always be overcollateralized. At no point, should the value of all the collateral <= the $ backed value of all the DSC.

 @notice This contract is the CORE of the DSC system. It handles all the logic for minting and redeeming DSC, as well as depositing and withdrawing collateral.

 @notice This contract is very loosely based on the MakerDAO DSS (DAI Stablecoin System) and the Reflexer RAI system.
*/

import {IDSCEngine} from "../interfaces/IDSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is IDSCEngine, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DSCEngine__AmountNeedsToBeMoreThanZero();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    error DSCEngine__TransferFailed();
    error DSCEngine__HealthFactorIsBelowMinimum();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address[] private s_collateralTokens;

    mapping(address tokenAddress => address priceFeedAddress)
        private s_tokenAddressToPriceFeed;

    // this is a mapping to a mapping
    // user address -> token address -> amount deposited
    // this is to keep track of how much collateral each user has deposited
    mapping(address userAddress => mapping(address tokenAddress => uint256 collateralAmountDeposited))
        private s_collateralDeposited;

    mapping(address userAddress => uint256 totalDSCMintedByUser)
        private s_userToTotalDSCMintedByUser;

    DecentralizedStableCoin private immutable i_dscContractAddress;

    uint256 public constant MIN_HEALTH_FACTOR = 10;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );

    event TransferFrom(
        address indexed from,
        address indexed token,
        uint256 indexed amount
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert DSCEngine__AmountNeedsToBeMoreThanZero();
        _;
    }

    modifier isAllowedToken(address token) {
        // check if the token is an allowed collateral
        if (s_tokenAddressToPriceFeed[token] == address(0))
            revert DSCEngine__TokenNotAllowed();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(
        address[] memory collateralTokenAddresses,
        address[] memory priceFeedAddresses,
        address _dscContractAddress
    ) {
        if (collateralTokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }

        for (uint index = 0; index < collateralTokenAddresses.length; index++) {
            // ETH / USD price feed and BTC / USD price feed
            s_tokenAddressToPriceFeed[
                collateralTokenAddresses[index]
            ] = priceFeedAddresses[index];
            s_collateralTokens.push(collateralTokenAddresses[index]);
        }

        i_dscContractAddress = DecentralizedStableCoin(_dscContractAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           External Functions
    //////////////////////////////////////////////////////////////*/

    function depositCollateralAndMintDsc() external payable override {}

    /**
     * @notice this function is used to deposit collateral into the DSC system
     * @notice follows the CEI pattern (checks-effects-interactions)
     * @param tokenCollateralAddress the address of the token to be deposited as collateral
     * @param amountCollateral the amount of the token to be deposited as collateral
     */

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        override
        // checks
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;

        // effects (inside the contract)
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );

        // interactions (external interactions)
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );

        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        emit TransferFrom(msg.sender, tokenCollateralAddress, amountCollateral);
    }

    function redeemCollateralForDsc() external override {}

    function redeemCollateral() external override {}

    function burnDsc() external override {}

    function liquidate() external override {}

    /**
     * @notice this function is used to mint the DSC stablecoin
     * @notice follows the CEI pattern (checks-effects-interactions)
     * @param amountDscToMint the amount of DSC to be minted
     */

    function mintDsc(
        uint256 amountDscToMint
    ) external override moreThanZero(amountDscToMint) nonReentrant {
        // checks
        s_userToTotalDSCMintedByUser[msg.sender] += amountDscToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        // effects (inside the contract)
        i_dscContractAddress.mint(msg.sender, amountDscToMint);
        emit TransferFrom(
            address(this),
            address(i_dscContractAddress),
            amountDscToMint
        );

        // interactions (external interactions)
    }

    /*//////////////////////////////////////////////////////////////
                            Getter Functions
    //////////////////////////////////////////////////////////////*/
    function getHealthFactor(
        address user
    ) public view override returns (uint256) {
        return _healthFactor(user);
    }

    function getTotalDscMintedByUser(
        address user
    ) public view returns (uint256) {
        return s_userToTotalDSCMintedByUser[user];
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 accountCollateralValueOfUser) {
        // 1. loop through each collateral token
        // 2. get the amount of each token deposited by the user
        // 3. get the USD value of each token
        // 4. add the value to the total collateral value
        // 5. return the total collateral value

        uint256 totalCollateralValueInUsd = 0;
        uint256 collateralAmountDepositedByUser;
        address collateralTokenAddress;
        for (uint i = 0; i < s_collateralTokens.length; i++) {
            collateralTokenAddress = s_collateralTokens[i];
            collateralAmountDepositedByUser = s_collateralDeposited[user][
                s_collateralTokens[i]
            ];
            totalCollateralValueInUsd += getUsdValueOfCollateral(
                collateralAmountDepositedByUser,
                collateralTokenAddress
            );
        }
        return totalCollateralValueInUsd;
    }

    function getUsdValueOfCollateral(
        uint256 amount,
        address tokenCollateralAddress
    ) public view returns (uint256) {
        // 1. get the price of the token
        // 2. convert the amount to USD value
        // 3. return the USD value

        AggregatorV3Interface priceFeedAddress = AggregatorV3Interface(
            s_tokenAddressToPriceFeed[tokenCollateralAddress]
        );
        (, int256 answer, , , ) = priceFeedAddress.latestRoundData();

        // if 1 $ETH = 1000 USD -> then the returned value will be 1000_00000000 (aka 1000 with 8 decimals or 1000 * 10^8 or 1000 * 1e8)
        uint256 price = ((uint256(answer) * 1e18) / 1e8); // we need to multiply answer by 1e18 to have the same decimals as the amount (which is in wei)
        // n.b. that's a magic number and could use a constant
        return (price * amount) / 1e18; // we need to divide by 1e18 to get the correct USD value because amount is in wei (aka 1e18) and so we need to adjust for that by dividing by 1e18
    }

    /*//////////////////////////////////////////////////////////////
                       Private & Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice this function is used to calculate the health factor of a user
     * if the health factor is below the minimum (aka 1), the user can get liquidated
     * @param user the address of the user to calculate the health factor for
     */
    function _healthFactor(address user) private view returns (uint256) {
        // we need to get:
        // 1. the total DSC minted by the user (aka their debt)
        // 2. the total value of the collateral VALUE deposited by the user
        (
            uint256 totalDscMintedByUser,
            uint256 collateralValueOfUserInUsdOfUser
        ) = _getAccountInformation(user);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = getHealthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBelowMinimum();
        }
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (
            uint256 totalDscMintedByUser,
            uint256 collateralValueOfUserInUsdOfUser
        )
    {
        totalDscMintedByUser = getTotalDscMintedByUser(user);
        collateralValueOfUserInUsdOfUser = getAccountCollateralValue(user);
    }
}

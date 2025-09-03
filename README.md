# Stablecoin Design:

1. Relative Stability: anchored or pegged to the US dollar == $1.00
   1. using Chainlink's Price Feed to make sure it's always pegged to $1.00
   2. then we set a function to exchange ETH and/or BTC to the dollar equivalent

2. Stability Mechanism: algorithmic - decentralized stablecoin
   1. users can only mint the stablecoin with enough collateral

3. Collateral: exogenous (crypto - eth or btc as collateral for our system)
   1. wETH (erc-20 version of btc)
   2. wBTC (erc-20 version of eth)
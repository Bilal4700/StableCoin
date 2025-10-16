# 🪙 Decentralized Stablecoin (DSC)

⚠️ Disclaimer: This is a learning project deployed only on the Sepolia testnet. It has not been audited and is not safe for production use. Use it for experimentation, education, and fun — not for real funds.

**DSC** is a simple yet powerful experiment in building a decentralized, crypto-collateralized stablecoin from the ground up.  
It’s designed to maintain a soft 1:1 peg to the US dollar — without relying on centralized entities, governance tokens, or hidden backdoors.  

Think of it as a stripped-down, educational version of **DAI** — but with only ETH and BTC as collateral, and with the core mechanics of collateral, minting, burning, and liquidation fully transparent on-chain.

> 🧪 **Network:** Sepolia Testnet (`11155111`)  
> 🔗 **Contract Address:** [View on Sepolia Etherscan](https://sepolia.etherscan.io/address/0xf0a847a7615fba0a0040cc0d7b41951213822f98)  


---

## 🌍 What This Project Is About

This project started as a side experiment to deeply understand how stablecoins actually work at the smart contract level.  
The goal was to answer a simple question:  

> *Can we build a truly minimal stablecoin protocol — with no governance and no extra fluff — and still keep it safe, overcollateralized, and stable?*

The result is **DSC**, a fully on-chain system where users deposit crypto as collateral, mint stablecoins against it, and rely on the protocol to keep the system solvent and the peg intact.

---

## 🧠 How It Works (In Plain English)

1. 💰 **Deposit Collateral:** Users lock up approved crypto (like WETH or WBTC) as collateral.  
2. 🪙 **Mint DSC:** Based on how much collateral you have and the required overcollateralization ratio, you mint stablecoins pegged to the US dollar.  
3. 🛡️ **Stay Healthy:** As long as your collateral value stays above the minimum threshold, your position is safe.  
4. 🧹 **Liquidation Safety Net:** If your collateral drops too much, anyone can repay your debt and claim your collateral with a small bonus — keeping the system solvent.  
5. 🔄 **Redeem Anytime:** Burn your DSC to get your collateral back.

It’s all automated. No admin keys. No manual intervention. Just code.

---

## ⚙️ Technical Breakdown

Here’s what’s happening behind the scenes:

- 🏗️ **Smart Contracts:**  
  - `DSCEngine.sol` – The brains of the system (minting, burning, deposits, withdrawals, liquidations).  
  - `DecentralizedStableCoin.sol` – ERC-20 token logic for the DSC stablecoin.  
  - `OracleLib.sol` + Chainlink – Fetches real-time ETH/BTC prices and checks for stale data.

- 📊 **Core Parameters:**  
  - **Collateralization Threshold:** 200% (liquidation triggers below this).  
  - **Liquidation Bonus:** 10% reward to liquidators.  
  - **Precision:** All math done with `1e18` scaling for accuracy.  
  - **Health Factor:** Must always be ≥ `1.0` to avoid liquidation.

- 🔒 **Security Best Practices:**  
  - CEI pattern (Checks-Effects-Interactions).  
  - Reentrancy protection with `ReentrancyGuard`.  
  - Price feed safety checks for stale oracle data.

---

## 🧪 Developer Quickstart

```bash
# Clone the repo
git clone https://github.com/Bilal4700/StableCoin.git
cd StableCoin

# Install dependencies
forge install

# Build & test
forge build
forge test -vvvv

Deploy to anvil Testnet
make deploy

Deploy to Sepolia Testnet
Add your keys to a .env file:
SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"
PRIVATE_KEY="0xYOUR_PRIVATE_KEY"
ETHERSCAN_API_KEY="YOUR_ETHERSCAN_KEY"

make deploy ARGS="--network sepolia"

🛠️ Interacting With the Protocol

Here are a few examples using cast:

# Check a user’s health factor
cast call <DSC_ENGINE_ADDRESS> "getHealthFactor(address)(uint256)" <WALLET>

# Get the price of collateral in USD
cast call <DSC_ENGINE_ADDRESS> "getTokenPriceInUsd(address,uint256)(uint256)" <TOKEN> <AMOUNT>

# Convert USD value to collateral tokens
cast call <DSC_ENGINE_ADDRESS> "getTokenAmountFromUsd(address,uint256)(uint256)" <TOKEN> <USD_AMOUNT_1e18>

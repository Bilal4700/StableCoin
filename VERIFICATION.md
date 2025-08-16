# Contract Verification Guide

## 🎯 Deployed Contracts on Sepolia

### Contract Addresses:

- **DecentralizedStableCoin**: `0x51B045D97B06C2436C27122169863F7300345CEe`
- **DSCEngine**: `0x1089e794dc0f1297bEa21047594b0309ea2C774b`
- **HelperConfig**: `0x5aAdFB43eF8dAF45DD80F4676345b7676f1D70e3`

### Etherscan Links:

- [DecentralizedStableCoin on Etherscan](https://sepolia.etherscan.io/address/0x51B045D97B06C2436C27122169863F7300345CEe)
- [DSCEngine on Etherscan](https://sepolia.etherscan.io/address/0x1089e794dc0f1297bEa21047594b0309ea2C774b)
- [HelperConfig on Etherscan](https://sepolia.etherscan.io/address/0x5aAdFB43eF8dAF45DD80F4676345b7676f1D70e3)

## 🔍 Manual Verification Steps

### 1. Get Etherscan API Key (Free)

1. Go to [Etherscan.io](https://etherscan.io/register)
2. Create a free account
3. Go to [API Keys](https://etherscan.io/myapikey)
4. Create a new API key

### 2. Verify Contracts Using Forge

#### Verify DecentralizedStableCoin:

```bash
forge verify-contract 0x51B045D97B06C2436C27122169863F7300345CEe \
  src/DecentralizedStableCoin.sol:DecentralizedStableCoin \
  --chain sepolia \
  --etherscan-api-key YOUR_API_KEY
```

#### Verify DSCEngine:

```bash
forge verify-contract 0x1089e794dc0f1297bEa21047594b0309ea2C774b \
  src/DSCEngine.sol:DSCEngine \
  --chain sepolia \
  --constructor-args $(cast abi-encode "constructor(address[],address[],address)" \
    "[0xdd13E55209Fd76AfE204dBda4007C227904f0a81,0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063]" \
    "[0x694AA1769357215DE4FAC081bf1f309aDC325306,0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43]" \
    "0x51B045D97B06C2436C27122169863F7300345CEe") \
  --etherscan-api-key YOUR_API_KEY
```

### 3. Using Makefile (After setting API key)

```bash
# Set your API key
export ETHERSCAN_API_KEY=your_api_key_here

# Run verification
make verify-contracts
```

## 🔧 Constructor Arguments for DSCEngine

The DSCEngine was deployed with these constructor arguments:

### Token Addresses (Sepolia):

- **WETH**: `0xdd13E55209Fd76AfE204dBda4007C227904f0a81`
- **WBTC**: `0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063`

### Price Feed Addresses (Sepolia):

- **ETH/USD**: `0x694AA1769357215DE4FAC081bf1f309aDC325306`
- **BTC/USD**: `0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43`

### DSC Token Address:

- **DecentralizedStableCoin**: `0x51B045D97B06C2436C27122169863F7300345CEe`

## ✅ Deployment Verification Checklist

- [x] **Contracts Deployed Successfully**
- [x] **Transaction Hashes Available**
- [x] **Contract Addresses Confirmed**
- [x] **Ownership Transferred to DSCEngine**
- [ ] **Source Code Verified on Etherscan** (Requires API key)
- [x] **Constructor Arguments Documented**

## 🎉 Next Steps

1. **Get Etherscan API Key** for source code verification
2. **Test Contract Interactions** on Sepolia
3. **Monitor Gas Usage** and optimize if needed
4. **Document API endpoints** for frontend integration

## 🛠️ Quick Commands

```bash
# Check deployment
make check-deployment

# Run tests
make test

# Build project
make build

# Verify contracts (with API key)
ETHERSCAN_API_KEY=your_key make verify-contracts
```

---

**Deployment Date**: August 15, 2025  
**Network**: Sepolia Testnet  
**Total Gas Used**: 3,022,903 gas  
**Total Cost**: 0.000024753364914364 ETH

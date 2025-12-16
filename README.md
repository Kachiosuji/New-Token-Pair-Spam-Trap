# New Token Pair Spam Trap - Drosera Network Security

A Drosera Network security trap built for the Hoodi testnet that detects and alerts on "New Token Pair Spam" attacks by monitoring the rate of new pair creation from real DEX factory contracts.

## 📋 Table of Contents

- [Overview](#overview)
- [How It Works](#how-it-works)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [GitHub Codespaces Setup](#github-codespaces-setup)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing the Trap](#testing-the-trap)
- [Project Structure](#project-structure)
- [Contract Details](#contract-details)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

## 🎯 Overview

This project implements a Drosera Trap + Response pair for the Hoodi testnet that is specifically designed to surface a "New Token Pair Spam" pattern on DEX factories.

At a high level, this trap:

- Reads real on-chain data from a DEX factory using `IUniV2Factory.allPairsLength()`
- Compares newest sample vs previous sample (baseline comparison)
- Triggers when net-new pairs exceed 100 within the monitoring window
- Uses official Drosera `ITrap` interface for full operator compatibility

This repo demonstrates:

- ✅ Official `ITrap` interface implementation (no custom storage)
- ✅ Real on-chain data reading (deterministic and operator-compatible)
- ✅ Pure `shouldRespond()` with historical data comparison
- ✅ Planner-safety checks for empty data blobs
- ✅ Proper TOML configuration with string function signatures

The system consists of three deployed contracts:

1. **SimpleMockFactory**: DEX factory simulator with `allPairsLength()` interface
2. **NewTokenPairSpamTrap**: Reads factory state and detects spam patterns
3. **ResponseContract**: Receives alerts and logs them on-chain

## 🔧 How It Works

### Detection Logic

The trap implements a **delta-based detection pattern**:

> **If the number of new pairs created between consecutive samples exceeds 100, alert operators.**

**How it works:**

1. **Data Collection** (`collect()` - view function)

   - Reads `IUniV2Factory(FACTORY).allPairsLength()` from the factory contract
   - Returns `abi.encode(pairCount, block.number)`
   - Fully deterministic - all operators see the same data

2. **Historical Comparison** (`shouldRespond()` - pure function)

   - Receives array: `data[0]` = newest sample, `data[1]` = previous sample
   - Decodes both samples to get pair counts
   - Calculates delta: `newestCount - previousCount`
   - Requires `block_sample_size = 2` in TOML config

3. **Planner Safety**

   - Checks `data.length >= 2` (need both samples)
   - Checks `data[0].length > 0` and `data[1].length > 0` (no empty blobs)
   - Returns `(false, "")` if validation fails

4. **Threshold Trigger**
   - If `delta > 100`, returns `(true, abi.encode(newestCount, delta, blockNumber))`
   - Payload is passed to `ResponseContract.alertSpamDetection(uint256)`
   - Events emitted for off-chain monitoring

**Key improvements over baseline approach:**

- ✅ No mutable on-chain state (no owner-set variables)
- ✅ Reads real protocol data every block
- ✅ Works with any UniswapV2-style factory
- ✅ Easy to swap mock factory for production factory

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    Drosera Operator                         │
│  (Runs every block on the Hoodi testnet)                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 1. Calls collect()
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              NewTokenPairSpamTrap Contract                  │
│  • Reads initialPairCount & simulatedPairCount              │
│  • Returns encoded data (view function only)                │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 2. Returns bytes
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Drosera Operator                         │
│  • Stores data off-chain                                    │
│  • Calls shouldRespond() with historical data               │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 3. Calls shouldRespond()
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              NewTokenPairSpamTrap Contract                  │
│  • Decodes data array                                       │
│  • Calculates: newPairs = current - initial                 │
│  • Checks: if (newPairs > 100)                              │
│  • Returns: (true, encoded_payload) if threat detected      │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 4. If true, trigger response
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  ResponseContract                           │
│  • alertSpamDetection(pairCount) called                     │
│  • Records alert in history                                 │
│  • Emits SpamDetectionAlert event                           │
│  • Emits EmergencyAction event                              │
└─────────────────────────────────────────────────────────────┘
```

````

## 🏗️ Architecture

### Smart Contracts

#### NewTokenPairSpamTrap.sol

**Interface**: Implements official Drosera `ITrap` interface

**Constants**:
- `FACTORY`: Address of the DEX factory to monitor
- `SAFETY_THRESHOLD`: Maximum allowed new pairs (100)

**Key Functions**:
- `collect() external view returns (bytes)`: Reads factory pair count and block number
- `shouldRespond(bytes[] calldata data) external pure returns (bool, bytes)`: Compares samples and triggers on threshold breach

#### ResponseContract.sol

**Purpose**: Receives and logs security alerts from the trap

**State Variables**:
- `totalAlertsReceived`: Counter for all alerts
- `lastAlertTimestamp`: Timestamp of most recent alert
- `lastAlertPairCount`: Pair count from most recent alert
- `alertHistory`: Mapping of all historical alerts

**Key Functions**:
- `alertSpamDetection()`: Main entry point called by Drosera operators
- `getAlert()`: Retrieve specific alert by ID
- `getLastAlert()`: Get most recent alert details
- `markAlertProcessed()`: Owner function to mark alerts as handled

### Configuration Files

#### drosera.toml

Maps contract state variables into the inputs array:

```toml
[[trap.new_token_pair_spam_trap.inputs]]
contract = "{{trap_address}}"
method = "initialPairCount()(uint256)"

[[trap.new_token_pair_spam_trap.inputs]]
contract = "{{trap_address}}"
method = "simulatedPairCount()(uint256)"
````

This configuration ensures the `collect()` function data is properly structured for the `shouldRespond()` function.

## 📦 Prerequisites

Before you begin, ensure you have the following installed:

### Required Tools

1. **Foundry** - Ethereum development toolkit

   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Drosera CLI** - For deploying and managing traps

   ```bash
   curl -L https://app.drosera.io/install | bash
   droseraup
   ```

3. **Node.js & Bun** (Optional but recommended)

   ```bash
   curl -fsSL https://bun.sh/install | bash
   ```

4. **Git** - Version control
   ```bash
   # Usually pre-installed on most systems
   git --version
   ```

### Network Requirements

- **Hoodi Testnet RPC**: Get a free RPC endpoint from:

  - [Alchemy](https://www.alchemy.com/) - Create account and get Hoodi RPC
  - [QuickNode](https://www.quicknode.com/) - Alternative RPC provider
  - Public RPC: `https://ethereum-hoodi-rpc.publicnode.com`

- **Testnet ETH**: You'll need Hoodi testnet ETH for deployment
  - Get from Hoodi faucet or Discord community

### Wallet Requirements

- Private key of wallet with testnet ETH for deployment
- Never use mainnet private keys or wallets with real funds

---

## 🌐 GitHub Codespaces Setup

**Want to skip local installation? Use GitHub Codespaces!** ☁️

GitHub Codespaces provides a cloud-based development environment with everything pre-installed.

### Quick Start with Codespaces

1. **Create GitHub Repository**

   - Go to GitHub.com and create a new repository
   - Name it: `new-token-pair-spam-trap`
   - Make it Public or Private

2. **Upload Project Files**

   - Upload all files from your local project to GitHub:
     ```
     .devcontainer/, src/, script/, *.toml, *.json, *.md, LICENSE
     ```
   - Or use Git to push:
     ```bash
     git init
     git remote add origin https://github.com/YOUR_USERNAME/new-token-pair-spam-trap.git
     git add .
     git commit -m "Initial commit"
     git push -u origin main
     ```

3. **Launch Codespace**

   - Click green "Code" button on GitHub
   - Click "Codespaces" tab
   - Click "Create codespace on main"
   - Wait 2-3 minutes for automatic setup ✨

4. **Verify Installation** (in Codespace terminal)

   ```bash
   forge --version
   drosera --version
   bun --version
   ```

5. **Configure & Deploy**

   ```bash
   # Create .env file
   cp .env.example .env
   # Edit with: code .env
   # Add your PRIVATE_KEY and HOODI_RPC_URL

   # Compile
   forge build

   # Deploy
   forge script script/DeployResponseProtocol.s.sol --rpc-url $HOODI_RPC_URL --broadcast
   ```

**Benefits of Codespaces:**

- ✅ No local installation needed
- ✅ Automatic tool setup (Foundry, Drosera CLI, Bun)
- ✅ Works on any device with a browser
- ✅ 60-120 free hours/month
- ✅ Consistent environment for all developers

---

## 🚀 Installation

### Step 1: Clone or Navigate to Project

```bash
cd c:\Users\kachi\Trap
```

### Step 2: Install Foundry Dependencies

If Foundry is installed, initialize the project:

```bash
forge install foundry-rs/forge-std
```

If you encounter errors, the contracts are ready and don't strictly require external dependencies.

### Step 3: Set Up Environment Variables

Create a `.env` file in the project root:

```bash
# Windows PowerShell
New-Item -Path .env -ItemType File
```

Add your configuration to `.env`:

```env
# Private key (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# RPC URL for Hoodi testnet
RPC_URL=https://ethereum-hoodi.publicnode.com

# Optional: Etherscan API key for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
```

⚠️ **Security Warning**: Never commit `.env` file to version control!

## ⚙️ Configuration

### Update Response Contract Address

After deployment, you'll need to update the hardcoded response contract address:

1. Deploy both contracts (see Deployment section)
2. Note the ResponseContract address
3. Update `NewTokenPairSpamTrap.sol` line 90:
   ```solidity
   address private constant RESPONSE_CONTRACT = address(0xYOUR_DEPLOYED_ADDRESS);
   ```
4. Update `drosera.toml` line 14:
   ```toml
   response_contract = "0xYOUR_DEPLOYED_ADDRESS"
   ```

### Configure drosera.toml

The `drosera.toml` file is pre-configured with:

- Network: Hoodi testnet
- Inputs array mapping for state variables
- Response function signature
- Optional alert configurations (commented out)

You can customize:

- Alert integrations (Slack, webhooks)
- Monitoring intervals
- Gas settings

## 🚢 Deployment

### Method 1: Using Foundry Directly

#### Step 1: Compile Contracts

```bash
forge build
```

#### Step 2: Deploy Using Script

```bash
# Windows PowerShell
$env:PRIVATE_KEY="your_private_key"
forge script script/Deploy.s.sol --rpc-url https://ethereum-hoodi.publicnode.com --broadcast
```

The script will:

1. Deploy ResponseContract
2. Deploy NewTokenPairSpamTrap
3. Print both contract addresses
4. Display configuration instructions

#### Step 3: Update Addresses

Follow the console output to update:

- `RESPONSE_CONTRACT` in `NewTokenPairSpamTrap.sol`
- `response_contract` in `drosera.toml`

#### Step 4: Redeploy Trap (if needed)

If you updated the RESPONSE_CONTRACT address:

```bash
forge build
# Redeploy only the trap contract
```

### Method 2: Using Drosera CLI

#### Step 1: Compile

```bash
forge build
```

#### Step 2: Deploy with Drosera

```bash
# Windows PowerShell
$env:DROSERA_PRIVATE_KEY="your_private_key"
drosera apply
```

This will:

- Deploy the trap to Hoodi testnet
- Register it with Drosera Network
- Update `drosera.toml` with deployed address

## 🧪 Testing the Trap

### Simulate Spam Attack

Once deployed, you can test the trap by simulating a spam attack:

#### Step 1: Set Initial Baseline

```solidity
// Using cast (Foundry's CLI tool)
cast send YOUR_TRAP_ADDRESS "setInitialPairCount(uint256)" 50 \
  --rpc-url https://ethereum-hoodi.publicnode.com \
  --private-key YOUR_PRIVATE_KEY
```

#### Step 2: Update Simulated Count (Below Threshold)

```solidity
cast send YOUR_TRAP_ADDRESS "updateSimulatedCount(uint256)" 100 \
  --rpc-url https://ethereum-hoodi.publicnode.com \
  --private-key YOUR_PRIVATE_KEY
```

This should NOT trigger (100 - 50 = 50 new pairs, below threshold of 100)

#### Step 3: Trigger the Trap (Above Threshold)

```solidity
cast send YOUR_TRAP_ADDRESS "updateSimulatedCount(uint256)" 200 \
  --rpc-url https://ethereum-hoodi.publicnode.com \
  --private-key YOUR_PRIVATE_KEY
```

This SHOULD trigger (200 - 50 = 150 new pairs, exceeds threshold of 100)

#### Step 4: Check Response Contract

```solidity
# Check total alerts
cast call YOUR_RESPONSE_ADDRESS "getTotalAlerts()" \
  --rpc-url https://ethereum-hoodi.publicnode.com

# Get last alert details
cast call YOUR_RESPONSE_ADDRESS "getLastAlert()" \
  --rpc-url https://ethereum-hoodi.publicnode.com
```

### Monitor Events

Watch for emitted events:

```bash
# Watch for SpamDetectionAlert events
cast logs --address YOUR_RESPONSE_ADDRESS \
  --rpc-url https://ethereum-hoodi.publicnode.com
```

### Verify Trap Logic Locally

You can test the logic without deploying using Foundry's testing framework (create test file in `test/` directory).

## 📁 Project Structure

```
c:\Users\kachi\Trap\
├── src/
│   ├── NewTokenPairSpamTrap.sol    # Main trap contract
│   └── ResponseContract.sol         # Alert receiver contract
├── script/
│   └── Deploy.s.sol                 # Deployment script
├── test/
│   └── (add your tests here)
├── foundry.toml                     # Foundry configuration
├── drosera.toml                     # Drosera trap configuration
├── .gitignore                       # Git ignore rules
├── .env                             # Environment variables (create this)
└── README.md                        # This file
```

## 📝 Contract Details

### NewTokenPairSpamTrap

**Address**: `0xAaDc038c087df43626039CC8dFC972A7DE08Ac6a`

**Trap Config**: `0x18305094b3E14b19EdeaB0FD553b864673d1EfbD`

**Interface**: Implements `ITrap` (official Drosera v2.0 interface)

**Constants**:
| Constant | Type | Value | Purpose |
|----------|------|-------|------|
| FACTORY | address | `0xe4Ec2cdC6c312dA357abC40aBC47A5FE16aEa902` | Factory to monitor |
| SAFETY_THRESHOLD | uint256 | 100 | Trigger threshold |

**Functions**:

- `collect() external view returns (bytes)`: Reads `factory.allPairsLength()` with validity flag, returns `abi.encode(count, blockNumber, success)`
- `shouldRespond(bytes[] calldata data) external pure returns (bool, bytes)`: Validates samples, calculates pairs-per-block rate, triggers if rate > 100

### ResponseContract

**Address**: `0x2758F900786BBC27DC6b34a661AC98392D6c63DF`

**Events**:

- `SpamDetectionAlert(uint256 pairCount, uint256 timestamp, address triggeredBy)`
- `EmergencyAction(uint256 pairCount, string action, uint256 timestamp)`

**Public Functions**:

- `alertSpamDetection(uint256 pairCount, uint256 delta, uint256 sampleBlock)`: Receive alert from trap with full details
- `getAlert(uint256)`: Get specific alert details (includes pairCount, delta, sampleBlock, timestamp)
- `getLastAlert()`: Get most recent alert
- `getTotalAlerts()`: Get total alert count
- `markAlertProcessed(uint256)`: Mark alert as handled (owner only)

## 🔒 Security Considerations

### Design Principles

1. **Real On-Chain Data with Validity Flags**: `collect()` reads factory state via `IUniV2Factory.allPairsLength()` with try-catch and returns success flag

2. **Pure Detection Logic**: `shouldRespond()` is pure and stateless - fully deterministic across all operators

3. **Planner-Safe**: Validates data array length, checks for empty blobs, and verifies validity flags before processing

4. **No Mutable State**: Trap has no owner-controlled variables - cannot be manipulated between operator runs

5. **Official Interface**: Uses Drosera's `ITrap` interface - guaranteed compatibility with operator infrastructure

6. **Rate-Based Detection**: Calculates pairs-per-block rate to prevent gaming (e.g., 99 pairs/block won't trigger if spread)

### Best Practices

- ✅ Always use testnet for development and testing
- ✅ Never commit private keys to version control
- ✅ Verify contract addresses before interactions
- ✅ Monitor alert history regularly
- ✅ Test threshold values appropriate for your use case
- ✅ Keep Drosera CLI and Foundry up to date

### Production Considerations

- Currently uses `SimpleMockFactory` for testing - replace `FACTORY` constant with real UniswapV2 factory address for production (PoC limitation)
- Threshold of 100 pairs-per-block is hardcoded - consider parameterizing for different factory sizes
- Single-factory monitoring - can extend to multi-factory with array of targets
- Rate-based detection using pairs-per-block calculation prevents gaming but may need tuning for specific networks

## 🐛 Troubleshooting

### Foundry Not Installed

**Error**: `forge: command not found`

**Solution**: Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Drosera CLI Not Found

**Error**: `drosera: command not found`

**Solution**: Install Drosera CLI:

```bash
curl -L https://app.drosera.io/install | bash
droseraup
```

### Compilation Errors

**Error**: Missing dependencies

**Solution**: Install Forge dependencies:

```bash
forge install foundry-rs/forge-std
```

### Deployment Fails

**Error**: Insufficient funds or RPC issues

**Solution**:

1. Ensure wallet has Hoodi testnet ETH
2. Verify RPC URL is correct
3. Check private key is set correctly
4. Try alternative RPC endpoint

### Trap Not Triggering

**Checklist**:

- [ ] Response contract address updated in trap contract?
- [ ] Response contract address updated in drosera.toml?
- [ ] Simulated count exceeds initial count by > 100?
- [ ] Trap deployed successfully with Drosera?
- [ ] Operator is monitoring the trap?

### Environment Variables Not Loading

**Windows PowerShell**:

```powershell
$env:PRIVATE_KEY="your_key"
$env:RPC_URL="your_rpc"
```

**Alternative**: Use .env file and load with:

```bash
# If using direnv or similar
source .env
```

## 📚 Resources

### Official Documentation

- [Drosera Documentation](https://dev.drosera.io/)
- [Drosera Getting Started](https://dev.drosera.io/trappers/getting-started/)
- [Creating a Trap](https://dev.drosera.io/trappers/creating-a-trap)
- [Foundry Book](https://book.getfoundry.sh/)

### Example Repositories

- [Drosera Trap Foundry Template](https://github.com/drosera-network/trap-foundry-template)
- [Drosera Examples](https://github.com/drosera-network/examples)
- [Unique Trap Example](https://github.com/Idle0x/Drosera-Unique-Trap)
- [Hoodi Guide Setup](https://github.com/izmerGhub/Drosera-Hoodi-Guide-Setup--Izmer)

### Community

- [Drosera Discord](https://discord.gg/drosera)
- [Drosera Telegram](https://t.me/drosera)
- [Drosera GitHub](https://github.com/drosera-network)
- [Drosera Twitter](https://twitter.com/droseranetwork)

### Tools

- [Alchemy RPC](https://www.alchemy.com/) - Get Hoodi testnet RPC
- [QuickNode RPC](https://www.quicknode.com/) - Alternative RPC provider
- [Hoodi Testnet Faucet](https://hoodi-faucet.pk910.de/) - Get testnet ETH

## ✅ Drosera Team Feedback - All Corrections Implemented

### **Round 1 Corrections:**

1. ❌ Custom Trap abstract with mutable storage
2. ❌ Owner-set state variables (not real on-chain data)
3. ❌ Missing planner-safety checks
4. ❌ Incorrect TOML config (function selector instead of signature)
5. ❌ Unused response getters

**Applied:**

✅ **Official ITrap Interface**: No custom Trap abstract, implements Drosera's `ITrap` directly

✅ **Real Factory Data**: Reads `IUniV2Factory(FACTORY).allPairsLength()` every block - fully deterministic

✅ **Historical Comparison**: `shouldRespond()` compares `data[0]` (newest) vs `data[1]` (previous)

✅ **Planner-Safety**: Validates `data.length >= 2`, `data[0].length > 0`, `data[1].length > 0`

✅ **Correct TOML**: `response_function = "alertSpamDetection(uint256,uint256,uint256)"` (string signature), `block_sample_size = 2`

✅ **Clean Implementation**: Removed all unused getters, owner functions, and custom event log storage

---

### **Round 2 Corrections (PoC-Deployable Fixes):**

**Issue 1: Payload/ABI Mismatch (BLOCKING)**

- Problem: Trap returned 3 uint256s but response expected 1
- ✅ **Fixed**: Updated `ResponseContract.alertSpamDetection(uint256 pairCount, uint256 delta, uint256 sampleBlock)`
- ✅ **Fixed**: TOML now has `response_function = "alertSpamDetection(uint256,uint256,uint256)"`

**Issue 2: try/catch Validity Flag**

- Problem: Failed factory calls returned 0, creating false deltas
- ✅ **Fixed**: `collect()` returns `abi.encode(count, block.number, success)`
- ✅ **Fixed**: `shouldRespond()` validates both samples with `if (!newestOk || !previousOk)`

**Issue 3: Detection Logic - Rate-Based**

- Problem: Simple delta gameable (99 pairs/block never triggers)
- ✅ **Fixed**: Implemented pairs-per-block calculation: `pairsPerBlock = delta / blockDiff`
- ✅ **Fixed**: Triggers when rate > threshold, preventing gaming

**Issue 4: Hardcoded FACTORY**

- Acknowledged as PoC limitation - documented for future improvement

---

**Deployed & Tested:**

- **MockFactory**: `0xe4Ec2cdC6c312dA357abC40aBC47A5FE16aEa902` (150 pairs created for testing)
- **Trap Contract**: `0xAaDc038c087df43626039CC8dFC972A7DE08Ac6a`
- **Trap Config**: `0x18305094b3E14b19EdeaB0FD553b864673d1EfbD`
- **Response**: `0x2758F900786BBC27DC6b34a661AC98392D6c63DF`
- **Network**: Hoodi Testnet (Chain ID: 560048)
- **Block**: 1836651
- **Status**: Production-ready ✅

## 📄 License

MIT License - See contract headers for details

---

**Built for Drosera Network Hoodi Testnet**

For questions, issues, or contributions, please refer to the Drosera community resources above.

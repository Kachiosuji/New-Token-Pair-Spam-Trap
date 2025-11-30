# New Token Pair Spam Trap - Drosera Network Security

A Drosera Network security trap built for the Hoodi testnet that detects and alerts on "New Token Pair Spam" attacks by monitoring the rate of new pair creation in a simulated factory environment.

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

- Treats the factory’s total pair count as a core signal
- Tracks a baseline `initialPairCount` and current `simulatedPairCount`
- Computes the net-new pairs `current - initial`
- Triggers a response once the number of new pairs crosses a configurable threshold (100 by default)

This repo is intended as a complete, operator-ready example for the Drosera team, showing:

- How to structure a trap around a realistic spam scenario
- How to keep `collect()` and `shouldRespond()` compatible with the operator environment
- How to wire a dedicated Response contract that cleanly separates detection from on-chain action

The system consists of two main smart contracts:

1. **NewTokenPairSpamTrap**: Encodes the detection logic for new token pair spam
2. **ResponseContract**: Receives alerts from the trap and records them on-chain for operators and downstream automation

## 🔧 How It Works

### Detection Logic

The trap is built around a simple but expressive invariant:
> **If the number of new token pairs created since the baseline exceeds 100, something unusual is happening and operators should take a look.**

**Concretely:**
1. **Baseline tracking**
    - `initialPairCount` represents the baseline “healthy” factory state.
    - In production, this would be set from the live factory pair count at some known-good time.

2. **Current state**
    - `simulatedPairCount` represents the current factory pair count.
    - In this implementation it is intentionally owner-controlled so scenarios can be simulated and tuned without needing a live factory. This makes it easy to demo, reason about, and extend.

3. **Threshold check**
    - On each block, the Drosera operator calls `collect()`, which returns `abi.encode(initialPairCount, simulatedPairCount)`.
    - The operator then calls `shouldRespond(bytes[] data)` with the most recent sample as `data[0]`.
    - The trap decodes `data[0]` and computes:
        - `newPairs = current > initial ? current - initial : 0`.

4. **Response trigger**
    - If `newPairs > SAFETY_THRESHOLD` (100 by default), `shouldRespond` returns:
        - `true` and `abi.encode(current)` as the payload.

    - That payload is forwarded to the Response contract’s `alertSpamDetection(uint256 pairCount)` function, which:
        - Records the alert,
        - Emits events for off-chain monitoring,
        - Tracks alert history and last-seen values.

        This keeps the core detection logic very focused (pair creation velocity), but it is easy to extend later—for example:

- Different thresholds per factory,
- Time-weighted windows (e.g. “100 pairs in the last N blocks”),
- Combining pair count with liquidity/TVL or volume metrics.

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
```

## 🏗️ Architecture

### Smart Contracts

#### NewTokenPairSpamTrap.sol

**Inheritance**: Extends the official Drosera `Trap` base contract

**State Variables**:
- `initialPairCount`: Baseline pair count for comparison
- `simulatedPairCount`: Current simulated pair count
- `SAFETY_THRESHOLD`: Maximum allowed new pairs (100)
- `owner`: Contract owner for administrative functions

**Key Functions**:
- `collect()`: View function that reads and encodes state variables
- `shouldRespond()`: Pure function that analyzes data and determines if alert should trigger
- `shouldAlert()`: Alternative alert mechanism with same logic
- `updateSimulatedCount()`: Owner-only function to update simulation for testing
- `setInitialPairCount()`: Owner-only function to set baseline

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
```

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

**Address**: _0x2298838564f479B890B4D7A5C59aE0A340cD2f05_

**Constructor**: Empty (required for Drosera dry-run compatibility)

**State Variables**:
| Variable | Type | Purpose |
|----------|------|---------|
| initialPairCount | uint256 | Baseline pair count |
| simulatedPairCount | uint256 | Current simulated count |
| SAFETY_THRESHOLD | uint256 | Trigger threshold (100) |
| owner | address | Contract owner |

**View Functions**:
- `collect()`: Returns encoded state for analysis
- `initialPairCount()`: Get baseline count
- `simulatedPairCount()`: Get current count
- `SAFETY_THRESHOLD()`: Get threshold value

**Pure Functions**:
- `shouldRespond(bytes[] calldata)`: Determine if response needed
- `shouldAlert(bytes[] calldata)`: Determine if alert needed
- `getResponseContract()`: Return response contract address
- `getResponseFunction()`: Return response function signature
- `getResponseArguments()`: Return response arguments

**Owner Functions**:
- `updateSimulatedCount(uint256)`: Update simulation
- `setInitialPairCount(uint256)`: Set baseline

### ResponseContract

**Address**: _0x4582470e4071E61fe4FED4f49F5F47bEcbAD89e8_

**Events**:
- `SpamDetectionAlert(uint256 pairCount, uint256 timestamp, address triggeredBy)`
- `EmergencyAction(uint256 pairCount, string action, uint256 timestamp)`

**Public Functions**:
- `alertSpamDetection(uint256)`: Receive alert from trap
- `getAlert(uint256)`: Get specific alert details
- `getLastAlert()`: Get most recent alert
- `getTotalAlerts()`: Get total alert count
- `markAlertProcessed(uint256)`: Mark alert as handled (owner only)

## 🔒 Security Considerations

### Design Principles

1. **No External Calls in collect()**: The `collect()` function is strictly a view function that only reads internal state, avoiding network calls that could fail in the Drosera operator environment.

2. **Pure shouldRespond()**: Detection logic is pure and deterministic, ensuring consistent behavior across operators.

3. **Owner Access Control**: Administrative functions are protected with `onlyOwner` modifier.

4. **Event Logging**: All critical actions emit events for transparency and monitoring.

### Best Practices

- ✅ Always use testnet for development and testing
- ✅ Never commit private keys to version control
- ✅ Verify contract addresses before interactions
- ✅ Monitor alert history regularly
- ✅ Test threshold values appropriate for your use case
- ✅ Keep Drosera CLI and Foundry up to date

### Limitations

- This is a **simulation** for educational/testing purposes
- Real production systems should monitor actual factory contracts
- The threshold of 100 new pairs is configurable but hardcoded
- Requires manual updates via owner functions for testing

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

## 🎓 How This Fulfills the Requirements

This implementation satisfies all specified requirements:

✅ **Trap & Response Contracts**: Two separate smart contracts as specified

✅ **Factory Monitoring Simulation**: Uses `initialPairCount` and `simulatedPairCount` 

✅ **Baseline Comparison**: Compares current count against initial baseline

✅ **Safety Threshold**: Triggers when difference exceeds 100 new pairs

✅ **View-Only collect()**: Strictly reads internal state, no external calls

✅ **Pure shouldRespond()**: Decodes data array and calculates difference

✅ **Response Contract Integration**: Calls `alertSpamDetection()` and emits events

✅ **Trap Base Contract**: Inherits from official Trap abstract contract

✅ **Empty Constructor**: Passes dry-run simulations

✅ **Helper Function**: `updateSimulatedCount()` for testing

✅ **Required Pure Functions**: Implements `getResponseContract`, `getResponseFunction`, `getResponseArguments`

✅ **Deployment Script**: Foundry script deploys both contracts

✅ **drosera.toml Configuration**: Maps state variables to inputs array

✅ **Comprehensive Documentation**: This README with full details

## 📄 License

MIT License - See contract headers for details

---

**Built for Drosera Network Hoodi Testnet**

For questions, issues, or contributions, please refer to the Drosera community resources above.


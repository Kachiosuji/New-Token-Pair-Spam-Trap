#!/bin/bash

echo "🚀 Setting up Drosera Trap Development Environment..."

# Install Foundry
echo "📦 Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Install Bun
echo "📦 Installing Bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Install Drosera CLI
echo "📦 Installing Drosera CLI..."
curl -L https://app.drosera.io/install | bash
source ~/.bashrc
droseraup

# Install dependencies
echo "📦 Installing project dependencies..."
cd /workspaces/$(basename $PWD)
bun install

echo "✅ Development environment setup complete!"
echo "ℹ️  You can now run 'forge build' to compile contracts"

# GiveProtocol Backend Makefile
# Provides easy deployment and management commands for different networks

# Default values
NETWORK ?= local
PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL ?= http://localhost:8545
VERIFY ?= false

# Network configurations
ifeq ($(NETWORK),sepolia)
	RPC_URL = https://ethereum-sepolia-rpc.publicnode.com
	CHAIN_ID = 11155111
	VERIFY = true
else ifeq ($(NETWORK),scroll-sepolia)
	RPC_URL = https://sepolia-rpc.scroll.io
	CHAIN_ID = 534351
	VERIFY = true
else ifeq ($(NETWORK),mainnet)
	RPC_URL = https://ethereum-rpc.publicnode.com
	CHAIN_ID = 1
	VERIFY = true
else ifeq ($(NETWORK),local)
	RPC_URL = http://localhost:8545
	CHAIN_ID = 31337
	VERIFY = false
endif

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help install build test clean deploy deploy-local deploy-sepolia deploy-scroll-sepolia verify format lint

# Default target
help:
	@echo "$(BLUE)GiveProtocol Backend Makefile$(NC)"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@echo "  $(GREEN)install$(NC)          - Install dependencies (Foundry)"
	@echo "  $(GREEN)build$(NC)            - Build contracts"
	@echo "  $(GREEN)test$(NC)             - Run tests"
	@echo "  $(GREEN)test-fork$(NC)        - Run fork tests"
	@echo "  $(GREEN)clean$(NC)            - Clean build artifacts"
	@echo "  $(GREEN)format$(NC)           - Format code"
	@echo "  $(GREEN)lint$(NC)             - Lint code"
	@echo ""
	@echo "$(YELLOW)Deployment commands:$(NC)"
	@echo "  $(GREEN)deploy-local$(NC)     - Deploy to local Anvil network"
	@echo "  $(GREEN)deploy-sepolia$(NC)   - Deploy to Ethereum Sepolia testnet"
	@echo "  $(GREEN)deploy-scroll$(NC)    - Deploy to Scroll Sepolia testnet"
	@echo "  $(GREEN)deploy$(NC)           - Deploy to specified network (NETWORK=...)"
	@echo ""
	@echo "$(YELLOW)Management commands:$(NC)"
	@echo "  $(GREEN)register-ngo$(NC)     - Register test NGO (local only)"
	@echo "  $(GREEN)update-metadata$(NC)  - Update NGO metadata"
	@echo "  $(GREEN)verify$(NC)           - Verify contracts on Etherscan"
	@echo ""
	@echo "$(YELLOW)Environment variables:$(NC)"
	@echo "  NETWORK              - Target network (local, sepolia, scroll-sepolia, mainnet)"
	@echo "  PRIVATE_KEY          - Deployer private key"
	@echo "  RPC_URL              - RPC endpoint URL"
	@echo "  ETHERSCAN_API_KEY    - Etherscan API key for verification"

# Installation
install:
	@echo "$(YELLOW)Installing Foundry dependencies...$(NC)"
	@forge install
	@echo "$(GREEN)Dependencies installed successfully!$(NC)"

# Build
build:
	@echo "$(YELLOW)Building contracts...$(NC)"
	@forge build
	@echo "$(GREEN)Build completed successfully!$(NC)"

# Test
test:
	@echo "$(YELLOW)Running tests...$(NC)"
	@forge test -vv

test-fork:
	@echo "$(YELLOW)Running fork tests...$(NC)"
	@forge test --match-contract Fork -vv --fork-url $(RPC_URL)

# Clean
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@forge clean
	@echo "$(GREEN)Clean completed!$(NC)"

# Format
format:
	@echo "$(YELLOW)Formatting code...$(NC)"
	@forge fmt
	@echo "$(GREEN)Code formatted!$(NC)"

# Lint
lint:
	@echo "$(YELLOW)Linting code...$(NC)"
	@forge fmt --check

# Generic deploy command
deploy: build
	@echo "$(YELLOW)Deploying to $(NETWORK) network...$(NC)"
	@echo "RPC URL: $(RPC_URL)"
	@echo "Chain ID: $(CHAIN_ID)"
ifeq ($(NETWORK),local)
	@forge script script/DeployLocal.s.sol:DeployLocal --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
else
	@forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify $(if $(filter true,$(VERIFY)),--etherscan-api-key $(ETHERSCAN_API_KEY),)
endif
	@echo "$(GREEN)Deployment completed!$(NC)"

# Local deployment
deploy-local:
	@echo "$(YELLOW)Deploying to local Anvil network...$(NC)"
	@$(MAKE) deploy NETWORK=local

# Sepolia deployment
deploy-sepolia:
	@echo "$(YELLOW)Deploying to Ethereum Sepolia...$(NC)"
	@set -a && [ -f .env ] && . ./.env && set +a; \
	if [ -z "$$ETHERSCAN_API_KEY" ]; then \
		echo "$(RED)Error: ETHERSCAN_API_KEY is required for Sepolia deployment$(NC)"; \
		exit 1; \
	fi; \
	forge script script/Deploy.s.sol:Deploy --rpc-url "$$SEPOLIA_RPC" --account default --broadcast --verify --etherscan-api-key "$$ETHERSCAN_API_KEY"
	@echo "$(GREEN)Deployment completed!$(NC)"

# Scroll Sepolia deployment
deploy-scroll:
	@echo "$(YELLOW)Deploying to Scroll Sepolia...$(NC)"
	@if [ -z "$(SCROLLSCAN_API_KEY)" ]; then \
		echo "$(RED)Error: SCROLLSCAN_API_KEY is required for Scroll deployment$(NC)"; \
		exit 1; \
	fi
	@$(MAKE) deploy NETWORK=scroll-sepolia RPC_URL=https://sepolia-rpc.scroll.io

# Register test NGO (local only)
register-ngo:
	@echo "$(YELLOW)Registering test NGO...$(NC)"
	@forge script script/RegisterTestNGO.s.sol:RegisterTestNGO --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
	@echo "$(GREEN)Test NGO registered!$(NC)"

# Update NGO metadata
update-metadata:
	@echo "$(YELLOW)Updating NGO metadata...$(NC)"
	@forge script script/UpdateNGOMetadata.s.sol:UpdateNGOMetadata --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
	@echo "$(GREEN)Metadata updated!$(NC)"

# Verify contracts
verify:
	@echo "$(YELLOW)Verifying contracts...$(NC)"
	@if [ -z "$(CONTRACT_ADDRESS)" ]; then \
		echo "$(RED)Error: CONTRACT_ADDRESS is required$(NC)"; \
		exit 1; \
	fi
	@forge verify-contract $(CONTRACT_ADDRESS) $(CONTRACT_NAME) --etherscan-api-key $(ETHERSCAN_API_KEY) --rpc-url $(RPC_URL)
	@echo "$(GREEN)Contract verified!$(NC)"

# Start local development environment
dev:
	@echo "$(YELLOW)Starting local development environment...$(NC)"
	@echo "Starting Anvil in background..."
	@anvil --host 0.0.0.0 --port 8545 &
	@sleep 2
	@echo "$(GREEN)Anvil started on http://localhost:8545$(NC)"
	@echo "$(YELLOW)Deploying contracts...$(NC)"
	@$(MAKE) deploy-local
	@echo "$(GREEN)Development environment ready!$(NC)"

# Stop local development environment
stop-dev:
	@echo "$(YELLOW)Stopping local development environment...$(NC)"
	@pkill -f anvil || true
	@echo "$(GREEN)Development environment stopped!$(NC)"

# Full setup for new developers
setup: install build test
	@echo "$(GREEN)Setup completed! Run 'make dev' to start local development.$(NC)"

# Check environment
check-env:
	@echo "$(YELLOW)Environment Check:$(NC)"
	@echo "Network: $(NETWORK)"
	@echo "RPC URL: $(RPC_URL)"
	@echo "Chain ID: $(CHAIN_ID)"
	@echo "Verify: $(VERIFY)"
	@if [ "$(NETWORK)" != "local" ] && [ -z "$(ETHERSCAN_API_KEY)" ]; then \
		echo "$(RED)Warning: ETHERSCAN_API_KEY not set$(NC)"; \
	fi
	@forge --version
	@echo "$(GREEN)Environment check completed!$(NC)"
#!/bin/bash
# Remove set -e to allow script to continue on errors
# We'll handle errors manually

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

BACKEND_DIR="../backend"
ABI_DIR="./src/abis"

echo -e "${BLUE}🔄 Syncing ABIs from backend...${NC}"

# Check if backend directory exists
if [ ! -d "$BACKEND_DIR" ]; then
  echo -e "${RED}❌ Backend directory not found: $BACKEND_DIR${NC}"
  exit 1
fi

# Create ABI directory if it doesn't exist
mkdir -p "$ABI_DIR"

# List of v0.5 contracts to sync
contracts=(
  "ACLManager"
  "GiveProtocolCore"
  "CampaignRegistry"
  "StrategyRegistry"
  "PayoutRouter"
  "CampaignVaultFactory"
  "GiveVault4626"
  "CampaignVault4626"
  "MockYieldAdapter"
)

# Counter for successful syncs
success_count=0
total_count=${#contracts[@]}

# Sync each contract ABI
for contract in "${contracts[@]}"; do
  echo -e "  ${BLUE}📄 Syncing $contract...${NC}"
  
  # Use forge inspect to extract ABI with --json flag
  (cd "$BACKEND_DIR" && forge inspect "$contract" abi --json > "../frontend/$ABI_DIR/$contract.json" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}✅ $contract${NC}"
    ((success_count++))
  else
    echo -e "  ${RED}❌ Failed to sync $contract${NC}"
  fi
done

echo ""
echo -e "${GREEN}✅ ABI Sync Complete: $success_count/$total_count contracts${NC}"

# List synced files
echo ""
echo -e "${BLUE}📂 Synced ABI files:${NC}"
ls -lh "$ABI_DIR"/*.json | awk '{print "  " $9 " (" $5 ")"}'

if [ $success_count -eq $total_count ]; then
  exit 0
else
  echo -e "${RED}⚠️  Some ABIs failed to sync. Check forge build status.${NC}"
  exit 1
fi

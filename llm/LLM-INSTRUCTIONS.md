# LLM-INSTRUCTIONS.md

## Master Instructions for All LLMs

This file contains the master rules that all LLMs must follow when working on this DeFi NGO fundraising platform project.

### Project Overview
**Project Name**: MorphImpact  
**Purpose**: DeFi NGO fundraising platform on Morph Chain that revolutionizes charitable giving  
**Core Concept**: Users stake ETH/USDC on Morph Chain on behalf of verified NGOs, selecting yield contribution rates (50%, 75%, or 100%) and lock periods (6, 12, or 24 months). Users retain their full principal after the period while NGOs receive continuous yield funding.

### Technology Stack
- **Frontend**: NextJS + Vite with full web3 functionality
- **Backend**: Foundry + smart contracts
- **Package Manager**: pnpm (MUST use, no Yarn or npm)
- **Structure**: `frontend/` and `backend/` directories

### LLM Collaboration Rules

#### 1. Change Logging (CRITICAL)
- **ALL changes** must be logged in `llm/LLM-CHANGELOG.md`
- **Format**: `Model_name YYYY-MM-DD HH:MM:SS UTC what has been done`
- **When to log**:
  - Any code changes
  - New features implemented
  - Bug fixes
  - Architecture decisions
  - Configuration updates
  - When instructed to fix something

#### 2. Startup Protocol
Every LLM must:
1. Read `llm/LLM-CHANGELOG.md` to understand what has been changed
2. Read `llm/LLM-INSTRUCTIONS.md` (this file) for master rules
3. Read model-specific instructions file:
   - Claude: `CLAUDE.md`
   - Other models: their respective instruction files in `llm/`

#### 3. File Structure Rules
```
llm/
├── LLM-INSTRUCTIONS.md     # Master rules (this file)
├── LLM-CHANGELOG.md        # All changes log
├── CLAUDE.md              # Claude-specific instructions
├── [model-name].md        # Other model-specific files
```

#### 4. Update Protocol
When rules are updated:
1. **Update master**: Modify `llm/LLM-INSTRUCTIONS.md` for universal rules
2. **Update model-specific**: Update respective model file (CLAUDE.md for Claude)
3. **Log change**: Add entry to `llm/LLM-CHANGELOG.md`
4. **Cross-reference**: Ensure changes in model files align with master rules

#### 5. Development Standards
- **Package Manager**: Use pnpm exclusively
- **Code Style**: Follow established patterns in the codebase
- **Testing**: Write tests for all new functionality
- **Security**: Never commit secrets, API keys, or private keys
- **Documentation**: Update relevant documentation with changes

#### 6. Project Structure
```
├── frontend/              # NextJS + Vite web3 frontend
├── backend/               # Foundry smart contracts
├── llm/                   # LLM collaboration files
├── pnpm-workspace.yaml    # pnpm workspace configuration
└── package.json          # Root package.json
```

### Core Features to Implement
1. **NGO Selection Interface**
2. **Staking Mechanism** (ETH/USDC)
3. **Yield Contribution Options** (50%, 75%, 100%)
4. **Time Period Selection** (6, 12, 24 months)
5. **Principal Return System**
6. **Yield Distribution Logic**
7. **Web3 Integration**

### Communication Protocol
- Use `llm/LLM-CHANGELOG.md` as the single source of truth for changes
- When fixing something instructed by user, log the fix in changelog
- Reference changelog entries when discussing changes
- Always check latest changelog before starting work
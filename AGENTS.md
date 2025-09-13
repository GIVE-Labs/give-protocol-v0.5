# Repository Guidelines

## Project Structure & Module Organization

```
.
├── frontend/          # Next.js application (TypeScript, TailwindCSS)
├── backend/           # Foundry smart contracts (Solidity)
├── docs/              # Project documentation and design notes
├── llm/               # Development notes and AI agent prompts
├── references/        # External resources and research
├── image.png          # Hackathon branding asset
└── README.md          # Quick start and overview
```

## Build, Test, and Development Commands

| Scope     | Command                     | Description                           |
|-----------|-----------------------------|---------------------------------------|
| Frontend  | `cd frontend && pnpm dev`   | Start the development server          |
| Frontend  | `cd frontend && pnpm build` | Build production assets               |
| Frontend  | `cd frontend && pnpm lint`  | Run ESLint checks                     |
| Backend   | `cd backend && forge build` | Compile smart contracts               |
| Backend   | `cd backend && forge test`  | Run Solidity unit tests               |
| Backend   | `cd backend && forge fmt`   | Format contracts (Solidity fmt)       |

## Coding Style & Naming Conventions

- **Indentation**: 2-space for JS/TS/Markdown; use `forge fmt` for Solidity.
- **Linting**: ESLint enforces React/TypeScript patterns in `frontend/`.
- **File Names**: 
  - Frontend components: PascalCase (e.g., `StakeForm.tsx`)
  - Smart contracts: PascalCase ending in `.sol` (e.g., `NGORegistry.sol`)
  - Tests: `.t.sol` suffix for Foundry tests (e.g., `GiveVault4626.t.sol`).
- **Commits**: Follow Conventional Commits (e.g., `feat:`, `fix:`, `chore:`).

## Testing Guidelines

- **Frameworks**: Foundry/Forge for smart contracts.
- **Test location**: `backend/test/*.t.sol`.
- **Running tests**: `cd backend && forge test`.
- **Coverage**: Use `forge coverage` to verify coverage goals.

## Commit & Pull Request Guidelines

- **Commit messages**: Use Conventional Commits (e.g., `feat: add staking modal`).
- **Pull requests**:
  1. Use descriptive title and summary.
  2. Link related issues or tickets.
  3. Include screenshots for UI changes.
  4. Request at least one reviewer before merging.

## Environment & Configuration Tips

- Copy `.env.example` to `.env.local` in `frontend/` and add your Scroll Sepolia RPC and keys (e.g., `SCROLL_SEPOLIA_RPC=https://sepolia-rpc.scroll.io`).
- Ensure Node.js >=18 and Foundry installed (`curl -L https://foundry.paradigm.xyz | bash`).

_This guide helps new contributors get up to speed quickly. Thank you for contributing!_

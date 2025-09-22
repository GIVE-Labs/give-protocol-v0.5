# Repository Guidelines

## Project Structure & Module Organization
- `frontend/` hosts the Next.js app in TypeScript with TailwindCSS; UI components live under `src/components/` and API routes under `src/pages/api/`.
- `backend/` contains Foundry smart contracts plus tests in `test/*.t.sol`; deploy scripts live under `script/`.
- Support material sits in `docs/`, `llm/`, and `references/`; use `image.png` for hackathon branding assets alongside `README.md` for quick starts.

## Build, Test, and Development Commands
- Frontend dev server: `cd frontend && pnpm dev` to iterate on UI with hot reload.
- Frontend production build: `cd frontend && pnpm build` for optimized artifacts; run `pnpm lint` before shipping.
- Backend compilation and tests: `cd backend && forge build` then `forge test` to validate contracts; `forge fmt` keeps Solidity tidy.

## Coding Style & Naming Conventions
- TypeScript/Markdown use 2-space indentation; Tailwind utilities stay inline in JSX.
- Frontend components follow PascalCase names (e.g., `StakeForm.tsx`); Solidity contracts end in `.sol` with PascalCase (e.g., `NGORegistry.sol`).
- Run `pnpm lint` and `forge fmt` prior to pushes to enforce ESLint and Foundry formatting baselines.

## Testing Guidelines
- Smart contract coverage relies on Foundry tests in `backend/test/`; mirror production flows with `.t.sol` files.
- Trigger the suite via `cd backend && forge test`; add scenario-specific assertions and revert checks for new opcodes or modifiers.
- For frontend logic, prefer Storybook-style manual validation or lightweight Jest tests if introduced later.

## Commit & Pull Request Guidelines
- Use Conventional Commits such as `feat: add staking modal` or `fix: patch vault math` for history clarity.
- Pull requests need a descriptive summary, linked issues, and UI screenshots when styling changes occur; request at least one reviewer pre-merge.

## Environment & Configuration Tips
- Duplicate `frontend/.env.example` into `.env.local`, then set `SCROLL_SEPOLIA_RPC` and wallet keys for Scroll Sepolia access.
- Ensure Node.js ≥18 and install Foundry via `curl -L https://foundry.paradigm.xyz | bash`; rerun `foundryup` before contract work to stay current.

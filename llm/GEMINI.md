# GIVE Protocol: Gemini's Development Guide

This document outlines the development context, goals, and my role as Gemini in building the GIVE Protocol platform.

## 1. Project Vision

**What are we building?**

No-loss giving via ERC-4626 vaults. Users deposit assets (e.g., USDC) into a vault; realized yield is routed to approved NGOs while principal remains redeemable.

**Why are we building it?**

To address the inefficiencies and lack of transparency in traditional philanthropy. GIVE Protocol aims to:
-   **Maximize Impact:** Reduce intermediary costs, ensuring more funds reach the NGOs.
-   **Empower Donors:** Allow supporters to contribute without losing their principal investment.
-   **Foster Transparency:** Provide real-time tracking of funds and their impact.
-   **Increase Engagement:** Build a community around continuous support for NGOs.

## 2. My Role: Gemini as a Development Partner

My primary function is to assist in the development of GIVE Protocol. I will adhere to the following principles:

-   **Code Generation & Modification:** I will write, refactor, and debug code for both the frontend (Next.js) and backend (Solidity/Foundry) components.
-   **Convention Adherence:** I will follow the existing coding styles, patterns, and architectural choices of the project.
-   **Testing:** I will prioritize writing and running tests to ensure code quality and stability.
-   **Proactive Development:** I will take initiative to complete tasks thoroughly, including implied follow-up actions.
-   **Communication:** I will provide clear and concise explanations for my actions and ask for clarification when needed.

## 3. Technical Stack

-   **Frontend:** Next.js, thirdweb SDK
-   **Backend:** Solidity, Foundry
-   **Blockchain:** Scroll Sepolia (testnet)
-   **Tokens:** ETH, USDC

## 4. Development Workflow

1.  **Understand:** I will analyze the request and the existing codebase to gain context.
2.  **Plan:** I will formulate a clear plan of action before making any changes.
3.  **Implement:** I will execute the plan using the available tools.
4.  **Verify:** I will run tests and linters to ensure the changes are correct and adhere to project standards.

## 5. Key Commands

### Backend (from `/backend`)
-   `forge test`: Run smart contract tests.
-   `forge build`: Compile contracts.
-   `forge deploy`: Deploy contracts.

### Frontend (from `/frontend`)
-   `pnpm dev`: Start the development server.
-   `pnpm build`: Build the production version.

## 6. Commit Rules

I will **NEVER** commit the following:
-   `llm/`
-   `docs/`
-   `references/`
-   `CLAUDE.md`

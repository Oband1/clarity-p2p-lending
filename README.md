# P2P Lending Platform

A decentralized peer-to-peer lending platform built on the Stacks blockchain. This contract enables:

- Creating loan requests with customizable amounts, interest rates, and terms
- Collateral-backed loans for enhanced security
- Partial loan repayments
- Full loan status tracking with state transitions
- Event emission for important actions
- Loan cancellation for unfunded loans
- Emergency pause functionality
- Configurable loan amount limits

## Security Features

- Contract pause mechanism
- Collateral management
- Loan amount limits
- Input validation
- Role-based access control
- Comprehensive error handling
- Status transition validation

## Contract Functions

- create-loan: Create a new collateralized loan request
- fund-loan: Fund an existing loan request
- repay-loan: Make full or partial loan repayments
- claim-collateral: Claim collateral for defaulted loans
- cancel-loan: Cancel an unfunded loan
- get-loan: View loan details
- get-loan-count: Get total number of loans
- set-contract-state: Enable/disable contract (admin only)

## Configuration

- Minimum loan amount: 1 STX
- Maximum loan amount: 100 STX
- Maximum loan term: 52 weeks
- Grace period: ~1 day (144 blocks)

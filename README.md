# P2P Lending Platform

A decentralized peer-to-peer lending platform built on the Stacks blockchain. This contract enables:

- Creating loan requests with customizable amounts, interest rates, and terms
- Funding existing loan requests
- Loan repayment with interest
- Full loan status tracking
- Loan cancellation for unfunded loans
- Emergency pause functionality
- Configurable loan amount limits

## Security Features

- Contract pause mechanism
- Loan amount limits
- Input validation
- Role-based access control
- Comprehensive error handling

## Contract Functions

- create-loan: Create a new loan request
- fund-loan: Fund an existing loan request
- repay-loan: Repay a funded loan with interest
- cancel-loan: Cancel an unfunded loan
- get-loan: View loan details
- get-loan-count: Get total number of loans
- set-contract-state: Enable/disable contract (admin only)

## Configuration

- Minimum loan amount: 1 STX
- Maximum loan amount: 100 STX
- Maximum loan term: 52 weeks

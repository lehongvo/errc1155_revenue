# ERC-1155 Revenue Share System - Contract Update Documentation

## Contract Update Overview

This document outlines critical updates to the ERC-1155 Revenue Share contract to address double-withdrawal vulnerabilities and implement improved revenue tracking.

## Reason for Update

### Previous Implementation Issue

The original contract had a critical vulnerability allowing multiple withdrawals of the same revenue due to insufficient tracking mechanisms.

#### Example of Previous Vulnerability:

```plaintext
Initial Revenue Deposit: 100 SUI
User A (10% ownership)

Problem Scenario:
1. First Withdrawal
   - Entitled: 10 SUI (10% of 100 SUI)
   - Withdrawn: 10 SUI ✓ (Correct)

2. Second Withdrawal
   - Could withdraw another 10 SUI ⚠️ (Incorrect duplicate withdrawal)
   - Total withdrawn: 20 SUI (Double-claiming error)
```

## Solution Implementation

### 1. Epoch-Based Revenue Tracking

#### New Structure

```rust
struct RevenueEpoch {
    epoch_id: u64,          // Unique epoch identifier
    amount: u64,            // Revenue amount
    total_supply: u64,      // Supply at deposit time
    withdrawn_addresses: VecMap<address, bool>, // Claim tracking
    timestamp: u64          // Creation timestamp
}
```

#### Key Changes

- Each revenue deposit creates new epoch
- Tracks total supply at deposit time
- Maintains withdrawal history per user
- Prevents double-claiming

### 2. Withdrawal System Update

#### New Features

- Per-epoch revenue tracking
- User-specific claim history
- Balance-based share calculation
- Double-withdrawal prevention

### 3. Share Calculation Updates

```rust
// Example calculation
per_epoch_share = (epoch_revenue * user_balance) / total_supply
total_claimable = sum(unclaimed_epoch_shares)
```

### 4. Revenue Tracking System

- Updates user's claimed epochs
- Marks revenue as claimed
- Records withdrawal history
- Maintains state consistency

## Design Decisions

### 1. Epoch Management System

#### Advantages

- Precise revenue allocation
- Historical balance tracking
- Double-claim prevention
- Clear audit trail

#### Challenges

- Increased system complexity
- Additional storage requirements
- Higher computation needs
- State management overhead

### 2. Alternative Approaches Considered

#### UTXO Model

- **Benefits:**

  - Precise tracking
  - Clear transaction history
  - Exact distribution records

- **Limitations:**
  - Complex implementation
  - Higher gas costs
  - Contract modification needs
  - Increased system complexity

#### Staking Model

- **Benefits:**

  - Simplified tracking
  - Reduced complexity
  - Easier management

- **Limitations:**
  - Less precise tracking
  - Limited flexibility
  - Contract compatibility issues

## Technical Implementation

### 1. Revenue Deposit

```rust
public entry fun deposit_revenue(
    collection: &mut Collection,
    token_id: ID,
    payment: &mut Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext
)
```

### 2. Revenue Withdrawal

```rust
public entry fun withdraw_revenue(
    collection: &mut Collection,
    nft: &mut NFT,
    ctx: &mut TxContext
)
```

### 3. Share Calculation

```rust
fun calculate_withdrawal_amounts(
    revenue_epochs: &mut vector<RevenueEpoch>,
    holder_balance: u64,
    last_claimed: u64,
    current_epoch: u64,
    sender: address
): WithdrawalInfo
```

## Security Considerations

### 1. Access Control

- Role-based permissions
- Operation validation
- State protection mechanisms

### 2. State Management

- Atomic operations
- Consistent state updates
- Safe mathematical operations

### 3. Data Validation

- Input verification
- Balance checks
- State consistency validation

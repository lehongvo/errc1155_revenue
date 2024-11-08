# ERC-1155 Implementation Documentation

## Table of Contents

- [Overview](#overview)
- [Technical Architecture](#technical-architecture)
- [Core Components](#core-components)
- [Implementation Details](#implementation-details)
- [Function Analysis](#function-analysis)
- [Testing Framework](#testing-framework)
- [Error Handling](#error-handling)
- [Events System](#events-system)
- [Security Considerations](#security-considerations)
- [Usage Guide](#usage-guide)

## Overview

### Description

A comprehensive ERC-1155 implementation on Sui blockchain that combines:

- Semi-fungible token capabilities
- Built-in revenue sharing system
- Role-based access control
- Automated balance tracking

### Key Features

- Multi-token support in single contract
- Revenue distribution system
- Comprehensive event logging
- Token merging functionality
- Metadata management
- Balance tracking at multiple levels

## Technical Architecture

### Core Dependencies

```rust
use sui::object::{Self, ID, UID};
use sui::tx_context::{Self, TxContext};
use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::transfer;
use sui::event;
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use sui::bag::{Self, Bag};
use sui::vec_map::{Self, VecMap};
use std::vector;
```

### Error Codes

```rust
const ENO_MINT_AUTHORITY: u64 = 1; // Only mint authority can perform this action
const ENO_OPERATOR: u64 = 2;       // Only operators can perform this action
const ETOKEN_NOT_EXIST: u64 = 3;   // Token ID does not exist
const ENO_BALANCE: u64 = 4;        // Insufficient balance for operation
const EINVALID_AMOUNT: u64 = 5;    // Invalid amount specified
```

## Core Components

### 1. Data Structures

#### NFT Structure

```rust
struct NFT has key, store {
    id: UID,
    token_id: ID,
    balance: u64
}
```

**Detailed Analysis:**

- `id`: Unique identifier from Sui
  - Generated using `object::new(ctx)`
  - Used for object management
  - Immutable after creation
- `token_id`: Links to token type
  - References metadata and supply info
  - Used for revenue calculations
  - Immutable after minting
- `balance`: Token quantity
  - Mutable through transfers/merges
  - Used in revenue share calculation
  - Must be positive

#### Collection Structure

```rust
struct Collection has key {
    id: UID,
    mint_authority: address,
    operators: vector<address>,
    token_supplies: VecMap<ID, u64>,
    token_metadata: Bag,
    revenues: VecMap<ID, Balance<SUI>>,
    holder_balances: VecMap<address, VecMap<ID, u64>>
}
```

**Component Analysis:**

1. **Access Control**

   - `mint_authority`: Primary administrator
   - `operators`: Revenue managers
   - Purpose: Multi-level permission system

2. **Token Management**

   - `token_supplies`: Supply tracking
   - `token_metadata`: Metadata storage
   - Purpose: Token information management

3. **Revenue System**
   - `revenues`: Per-token revenue storage
   - `holder_balances`: User balance tracking
   - Purpose: Revenue distribution management

#### TokenMetadata Structure

```rust
struct TokenMetadata has store {
    name: String,
    description: String,
    uri: String
}
```

## Implementation Details

### 1. Initialization Process

```rust
fun init(ctx: &mut TxContext)
```

**Steps:**

1. Creates new Collection object
2. Sets transaction sender as mint authority
3. Initializes empty data structures
4. Shares object for public access

### 2. Access Control System

#### Roles & Permissions

1. **Mint Authority**

   - Mint new tokens
   - Add/remove operators
   - Transfer authority role
   - Full administrative control

2. **Operators**

   - Deposit revenue
   - Cannot mint or manage roles
   - Limited to revenue operations

3. **Token Holders**
   - Transfer tokens
   - Withdraw revenue shares
   - Merge owned tokens

### 3. Revenue Management

#### Revenue Distribution Process

```rust
public entry fun withdraw_revenue(
    collection: &mut Collection,
    nft: &NFT,
    ctx: &mut TxContext
)
```

**Algorithm:**

1. Verify token existence
2. Calculate holder's share:
   ```rust
   share = (total_revenue * holder_balance) / total_supply
   ```
3. Split revenue balance
4. Transfer to holder
5. Emit withdrawal event

#### Revenue Deposit Process

```rust
public entry fun deposit_revenue(
    collection: &mut Collection,
    token_id: ID,
    payment: &mut Coin<SUI>,
    amount: u64,
    ctx: &mut TxContext
)
```

**Steps:**

1. Verify operator status
2. Check token existence
3. Validate payment amount
4. Transfer to revenue pool
5. Emit deposit event

## Testing Framework

### Test Environment

```rust
const ADMIN: address = @0xAA;
const OPERATOR: address = @0xBB;
const USER1: address = @0xCC;
const USER2: address = @0xDD;
```

### Test Categories

#### 1. Initialization Tests

```rust
#[test]
fun test_init_revenue()
```

**Verifies:**

- Collection creation
- Initial operator status
- Basic structure setup

#### 2. Access Control Tests

```rust
#[test]
#[expected_failure(abort_code = 1)]
fun test_add_operator_unauthorized()
```

**Validates:**

- Role permissions
- Authorization checks
- Error handling

#### 3. Token Operation Tests

```rust
#[test]
fun test_mint_erc1155()
```

**Checks:**

- Token minting
- Balance updates
- Metadata storage
- Event emission

#### 4. Transfer Tests

```rust
#[test]
fun test_transfer_erc1155()
```

**Verifies:**

- Balance updates
- NFT creation
- Authorization
- Error conditions

#### 5. Revenue System Tests

```rust
#[test]
fun test_deposit_revenue()
#[test]
fun test_withdraw_revenue()
```

**Validates:**

- Revenue deposits
- Withdrawal calculations
- Balance tracking
- Event emission

### Test Execution Flow

#### Example: Revenue Test

1. Initialize collection
2. Add operator
3. Mint tokens
4. Deposit revenue
5. Process withdrawal
6. Verify balances

## Events System

### 1. TokenMinted

```rust
struct TokenMinted has copy, drop {
    token_id: ID,
    creator: address,
    recipient: address,
    amount: u64
}
```

### 2. RevenueDeposited

```rust
struct RevenueDeposited has copy, drop {
    token_id: ID,
    operator: address,
    amount: u64
}
```

### 3. RevenueWithdrawn

```rust
struct RevenueWithdrawn has copy, drop {
    token_id: ID,
    holder: address,
    amount: u64
}
```

## Security Considerations

### 1. Access Control

- Role-based permissions
- Authority validation
- Operation restrictions

### 2. Input Validation

- Balance checks
- Amount validation
- Token existence verification

### 3. State Management

- Atomic operations
- Balance consistency
- Event tracking

### 4. Error Handling

- Custom error codes
- Comprehensive checks
- Clear error messages

## Usage Guide

### 1. Contract Deployment

```rust
// Initialize collection
init(ctx);
```

### 2. Token Management

```rust
// Mint tokens
mint(collection, "Name", "Description", "URI", 1000, recipient, ctx);

// Transfer tokens
transfer(nft, 500, new_recipient, ctx);
```

### 3. Revenue Operations

```rust
// Deposit revenue
deposit_revenue(collection, token_id, payment, amount, ctx);

// Withdraw revenue
withdraw_revenue(collection, nft, ctx);
```

### 4. Access Control

```rust
// Add operator
add_operator(collection, operator_address, ctx);

// Remove operator
remove_operator(collection, operator_address, ctx);
```

## Future Improvements

1. **Enhanced Features**

   - Batch operations
   - Metadata updates
   - Advanced revenue models

2. **Optimizations**

   - Gas efficiency
   - Storage optimization
   - Batch processing

3. **Additional Functionality**
   - Token burning
   - Approval system
   - Secondary market support

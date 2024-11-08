# ERC-1155 Implementation Documentation

## Overview

This implementation provides an ERC-1155-style NFT system on the Sui blockchain with revenue sharing capabilities. The system allows for semi-fungible tokens where users can own multiple units of the same token type, combining the benefits of fungible tokens (like ERC-20) and non-fungible tokens (like ERC-721).

## Features

- 🔐 Role-based access control
- 💰 Revenue sharing system
- 🔄 Token merging capabilities
- 📊 Balance tracking per holder
- 🏷️ Metadata management
- 📡 Event emission system
- ⚡ Efficient batch operations

## Core Components

### 1. Main Structures

#### NFT

- Represents individual token ownership
- Fields:
- `id: UID`: Unique identifier for the NFT instance
- `token_id: ID`: ID of the token type
- `balance: u64`: Amount of tokens owned
- Capabilities:
- `key`: Can be stored as a top-level object
- `store`: Can be stored inside other objects

#### Collection

- Central management structure for the entire system
- Fields:
- Access Control:
- `id: UID`: Unique identifier for collection
- `mint_authority: address`: Address authorized to mint tokens
- `operators: vector<address>`: List of authorized operators
- Token Management:
- `token_supplies: VecMap<ID, u64>`: Total supply per token type
- `token_metadata: Bag`: Storage for token metadata
- Revenue System:
- `revenues: VecMap<ID, Balance<SUI>>`: Revenue per token type
- `holder_balances: VecMap<address, VecMap<ID, u64>>`: Balance tracking
- Capability:
- `key`: Can be stored as a top-level object

#### TokenMetadata

- Stores token type information
- Fields:
- `name: String`: Token type name
- `description: String`: Token type description
- `uri: String`: URI for additional metadata
- Capability:
- `store`: Can be stored inside other objects

### 2. Events System

#### TokenMinted

```rust
struct TokenMinted has copy, drop {
token_id: ID,
creator: address,
recipient: address,
amount: u64
}
```

- Emitted when new tokens are created
- Tracks creation details and initial distribution

#### RevenueDeposited

```rust
struct RevenueDeposited has copy, drop {
token_id: ID,
operator: address,
amount: u64
}
```

- Emitted when revenue is added to token type
- Monitors revenue inflow and source

#### RevenueWithdrawn

```rust
struct RevenueWithdrawn has copy, drop {
token_id: ID,
holder: address,
amount: u64
}
```

- Emitted when holders claim revenue
- Records distribution of revenue

### 3. Error Constants

```rust
const ENO_MINT_AUTHORITY: u64 = 1 ; // Only mint authority can perform this action
const ENO_OPERATOR: u64 = 2       ;     // Only operators can perform this action
const ETOKEN_NOT_EXIST: u64 = 3   ; // Token ID does not exist
const ENO_BALANCE: u64 = 4        ;      // Insufficient balance for operation
const EINVALID_AMOUNT: u64 = 5    ;  // Invalid amount specified
```

### 4. Key Functions

#### Token Management

##### Initialize Collection

```rust
fun init(ctx: &mut TxContext)
```

- Creates new collection with sender as mint authority
- Initializes empty data structures
- Shares collection object for public access

##### Mint Tokens

```rust
public entry fun mint(
collection: &mut Collection,
name: vector<u8>,
description: vector<u8>,
uri: vector<u8>,
amount: u64,
recipient: address,
ctx: &mut TxContext
)
```

- Creates new token type with metadata
- Mints specified amount to recipient
- Updates supplies and balances
- Access: Mint authority only

##### Transfer Tokens

```rust
public entry fun transfer(
nft: &mut NFT,
amount: u64,
recipient: address,
ctx: &mut TxContext
)
```

- Transfers specified amount to recipient
- Creates new NFT object for recipient
- Updates balances automatically

##### Merge Tokens

```rust
public entry fun merge(nft1: &mut NFT, nft2: NFT)
```

- Combines balances of two NFTs
- Requires same token_id
- Deletes second NFT after merging

#### Revenue System

##### Deposit Revenue

```rust
public entry fun deposit_revenue(
collection: &mut Collection,
token_id: ID,
payment: &mut Coin<SUI>,
amount: u64,
ctx: &mut TxContext
)
```

- Accepts SUI payment for token type
- Updates revenue balance
- Access: Operators only

##### Withdraw Revenue

```rust
public entry fun withdraw_revenue(
collection: &mut Collection,
nft: &NFT,
ctx: &mut TxContext
)
```

- Calculates holder's share based on balance
- Transfers revenue in SUI
- Proportional to token ownership

#### Access Control Functions

##### Operator Management

```rust
public entry fun add_operator(collection: &mut Collection, operator: address, ctx: &mut TxContext)
public entry fun remove_operator(collection: &mut Collection, operator: address, ctx: &mut TxContext)
```

- Manages operator access list
- Access: Mint authority only

##### Authority Transfer

```rust
public entry fun transfer_authority(collection: &mut Collection, new_authority: address, ctx: &mut TxContext)
```

- Transfers mint authority role
- Access: Current mint authority only

#### Utility Functions

```rust
public fun balance(nft: &NFT): u64
public fun token_id(nft: &NFT): ID
public fun token_exists(collection: &Collection, token_id: ID): bool
public fun is_operator(collection: &Collection, addr: address): bool
public fun total_supply(collection: &Collection, token_id: ID): u64
public fun get_metadata(collection: &Collection, token_id: ID): &TokenMetadata
public fun get_revenue_balance(collection: &Collection, token_id: ID): u64
```

## Implementation Details

### Access Control System

1. **Roles**:

- Mint Authority: Full control over minting and operators
- Operators: Can deposit revenue
- Token Holders: Can transfer and withdraw revenue

2. **Role Management**:

- Authority transferable via `transfer_authority`
- Operators managed via add/remove functions
- Role checks via assertions

### Revenue Distribution

1. **Deposit Process**:

- Operators deposit SUI tokens
- Amount tracked per token type
- Events emitted for transparency

2. **Withdrawal Process**:

- Proportional to token ownership
- Formula: `share = (total_revenue * holder_balance) / total_supply`
- Automatic calculation and transfer

### Balance Tracking

1. **Multiple Levels**:

- Individual NFT balances
- Per-holder balances in collection
- Total supplies per token type

2. **Update Mechanisms**:

- Automatic updates on mint
- Transfer adjustments
- Merge consolidation

## Usage Examples

### Basic Token Operations

```rust
// Initialize collection (done once)
init(ctx)                            ;

// Mint new tokens
mint(
collection,
b"Game Item",
b"In-game collectible",
b"https://metadata.uri",
1000,
recipient,
ctx
)                        ;

// Transfer tokens
transfer(nft, 500, new_recipient, ctx) ;

// Merge tokens
merge(nft1, nft2) ;
```

### Revenue Management

```rust
// Deposit revenue
deposit_revenue(collection, token_id, payment, 1000, ctx) ;

// Withdraw revenue share
withdraw_revenue(collection, nft, ctx) ;
```

### Access Control

```rust
// Add operator
add_operator(collection, operator_address, ctx) ;

// Remove operator
remove_operator(collection, operator_address, ctx) ;

// Transfer authority
transfer_authority(collection, new_authority, ctx) ;
```

## Testing

Test mode initialization available via:

```rust
#[test_only]
public fun init_for_testing(ctx: &mut TxContext)
```

## Security Considerations

1. Access control checks on all privileged operations
2. Balance validation before transfers
3. Revenue calculation protection against overflow
4. Event emission for transparency
5. Comprehensive error handling

## Dependencies

- `sui::object`
- `sui::tx_context`
- `std::string`
- `sui::coin`
- `sui::transfer`
- `sui::event`
- `sui::balance`
- `sui::bag`
- `sui::vec_map`
- `std::vector`

// SPDX-License-Identifier: MIT

module erc1155::erc1155 {
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

    /* Error codes for contract operations */
    const ENO_MINT_AUTHORITY: u64 = 1; // Only mint authority can perform this action
    const ENO_OPERATOR: u64 = 2; // Only operators can perform this action
    const ETOKEN_NOT_EXIST: u64 = 3; // Token ID does not exist
    const ENO_BALANCE: u64 = 4; // Insufficient balance for operation
    const EINVALID_AMOUNT: u64 = 5; // Invalid amount specified
    const ENO_NEW_REVENUE: u64 = 6; // No new revenue to withdraw

    /*
    * Main NFT token struct representing ownership of tokens
    * - id: Unique identifier for this NFT instance
    * - token_id: ID of the token type this NFT represents
    * - balance: Amount of tokens owned in this NFT instance
    * - last_withdrawn_revenue: Tracks total revenue at last withdrawal to prevent multiple withdrawals
    */
    struct NFT has key, store {
        id: UID,
        token_id: ID,
        balance: u64,
        last_withdrawn_revenue: u64
    }

    /*
    * Collection struct managing all token types and revenue distribution
    * - mint_authority: Address authorized to mint new tokens
    * - operators: Addresses authorized to deposit revenue
    * - token_supplies: Total supply tracking for each token type
    * - token_metadata: Storage for token type metadata
    * - revenues: Revenue balance tracking for each token type
    * - holder_balances: Balance tracking for all token holders
    */
    struct Collection has key {
        id: UID,
        // Access control
        mint_authority: address,
        operators: vector<address>,
        // Token data
        token_supplies: VecMap<ID, u64>,
        token_metadata: Bag,
        // Revenue tracking
        revenues: VecMap<ID, Balance<SUI>>,
        holder_balances: VecMap<address, VecMap<ID, u64>>
    }

    /*
    * Metadata struct storing token type information
    * - name: Token type name
    * - description: Token type description
    * - uri: URI pointing to additional metadata
    */
    struct TokenMetadata has store {
        name: String,
        description: String,
        uri: String
    }

    /* Events */
    /*
    * Emitted when new tokens are minted
    * - token_id: ID of the token type minted
    * - creator: Address that minted the tokens
    * - recipient: Address receiving the tokens
    * - amount: Number of tokens minted
    */
    struct TokenMinted has copy, drop {
        token_id: ID,
        creator: address,
        recipient: address,
        amount: u64
    }

    /*
    * Emitted when revenue is deposited
    * - token_id: Token type receiving revenue
    * - operator: Address depositing revenue
    * - amount: Amount deposited
    */
    struct RevenueDeposited has copy, drop {
        token_id: ID,
        operator: address,
        amount: u64
    }

    /*
    * Emitted when revenue is withdrawn
    * - token_id: Token type withdrawn from
    * - holder: Address withdrawing revenue
    * - amount: Amount withdrawn
    */
    struct RevenueWithdrawn has copy, drop {
        token_id: ID,
        holder: address,
        amount: u64
    }

    /*
    * Initializes a new collection
    * Creates a shared collection object with sender as mint authority
    * @param ctx Transaction context
    * Note: This function is only called once during contract deployment
    * Note: The mint authority is set to the sender of the transaction
    * Note: The collection object is shared to allow access from other modules
    */
    fun init(ctx: &mut TxContext) {
        let collection = Collection {
            id: object::new(ctx),
            mint_authority: tx_context::sender(ctx),
            operators: vector::empty(),
            token_supplies: vec_map::empty(),
            token_metadata: bag::new(ctx),
            revenues: vec_map::empty(),
            holder_balances: vec_map::empty()
        };
        transfer::share_object(collection);
    }

    /*
    * Adds a new operator address
    * Requirements:
    * @Param collection The NFT collection
    * @Param operator The address to add as an operator
    * @Param ctx Transaction context
    */
    public entry fun add_operator(
        collection: &mut Collection,
        operator: address,
        ctx: &mut TxContext
    ) {
        assert!(
            collection.mint_authority == tx_context::sender(ctx),
            ENO_MINT_AUTHORITY
        );
        if (!vector::contains(&collection.operators, &operator)) {
            vector::push_back(&mut collection.operators, operator);
        }
    }

    /*
    * Removes an operator address
    * Requirements:
    * @Param collection The NFT collection
    * @Param operator The address to remove
    * @Param ctx Transaction context
    */
    public entry fun remove_operator(
        collection: &mut Collection,
        operator: address,
        ctx: &mut TxContext
    ) {
        assert!(
            collection.mint_authority == tx_context::sender(ctx),
            ENO_MINT_AUTHORITY
        );
        let (exists, index) = vector::index_of(&collection.operators, &operator);
        if (exists) {
            vector::remove(&mut collection.operators, index);
        };
    }

    /*
    * Transfers mint authority to a new address
    * Requirements:
    * @Param collection The NFT collection
    * @Param new_authority The address to transfer mint authority to
    * @Param ctx Transaction context
    */
    public entry fun transfer_authority(
        collection: &mut Collection,
        new_authority: address,
        ctx: &mut TxContext
    ) {
        assert!(
            collection.mint_authority == tx_context::sender(ctx),
            ENO_MINT_AUTHORITY
        );
        collection.mint_authority = new_authority;
    }

    /*
    * Mints new tokens
    * Requirements:
    * @Param collection The NFT collection
    * @Param name The name of the token
    * @Param description The description of the token
    * @Param uri The URI for the token metadata
    * @Param amount The number of tokens to mint
    * @Param recipient The address to mint tokens for
    * @Param ctx Transaction context
    * Effects:
    * Emits a TokenMinted event
    */
    public entry fun mint(
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        uri: vector<u8>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Only mint authority can mint
        assert!(
            collection.mint_authority == tx_context::sender(ctx),
            ENO_MINT_AUTHORITY
        );

        // Create token ID and metadata
        let token_id = object::new(ctx);
        let metadata = TokenMetadata {
            name: string::utf8(name),
            description: string::utf8(description),
            uri: string::utf8(uri)
        };

        // Store token data
        bag::add(
            &mut collection.token_metadata,
            object::uid_to_inner(&token_id),
            metadata
        );
        vec_map::insert(
            &mut collection.token_supplies,
            object::uid_to_inner(&token_id),
            amount
        );
        vec_map::insert(
            &mut collection.revenues,
            object::uid_to_inner(&token_id),
            balance::zero()
        );

        // Create NFT and setup last_withdrawn_revenuefor recipient with initial withdrawn revenue of 0
        let nft = NFT {
            id: object::new(ctx),
            token_id: object::uid_to_inner(&token_id),
            balance: amount,
            last_withdrawn_revenue: 0
        };

        // Update holder balance
        update_holder_balance(
            collection,
            recipient,
            object::uid_to_inner(&token_id),
            amount
        );

        // Emit event
        event::emit(
            TokenMinted {
                token_id: object::uid_to_inner(&token_id),
                creator: tx_context::sender(ctx),
                recipient,
                amount
            }
        );

        transfer::public_transfer(nft, recipient);
        object::delete(token_id);
    }

    /*
    * Deposits revenue for a token type
    * Requirements:
    * @Param caller must be a registered operator
    * @Param token must exist
    * @Param payment amount must be sufficient
    * @Param ctx Transaction context
    * Effects:
    * Emits a RevenueDeposited event
    */
    public entry fun deposit_revenue(
        collection: &mut Collection,
        token_id: ID,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // Only operators can deposit
        assert!(
            vector::contains(&collection.operators, &sender),
            ENO_OPERATOR
        );
        assert!(
            vec_map::contains(&collection.revenues, &token_id),
            ETOKEN_NOT_EXIST
        );
        assert!(
            coin::value(payment) >= amount,
            EINVALID_AMOUNT
        );

        // Transfer payment to revenue
        let revenue = vec_map::get_mut(&mut collection.revenues, &token_id);
        let paid = coin::split(payment, amount, ctx);
        balance::join(revenue, coin::into_balance(paid));

        // Emit event
        event::emit(
            RevenueDeposited {
                token_id,
                operator: sender,
                amount
            }
        );
    }

    /*
    * Withdraws revenue share for token holder
    * Requirements:
    * @Param collection The NFT collection
    * @Param nft The NFT to withdraw revenue from
    * @Param ctx Transaction context
    * Actions:
    * - Verifies token exists
    * - Calculates only new revenue since last withdrawal
    * - Updates last_withdrawn_revenue to prevent multiple withdrawals
    * Effects:
    * - Emits a RevenueWithdrawn event
    */
    public entry fun withdraw_revenue(
        collection: &mut Collection,
        nft: &mut NFT,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let token_id = nft.token_id;

        // Verify token exists
        assert!(
            vec_map::contains(&collection.revenues, &token_id),
            ETOKEN_NOT_EXIST
        );

        // Get current total revenue for token and holder 
        let revenue = vec_map::get_mut(&mut collection.revenues, &token_id);
        let total_revenue = balance::value(revenue);
        
        // Calculate new revenue since last withdrawal
        let new_revenue = total_revenue - nft.last_withdrawn_revenue;
        assert!(new_revenue > 0, ENO_NEW_REVENUE);

        // Calculate share of new revenue only
        let total_supply = *vec_map::get(&collection.token_supplies, &token_id);
        let share = (new_revenue * nft.balance) / total_supply;

        // Update last withdrawn amount before transfer to prevent reentrancy
        nft.last_withdrawn_revenue = total_revenue;

        // Transfer revenue share
        let revenue_share = coin::from_balance(balance::split(revenue, share), ctx);
        transfer::public_transfer(revenue_share, sender);

        // Emit event
        event::emit(
            RevenueWithdrawn {
                token_id,
                holder: sender,
                amount: share
            }
        );
    }

    /*
    * Transfers tokens to another address
    * Requirements:
    * @Param nft The NFT to transfer
    * @Param amount The amount of tokens to transfer
    * @Param recipient The address to transfer tokens to
    * @Param ctx Transaction context
    */
    public entry fun transfer(
        nft: &mut NFT,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(nft.balance >= amount, ENO_BALANCE);

        // Create new NFT for recipient with same withdrawal tracking
        let new_nft = NFT {
            id: object::new(ctx),
            token_id: nft.token_id,
            balance: amount,
            last_withdrawn_revenue: nft.last_withdrawn_revenue // Copy withdrawal state
        };

        // Update balances
        nft.balance = nft.balance - amount;

        transfer::public_transfer(new_nft, recipient);
    }

    /*
    * Merges two NFTs with the same token_id
    * Requirements:
    * @Param nft1 The NFT to merge into
    * @Param nft2 The NFT to merge from
    * - Both NFTs must have the same token_id
    * Effects:
    * - Takes maximum last_withdrawn_revenue to be conservative
    */
    public entry fun merge(nft1: &mut NFT, nft2: NFT) {
        assert!(
            nft1.token_id == nft2.token_id,
            ETOKEN_NOT_EXIST
        );
        
        // When merging, take the maximum last_withdrawn_revenue to be conservative
        nft1.last_withdrawn_revenue = if (nft1.last_withdrawn_revenue > nft2.last_withdrawn_revenue) 
            nft1.last_withdrawn_revenue 
        else 
            nft2.last_withdrawn_revenue;
            
        let NFT {id, token_id: _, balance, last_withdrawn_revenue: _} = nft2;
        nft1.balance = nft1.balance + balance;
        object::delete(id);
    }

    /*
    * Updates holder balance tracking
    * Internal helper function to maintain accurate balance records
    * @param collection The NFT collection
    * @param holder The address of the token holder
    * @param token_id The token ID to update balance for
    * @param amount The amount to update balance by
    */
    fun update_holder_balance(
        collection: &mut Collection,
        holder: address,
        token_id: ID,
        amount: u64
    ) {
        if (!vec_map::contains(&collection.holder_balances, &holder)) {
            vec_map::insert(
                &mut collection.holder_balances,
                holder,
                vec_map::empty()
            );
        };
        let balances = vec_map::get_mut(
            &mut collection.holder_balances,
            &holder
        );
        if (!vec_map::contains(balances, &token_id)) {
            vec_map::insert(balances, token_id, amount);
        } else {
            let balance = vec_map::get_mut(balances, &token_id);
            *balance = *balance + amount;
        }
    }

    /*
    * @dev Returns the token balance of a given NFT
    * @param nft The NFT to check balance for
    * @return The balance amount of the NFT
    */
    public fun balance(nft: &NFT): u64 {
        nft.balance
    }

    /*
    * @dev Returns the token ID associated with a given NFT
    * @param nft The NFT to get token ID for  
    * @return The token ID of the NFT
    */
    public fun token_id(nft: &NFT): ID {
        nft.token_id
    }

    /*
    * @dev Checks if a token exists in the collection
    * @param collection The NFT collection  
    * @param token_id The token ID to check
    * @return true if token exists, false otherwise
    */
    public fun token_exists(collection: &Collection, token_id: ID): bool {
        vec_map::contains(&collection.token_supplies, &token_id)
    }

    /*
    * @dev Checks if an address is registered as an operator
    * @param collection The NFT collection
    * @param addr The address to check
    * @return true if address is an operator, false otherwise  
    */
    public fun is_operator(collection: &Collection, addr: address): bool {
        vector::contains(&collection.operators, &addr)
    }

    /*
    * @dev Returns the total supply of a given token
    * @param collection The NFT collection
    * @param token_id The token ID to check supply for
    * @return The total supply of the token
    */
    public fun total_supply(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(&collection.token_supplies, &token_id)
    }

    /*
    * @dev Returns the metadata for a given token
    * @param collection The NFT collection
    * @param token_id The token ID to get metadata for
    * @return Reference to the token's metadata
    */
    public fun get_metadata(collection: &Collection, token_id: ID): &TokenMetadata {
        bag::borrow(&collection.token_metadata, token_id)
    }

    /*
    * @dev Returns the revenue balance for a given token
    * @param collection The NFT collection  
    * @param token_id The token ID to check revenue for
    * @return The revenue balance of the token
    */
    public fun get_revenue_balance(collection: &Collection, token_id: ID): u64 {
        balance::value(vec_map::get(&collection.revenues, &token_id))
    }

    /*
    * @dev Returns the last withdrawn revenue amount for an NFT
    * @param nft The NFT to check
    * @return The last withdrawn revenue amount
    */
    public fun get_last_withdrawn_revenue(nft: &NFT): u64 {
        nft.last_withdrawn_revenue
    }

    /*
    * @dev Initializes collection for testing purposes
    * @param ctx Transaction context
    * Note: This function is only available in test mode
    */
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}
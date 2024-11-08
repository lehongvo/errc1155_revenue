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

    /*
    * Main NFT token struct representing ownership of tokens
    * - id: Unique identifier for this NFT instance
    * - token_id: ID of the token type this NFT represents
    * - balance: Amount of tokens owned in this NFT instance
    */
    struct NFT has key, store {
        id: UID,
        token_id: ID,
        balance: u64
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
    * - Caller must be the mint authority
    * - Operator address must not already be registered
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
    * - Caller must be the mint authority
    * - Operator address must exist
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
    * - Caller must be the current mint authority
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
    * - Caller must be the mint authority
    * - Amount must be greater than 0
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

        // Create NFT for recipient
        let nft = NFT {
            id: object::new(ctx),
            token_id: object::uid_to_inner(&token_id),
            balance: amount
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
    * - Caller must be a registered operator
    * - Token must exist
    * - Payment amount must be sufficient
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
    * - Token must exist
    * - Caller must have sufficient token balance
    * Emits a RevenueWithdrawn event
    */
    public entry fun withdraw_revenue(
        collection: &mut Collection,
        nft: &NFT,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let token_id = nft.token_id;

        // Verify token exists
        assert!(
            vec_map::contains(&collection.revenues, &token_id),
            ETOKEN_NOT_EXIST
        );

        // Calculate share
        let total_supply = *vec_map::get(
            &collection.token_supplies,
            &token_id
        );
        let revenue = vec_map::get_mut(&mut collection.revenues, &token_id);
        let total_revenue = balance::value(revenue);
        let share = (total_revenue * nft.balance) / total_supply;

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
    * - Caller must have sufficient balance
    */
    public entry fun transfer(
        nft: &mut NFT,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(nft.balance >= amount, ENO_BALANCE);

        // Create new NFT for recipient
        let new_nft = NFT {
            id: object::new(ctx),
            token_id: nft.token_id,
            balance: amount
        };

        // Update balances
        nft.balance = nft.balance - amount;

        transfer::public_transfer(new_nft, recipient);
    }

    /*
    * Merges two NFTs with the same token_id
    * Requirements:
    * - Both NFTs must have the same token_id
    */
    public entry fun merge(nft1: &mut NFT, nft2: NFT) {
        assert!(
            nft1.token_id == nft2.token_id,
            ETOKEN_NOT_EXIST
        );
        let NFT {id, token_id: _, balance} = nft2;
        nft1.balance = nft1.balance + balance;
        object::delete(id);
    }

    /*
    * Updates holder balance tracking
    * Internal helper function to maintain accurate balance records
    */
    fun update_holder_balance(
        collection: &mut Collection,
        holder: address,
        token_id: ID,
        amount: u64
    ) {
        if (!vec_map::contains(
                &collection.holder_balances,
                &holder
            )) {
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
        vec_map::contains(
            &collection.token_supplies,
            &token_id
        )
    }

    /*
    * @dev Checks if an address is registered as an operator
    * @param collection The NFT collection
    * @param addr The address to check
    * @return true if address is an operator, false otherwise
    */
    public fun is_operator(
        collection: &Collection,
        addr: address
    ): bool {
        vector::contains(&collection.operators, &addr)
    }

    /*
    * @dev Returns the total supply of a given token
    * @param collection The NFT collection
    * @param token_id The token ID to check supply for
    * @return The total supply of the token
    */
    public fun total_supply(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(
            &collection.token_supplies,
            &token_id
        )
    }

    /*
    * @dev Returns the metadata for a given token
    * @param collection The NFT collection
    * @param token_id The token ID to get metadata for
    * @return Reference to the token's metadata
    */
    public fun get_metadata(collection: &Collection, token_id: ID): &TokenMetadata {
        bag::borrow(
            &collection.token_metadata,
            token_id
        )
    }

    /*
    * @dev Returns the revenue balance for a given token
    * @param collection The NFT collection
    * @param token_id The token ID to check revenue for
    * @return The revenue balance of the token
    */
    public fun get_revenue_balance(collection: &Collection, token_id: ID): u64 {
        balance::value(
            vec_map::get(&collection.revenues, &token_id)
        )
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

// SPDX-License-Identifier: MIT
module erc1155::erc1155 {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::bag::{Self, Bag};
    use sui::vec_map::{Self, VecMap};

    /* Error codes for contract operations */
    const ENO_MINT_AUTHORITY: u64 = 1; // Mint authority required for operation
    const ENO_OPERATOR: u64 = 2; // Operator required for operation
    const ETOKEN_NOT_EXIST: u64 = 3; // Token does not exist
    const ENO_BALANCE: u64 = 4; // Insufficient balance
    const EINVALID_AMOUNT: u64 = 5; // Invalid amount
    const ENO_NEW_REVENUE: u64 = 6; // No new revenue to withdraw

    /*
    * Revenue epoch struct tracking each deposit event
    * amount: Amount deposited
    * withdrawn_addresses: Addresses that have withdrawn revenue
    */
    public struct RevenueEpoch has store {
        amount: u64,
        withdrawn_addresses: VecMap<address, bool>
    }

    /*
    * Main NFT token struct representing ownership of tokens
    * id: Unique identifier
    * token_id: Token type identifier
    * balance: Token balance
    * epochs_withdrawn: Vector tracking withdrawn epochs
    */
    public struct NFT has key, store {
        id: UID,
        token_id: ID,
        balance: u64,
        epochs_withdrawn: vector<u64> // Track withdrawn epochs
    }

    /*
    * Collection struct managing all token types and revenue distribution
    * id: Unique identifier
    * mint_authority: Address with minting authority
    * operators: Vector of operator addresses
    * token_supplies: Map of token type to total supply
    */
    public struct Collection has key {
        id: UID,
        mint_authority: address,
        operators: vector<address>,
        token_supplies: VecMap<ID, u64>,
        token_metadata: Bag,
        revenues: VecMap<ID, Balance<SUI>>,
        holder_balances: VecMap<address, VecMap<ID, u64>>,
        revenue_epochs: VecMap<ID, vector<RevenueEpoch>>
    }

    /*
    * Metadata struct storing token type information
    * name: Token name
    * description: Token description
    * uri: Token URI
    */
    public struct TokenMetadata has store {
        name: String,
        description: String,
        uri: String
    }

    /*
    * TokenMinted: Emitted when a new token is minted
    * token_id: Token type identifier
    * creator: Creator address
    * recipient: Recipient address
    * amount: Amount minted
    */
    public struct TokenMinted has copy, drop {
        token_id: ID,
        creator: address,
        recipient: address,
        amount: u64
    }

    /*
    * RevenueDeposited: Emitted when revenue is deposited
    * token_id: Token type identifier
    * operator: Operator address
    * amount: Amount deposited
    */
    public struct RevenueDeposited has copy, drop {
        token_id: ID,
        operator: address,
        amount: u64
    }

    /*
    * RevenueWithdrawn: Emitted when revenue is withdrawn
    * token_id: Token type identifier
    * holder: Holder address
    * amount: Amount withdrawn
    * epochs: Vector of withdrawn epochs
    */
    public struct RevenueWithdrawn has copy, drop {
        token_id: ID,
        holder: address,
        amount: u64,
        epochs: vector<u64>
    }

    /*
    * TokenTransferred: Emitted when tokens are transferred
    * token_id: Token type identifier
    * from: Sender address
    * to: Recipient address
    * amount: Amount transferred
    */
    public struct TokenTransferred has copy, drop {
        token_id: ID,
        from: address,
        to: address,
        amount: u64
    }

    /*
    * TokensMerged: Emitted when tokens are merged
    * token_id: Token type identifier
    * holder: Holder address
    * total_balance: Total balance after merge
    */
    public struct TokensMerged has copy, drop {
        token_id: ID,
        holder: address,
        total_balance: u64
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
            holder_balances: vec_map::empty(),
            revenue_epochs: vec_map::empty()
        };
        transfer::share_object(collection);
    }

    /*
    * Adds a new operator address
    * @param collection Collection object
    * @param operator Operator address
    * @param ctx Transaction context
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
    * @param collection Collection object
    * @param operator Operator address
    * @param ctx Transaction context
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
    * @param collection Collection object
    * @param new_authority New mint authority address
    * @param ctx Transaction context
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
    * Mints new tokens and transfers to recipient
    * @param collection Collection object
    * @param name Token name
    * @param description Token description
    * @param uri Token URI
    * @param amount Amount to mint
    * @param recipient Recipient address
    * @param ctx Transaction context
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
        assert!(
            collection.mint_authority == tx_context::sender(ctx),
            ENO_MINT_AUTHORITY
        );

        let token_id = object::new(ctx);
        let metadata = TokenMetadata {
            name: string::utf8(name),
            description: string::utf8(description),
            uri: string::utf8(uri)
        };

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
        vec_map::insert(
            &mut collection.revenue_epochs,
            object::uid_to_inner(&token_id),
            vector::empty()
        );

        let nft = NFT {
            id: object::new(ctx),
            token_id: object::uid_to_inner(&token_id),
            balance: amount,
            epochs_withdrawn: vector::empty()
        };

        update_holder_balance(
            collection,
            recipient,
            object::uid_to_inner(&token_id),
            amount
        );

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
    * Deposits revenue for a token type into the collection
    * @param collection Collection object
    * @param token_id Token type identifier
    * @param payment Payment coin
    * @param amount Amount to deposit
    * @param ctx Transaction context
    */
    public entry fun deposit_revenue(
        collection: &mut Collection,
        token_id: ID,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

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

        let revenue = vec_map::get_mut(&mut collection.revenues, &token_id);
        let paid = coin::split(payment, amount, ctx);
        balance::join(revenue, coin::into_balance(paid));

        let epoch = RevenueEpoch {
            amount,
            withdrawn_addresses: vec_map::empty()
        };
        let revenue_epochs = vec_map::get_mut(
            &mut collection.revenue_epochs,
            &token_id
        );
        revenue_epochs.push_back(epoch);

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
    * @param collection Collection object
    * @param nft NFT object
    * @param ctx Transaction context
    */
    public entry fun withdraw_revenue(
        collection: &mut Collection,
        nft: &mut NFT,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let token_id = nft.token_id;

        assert!(
            vec_map::contains(&collection.revenues, &token_id),
            ETOKEN_NOT_EXIST
        );

        let revenue_epochs = vec_map::get_mut(
            &mut collection.revenue_epochs,
            &token_id
        );
        let mut total_revenue: u64 = 0;
        let mut withdrawn_epochs = vector::empty();
        let revenue_epochs_len = vector::length(revenue_epochs);

        let mut i = 0;
        while (i < revenue_epochs_len) {
            if (!vector::contains(&nft.epochs_withdrawn, &i)) {
                let epoch = vector::borrow(revenue_epochs, i);
                total_revenue = total_revenue + epoch.amount;
                vector::push_back(&mut withdrawn_epochs, i);
            };
            i = i + 1;
        };

        assert!(total_revenue > 0, ENO_NEW_REVENUE);

        let total_supply = *vec_map::get(
            &collection.token_supplies,
            &token_id
        );
        let share = (total_revenue * nft.balance) / total_supply;

        // Transfer revenue share
        let revenue_share = coin::from_balance(
            balance::split(
                vec_map::get_mut(&mut collection.revenues, &token_id),
                share
            ),
            ctx
        );
        transfer::public_transfer(revenue_share, sender);

        // Update withdrawn epochs
        let mut j = 0;
        while (
            j < vector::length(&withdrawn_epochs)
        ) {
            let epoch_index = *vector::borrow(&withdrawn_epochs, j);
            let epoch = vector::borrow_mut(revenue_epochs, epoch_index);
            vec_map::insert(
                &mut epoch.withdrawn_addresses,
                sender,
                true
            );
            vector::push_back(
                &mut nft.epochs_withdrawn,
                epoch_index
            );
            j = j + 1;
        };

        event::emit(
            RevenueWithdrawn {
                token_id,
                holder: sender,
                amount: share,
                epochs: withdrawn_epochs
            }
        );
    }

    /*
    * Updates holder balance tracking for a given token
    * @param collection Collection object
    * @param holder Holder address
    * @param token_id Token type identifier
    * @param amount Amount to update
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
    * Transfers tokens to another address
    * @param collection Collection object
    * @param nft NFT object
    * @param amount Amount to transfer
    * @param recipient Recipient address
    * @param ctx Transaction context
    */
    public entry fun transfer(
        collection: &mut Collection,
        nft: &mut NFT,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(nft.balance >= amount, ENO_BALANCE);

        let new_nft = NFT {
            id: object::new(ctx),
            token_id: nft.token_id,
            balance: amount,
            epochs_withdrawn: vector::empty()
        };

        nft.balance = nft.balance - amount;

        if (!vec_map::contains(
                &collection.holder_balances,
                &sender
            )) {
            vec_map::insert(
                &mut collection.holder_balances,
                sender,
                vec_map::empty()
            );
        };
        let sender_balances = vec_map::get_mut(
            &mut collection.holder_balances,
            &sender
        );
        if (!vec_map::contains(sender_balances, &nft.token_id)) {
            vec_map::insert(sender_balances, nft.token_id, 0);
        } else {
            let balance = vec_map::get_mut(sender_balances, &nft.token_id);
            *balance = *balance - amount;
        };

        update_holder_balance(
            collection,
            recipient,
            nft.token_id,
            amount
        );

        event::emit(
            TokenTransferred {
                token_id: nft.token_id,
                from: sender,
                to: recipient,
                amount
            }
        );

        transfer::public_transfer(new_nft, recipient);
    }

    /*
    * Merges two NFTs with the same token_id
    * @param nft1 First NFT object
    * @param nft2 Second NFT object
    */
    public entry fun merge(
        nft1: &mut NFT,
        nft2: NFT,
        ctx: &mut TxContext
    ) {
        assert!(
            nft1.token_id == nft2.token_id,
            ETOKEN_NOT_EXIST
        );

        // Merge epochs_withdrawn without duplicates
        let mut i = 0;
        let len = vector::length(&nft2.epochs_withdrawn);
        while (i < len) {
            let epoch = *vector::borrow(&nft2.epochs_withdrawn, i);
            if (!vector::contains(&nft1.epochs_withdrawn, &epoch)) {
                vector::push_back(&mut nft1.epochs_withdrawn, epoch);
            };
            i = i + 1;
        };

        let NFT {
            id,
            token_id: _,
            balance,
            epochs_withdrawn: _
        } = nft2;
        nft1.balance = nft1.balance + balance;

        event::emit(
            TokensMerged {
                token_id: nft1.token_id,
                holder: tx_context::sender(ctx),
                total_balance: nft1.balance
            }
        );

        object::delete(id);
    }

    /*
    * @dev Returns the token balance of a given NFT
    * @param nft NFT object
    */
    public fun balance(nft: &NFT): u64 {
        nft.balance
    }

    /*
    * @dev Returns the token ID associated with a given NFT
    * @param nft NFT object
    */
    public fun token_id(nft: &NFT): ID {
        nft.token_id
    }

    /*
    * @dev Checks if a token exists in the collection
    * @param collection Collection object
    * @param token_id Token type identifier
    */
    public fun token_exists(collection: &Collection, token_id: ID): bool {
        vec_map::contains(
            &collection.token_supplies,
            &token_id
        )
    }

    /*
    * @dev Checks if an address is registered as an operator
    * @param collection Collection object
    * @param addr Operator address
    */
    public fun is_operator(
        collection: &Collection,
        addr: address
    ): bool {
        vector::contains(&collection.operators, &addr)
    }

    /*
    * @dev Returns the total supply of a given token
    * @param collection Collection object
    * @param token_id Token type identifier
    */
    public fun total_supply(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(
            &collection.token_supplies,
            &token_id
        )
    }

    /*
    * @dev Returns the metadata for a given token
    * @param collection Collection object
    * @param token_id Token type identifier
    */
    public fun get_metadata(collection: &Collection, token_id: ID): &TokenMetadata {
        bag::borrow(
            &collection.token_metadata,
            token_id
        )
    }

    /*
    * @dev Returns the revenue balance for a given token
    * @param collection Collection object
    * @param token_id Token type identifier
    */
    public fun get_revenue_balance(collection: &Collection, token_id: ID): u64 {
        balance::value(
            vec_map::get(&collection.revenues, &token_id)
        )
    }

    /*
    * @dev Initializes collection for testing purposes
    * @param ctx Transaction context
    */
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}

// SPDX-License-Identifier: MIT
module erc1155::erc1155 {
    use std::string::{Self, String};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::bag::{Self, Bag};
    use sui::vec_map::{Self, VecMap};

    /* Error codes */
    const ENO_MINT_AUTHORITY: u64 = 1;
    const ENO_OPERATOR: u64 = 2;
    const ETOKEN_NOT_EXIST: u64 = 3;
    const ENO_BALANCE: u64 = 4;
    const EINVALID_AMOUNT: u64 = 5;
    const ENO_NEW_REVENUE: u64 = 6;
    const EINVALID_RECIPIENT: u64 = 7;
    const EZERO_SUPPLY: u64 = 8;
    const EOVERFLOW: u64 = 12;

    /* Structs */
    public struct RevenueEpoch has store {
        epoch_id: u64,
        amount: u64,
        total_supply: u64,
        withdrawn_addresses: VecMap<address, bool>,
        cumulative_amount: u64,
        timestamp: u64
    }

    public struct WithdrawalInfo has drop {
        withdrawable_amount: u64,
        withdrawn_epochs: vector<u64>,
        remaining_unclaimed: u64,
        total_shares: u64
    }

    public struct NFT has key, store {
        id: UID,
        token_id: ID,
        balance: u64,
        claimed_revenue: u64,
        epochs_withdrawn: vector<u64>,
        last_epoch_claimed: u64,
        created_at: u64,
        last_transfer_time: u64
    }

    public struct Collection has key {
        id: UID,
        mint_authority: address,
        operators: vector<address>,
        token_supplies: VecMap<ID, u64>,
        token_metadata: Bag,
        revenues: VecMap<ID, Balance<SUI>>,
        holder_balances: VecMap<address, VecMap<ID, u64>>,
        revenue_epochs: VecMap<ID, vector<RevenueEpoch>>,
        epoch_counter: VecMap<ID, u64>,
        total_revenue: VecMap<ID, u64>,
        created_at: u64
    }

    public struct TokenMetadata has store {
        name: String,
        description: String,
        uri: String,
        created_at: u64,
        properties: Option<VecMap<String, String>>
    }

    /* Events */
    public struct TokenMinted has copy, drop {
        token_id: ID,
        creator: address,
        recipient: address,
        amount: u64,
        metadata: TokenMetadataEvent,
        timestamp: u64
    }

    public struct TokenMetadataEvent has copy, drop {
        name: String,
        description: String,
        uri: String
    }

    public struct RevenueDeposited has copy, drop {
        token_id: ID,
        operator: address,
        amount: u64,
        total_supply: u64,
        epoch_id: u64,
        cumulative_amount: u64,
        timestamp: u64
    }

    public struct RevenueWithdrawn has copy, drop {
        token_id: ID,
        holder: address,
        amount: u64,
        epochs: vector<u64>,
        remaining_balance: u64,
        remaining_unclaimed: u64,
        remaining_claimable: u64,
        total_claimed: u64,
        holder_balance: u64,
        timestamp: u64
    }

    public struct TokenTransferred has copy, drop {
        token_id: ID,
        from: address,
        to: address,
        amount: u64,
        transferred_revenue: u64,
        epoch_context: vector<u64>,
        timestamp: u64
    }

    /* Core functions */
    fun init(ctx: &mut TxContext) {
        let collection = Collection {
            id: object::new(ctx),
            mint_authority: tx_context::sender(ctx),
            operators: vector::empty(),
            token_supplies: vec_map::empty(),
            token_metadata: bag::new(ctx),
            revenues: vec_map::empty(),
            holder_balances: vec_map::empty(),
            revenue_epochs: vec_map::empty(),
            epoch_counter: vec_map::empty(),
            total_revenue: vec_map::empty(),
            created_at: tx_context::epoch(ctx)
        };
        transfer::share_object(collection);
    }

    public entry fun add_operator(
        collection: &mut Collection,
        operator: address,
        ctx: &mut TxContext
    ) {
        assert!(collection.mint_authority == tx_context::sender(ctx), ENO_MINT_AUTHORITY);
        if (!vector::contains(&collection.operators, &operator)) {
            vector::push_back(&mut collection.operators, operator);
        };
    }

    public entry fun remove_operator(
        collection: &mut Collection,
        operator: address,
        ctx: &mut TxContext
    ) {
        assert!(collection.mint_authority == tx_context::sender(ctx), ENO_MINT_AUTHORITY);
        let (exists, index) = vector::index_of(&collection.operators, &operator);
        if (exists) {
            vector::remove(&mut collection.operators, index);
        };
    }

    public entry fun mint(
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        uri: vector<u8>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(collection.mint_authority == tx_context::sender(ctx), ENO_MINT_AUTHORITY);
        assert!(amount > 0, EINVALID_AMOUNT);

        let token_id = object::new(ctx);
        let current_time = tx_context::epoch(ctx);

        let metadata = TokenMetadata {
            name: string::utf8(name),
            description: string::utf8(description),
            uri: string::utf8(uri),
            created_at: current_time,
            properties: option::none()
        };

        bag::add(&mut collection.token_metadata, object::uid_to_inner(&token_id), metadata);
        vec_map::insert(&mut collection.token_supplies, object::uid_to_inner(&token_id), amount);
        vec_map::insert(&mut collection.revenues, object::uid_to_inner(&token_id), balance::zero());
        vec_map::insert(&mut collection.revenue_epochs, object::uid_to_inner(&token_id), vector::empty());
        vec_map::insert(&mut collection.epoch_counter, object::uid_to_inner(&token_id), 0);
        vec_map::insert(&mut collection.total_revenue, object::uid_to_inner(&token_id), 0);

        let nft = NFT {
            id: object::new(ctx),
            token_id: object::uid_to_inner(&token_id),
            balance: amount,
            claimed_revenue: 0,
            epochs_withdrawn: vector::empty(),
            last_epoch_claimed: 0,
            created_at: current_time,
            last_transfer_time: current_time
        };

        update_holder_balance(
            collection,
            recipient,
            object::uid_to_inner(&token_id),
            amount
        );

        let metadata_event = TokenMetadataEvent {
            name: string::utf8(name),
            description: string::utf8(description),
            uri: string::utf8(uri)
        };

        event::emit(TokenMinted {
            token_id: object::uid_to_inner(&token_id),
            creator: tx_context::sender(ctx),
            recipient,
            amount,
            metadata: metadata_event,
            timestamp: current_time
        });

        transfer::public_transfer(nft, recipient);
        object::delete(token_id);
    }

    public entry fun deposit_revenue(
        collection: &mut Collection,
        token_id: ID,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(vector::contains(&collection.operators, &sender), ENO_OPERATOR);
        assert!(vec_map::contains(&collection.token_supplies, &token_id), ETOKEN_NOT_EXIST);
        
        let current_supply = *vec_map::get(&collection.token_supplies, &token_id);
        assert!(current_supply > 0, EZERO_SUPPLY);
        assert!(coin::value(payment) >= amount && amount > 0, EINVALID_AMOUNT);

        // Update total revenue
        if (!vec_map::contains(&collection.total_revenue, &token_id)) {
            vec_map::insert(&mut collection.total_revenue, token_id, 0);
        };
        let total_revenue = vec_map::get_mut(&mut collection.total_revenue, &token_id);
        *total_revenue = safe_add(*total_revenue, amount);

        // Get or initialize epoch counter
        let epoch_counter = if (vec_map::contains(&collection.epoch_counter, &token_id)) {
            vec_map::get_mut(&mut collection.epoch_counter, &token_id)
        } else {
            vec_map::insert(&mut collection.epoch_counter, token_id, 0);
            vec_map::get_mut(&mut collection.epoch_counter, &token_id)
        };

        // Calculate cumulative amount
        let previous_cumulative = if (!vec_map::contains(&collection.revenue_epochs, &token_id)) {
            vec_map::insert(&mut collection.revenue_epochs, token_id, vector::empty());
            0
        } else {
            let epochs = vec_map::get(&collection.revenue_epochs, &token_id);
            if (vector::is_empty(epochs)) {
                0
            } else {
                let last_epoch = vector::borrow(epochs, vector::length(epochs) - 1);
                last_epoch.cumulative_amount
            }
        };

        // Create new epoch
        let new_epoch = RevenueEpoch {
            epoch_id: *epoch_counter,
            amount,
            total_supply: current_supply,
            withdrawn_addresses: vec_map::empty(),
            cumulative_amount: safe_add(previous_cumulative, amount),
            timestamp: tx_context::epoch(ctx)
        };

        *epoch_counter = *epoch_counter + 1;

        // Add revenue to balance
        let revenue = vec_map::get_mut(&mut collection.revenues, &token_id);
        let paid = coin::split(payment, amount, ctx);
        balance::join(revenue, coin::into_balance(paid));

        // Add epoch
        let epochs = vec_map::get_mut(&mut collection.revenue_epochs, &token_id);
        vector::push_back(epochs, new_epoch);

        event::emit(RevenueDeposited {
            token_id,
            operator: sender,
            amount,
            total_supply: current_supply,
            epoch_id: *epoch_counter - 1,
            cumulative_amount: safe_add(previous_cumulative, amount),
            timestamp: tx_context::epoch(ctx)
        });
    }

    public entry fun withdraw_revenue(
        collection: &mut Collection,
        nft: &mut NFT,
        ctx: &mut TxContext
    ) {
        // Basic validations
        let sender = tx_context::sender(ctx);
        let token_id = nft.token_id;

        assert!(vec_map::contains(&collection.revenues, &token_id), ETOKEN_NOT_EXIST);
        assert!(nft.balance > 0, ENO_BALANCE);

        // Get revenue epochs
        let revenue_epochs = vec_map::get_mut(&mut collection.revenue_epochs, &token_id);
        let current_epoch = vector::length(revenue_epochs);
        
        // Skip if no new epochs since last claim
        assert!(current_epoch > nft.last_epoch_claimed, ENO_NEW_REVENUE);

        // Calculate withdrawal amounts
        let withdrawal_info = calculate_withdrawal_amounts(
            revenue_epochs,
            nft.balance,
            nft.last_epoch_claimed,
            current_epoch,
            sender
        );

        assert!(withdrawal_info.withdrawable_amount > 0, ENO_NEW_REVENUE);

        // Track withdrawn epochs
        let mut i = 0;
        let epochs_len = vector::length(&withdrawal_info.withdrawn_epochs);
        while (i < epochs_len) {
            let epoch_index = *vector::borrow(&withdrawal_info.withdrawn_epochs, i);
            let epoch = vector::borrow_mut(revenue_epochs, epoch_index);
            vec_map::insert(&mut epoch.withdrawn_addresses, sender, true);
            i = i + 1;
        };

        // Update NFT state
        nft.claimed_revenue = safe_add(
            nft.claimed_revenue, 
            withdrawal_info.withdrawable_amount
        );
        nft.last_epoch_claimed = current_epoch;
        vector::append(&mut nft.epochs_withdrawn, withdrawal_info.withdrawn_epochs);

        // Calculate remaining claimable revenue
        let total_revenue = if (vec_map::contains(&collection.total_revenue, &token_id)) {
            *vec_map::get(&collection.total_revenue, &token_id)
        } else {
            0
        };

        let remaining_claimable = if (total_revenue > withdrawal_info.total_shares) {
            total_revenue - withdrawal_info.total_shares
        } else {
            0
        };

        // Perform revenue transfer
        let revenue_balance = vec_map::get_mut(&mut collection.revenues, &token_id);
        assert!(
            balance::value(revenue_balance) >= withdrawal_info.withdrawable_amount,
            EINVALID_AMOUNT
        );

        let withdrawal = coin::from_balance(
            balance::split(revenue_balance, withdrawal_info.withdrawable_amount),
            ctx
        );

        // Emit detailed event
        event::emit(RevenueWithdrawn {
            token_id,
            holder: sender,
            amount: withdrawal_info.withdrawable_amount,
            epochs: withdrawal_info.withdrawn_epochs,
            remaining_balance: balance::value(revenue_balance),
            remaining_unclaimed: withdrawal_info.remaining_unclaimed,
            remaining_claimable,
            total_claimed: nft.claimed_revenue,
            holder_balance: nft.balance,
            timestamp: tx_context::epoch(ctx)
        });

        // Transfer revenue to sender
        transfer::public_transfer(withdrawal, sender);
    }

    public entry fun transfer(
        collection: &mut Collection,
        nft: &mut NFT,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        assert!(nft.balance >= amount, ENO_BALANCE);
        assert!(amount > 0, EINVALID_AMOUNT);
        assert!(recipient != sender, EINVALID_RECIPIENT);
        assert!(token_exists(collection, nft.token_id), ETOKEN_NOT_EXIST);

        // Calculate claimed revenue share for transfer amount
        let (transfer_claimed_revenue, _) = safe_calculate_share(
            nft.claimed_revenue,
            amount,
            nft.balance
        );

        // Create withdrawal history for recipient
        let mut recipient_epochs = vector::empty();
        let epochs_len = vector::length(&nft.epochs_withdrawn);
        let mut i = 0;

        while (i < epochs_len) {
            let epoch_id = *vector::borrow(&nft.epochs_withdrawn, i);
            vector::push_back(&mut recipient_epochs, epoch_id);
            i = i + 1;
        };

        let current_time = tx_context::epoch(ctx);

        // Create new NFT for recipient
        let new_nft = NFT {
            id: object::new(ctx),
            token_id: nft.token_id,
            balance: amount,
            claimed_revenue: transfer_claimed_revenue,
            epochs_withdrawn: recipient_epochs,
            last_epoch_claimed: nft.last_epoch_claimed,
            created_at: current_time,
            last_transfer_time: current_time
        };

        // Update sender's NFT
        nft.balance = nft.balance - amount;
        nft.claimed_revenue = safe_sub(nft.claimed_revenue, transfer_claimed_revenue);
        nft.last_transfer_time = current_time;

        // Update holder balances
        update_holder_balance(collection, sender, nft.token_id, nft.balance);
        update_holder_balance(collection, recipient, nft.token_id, amount);

        // Update epoch withdrawal records
        let mut_revenue_epochs = vec_map::get_mut(
            &mut collection.revenue_epochs,
            &nft.token_id
        );
            
        i = 0;
        let total_epochs = vector::length(mut_revenue_epochs);
            
        while (i < total_epochs) {
            let epoch = vector::borrow_mut(mut_revenue_epochs, i);
            if (vec_map::contains(&epoch.withdrawn_addresses, &sender)) {
                let (epoch_share, _) = safe_calculate_share(
                    epoch.amount,
                    amount,
                    epoch.total_supply
                );
                if (epoch_share > 0) {
                    vec_map::insert(&mut epoch.withdrawn_addresses, recipient, true);
                }
            };
            i = i + 1;
        };

        // Emit transfer event
        event::emit(TokenTransferred {
            token_id: nft.token_id,
            from: sender,
            to: recipient,
            amount,
            transferred_revenue: transfer_claimed_revenue,
            epoch_context: recipient_epochs,
            timestamp: current_time
        });

        transfer::public_transfer(new_nft, recipient);
    }

    /* Helper functions */
    fun calculate_withdrawal_amounts(
        revenue_epochs: &mut vector<RevenueEpoch>,
        holder_balance: u64,
        last_claimed: u64,
        current_epoch: u64,
        sender: address
    ): WithdrawalInfo {
        let mut withdrawable_amount: u64 = 0;
        let mut withdrawn_epochs = vector::empty();
        let mut remaining_unclaimed: u64 = 0;
        let mut total_shares: u64 = 0;
        let mut i = last_claimed;

        while (i < current_epoch) {
            let epoch = vector::borrow_mut(revenue_epochs, i);
            
            if (!vec_map::contains(&epoch.withdrawn_addresses, &sender)) {
                let (epoch_share, unclaimed) = safe_calculate_share(
                    epoch.amount,
                    holder_balance,
                    epoch.total_supply
                );

                if (epoch_share > 0) {
                    withdrawable_amount = safe_add(withdrawable_amount, epoch_share);
                    vector::push_back(&mut withdrawn_epochs, i);
                    total_shares = safe_add(total_shares, epoch_share);
                };

                remaining_unclaimed = safe_add(remaining_unclaimed, unclaimed);
            };
            i = i + 1;
        };

        WithdrawalInfo {
            withdrawable_amount,
            withdrawn_epochs,
            remaining_unclaimed,
            total_shares
        }
    }

    fun update_holder_balance(
        collection: &mut Collection,
        holder: address,
        token_id: ID,
        amount: u64
    ) {
        if (!vec_map::contains(&collection.holder_balances, &holder)) {
            vec_map::insert(&mut collection.holder_balances, holder, vec_map::empty());
        };
        
        let balances = vec_map::get_mut(&mut collection.holder_balances, &holder);
        if (!vec_map::contains(balances, &token_id)) {
            vec_map::insert(balances, token_id, amount);
        } else {
            *vec_map::get_mut(balances, &token_id) = amount;
        };
    }

    /* Safe math functions */
    fun safe_add(a: u64, b: u64): u64 {
        let c = a + b;
        assert!(c >= a, EOVERFLOW);
        c
    }

    fun safe_sub(a: u64, b: u64): u64 {
        assert!(a >= b, EOVERFLOW);
        a - b
    }

    fun safe_multiply_ratio(amount: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, EZERO_SUPPLY);
        ((((amount as u128) * (numerator as u128)) / (denominator as u128)) as u64)
    }

    fun safe_calculate_share(amount: u64, balance: u64, total_supply: u64): (u64, u64) {
        assert!(total_supply > 0, EZERO_SUPPLY);
        let share = safe_multiply_ratio(amount, balance, total_supply);
        let unclaimed = safe_sub(amount, share);
        (share, unclaimed)
    }

    /* View functions */
    public fun token_exists(collection: &Collection, token_id: ID): bool {
        vec_map::contains(&collection.token_supplies, &token_id)
    }

    public fun is_operator(collection: &Collection, addr: address): bool {
        vector::contains(&collection.operators, &addr)
    }

    public fun get_token_balance(nft: &NFT): u64 {
        nft.balance
    }

    public fun get_claimed_revenue(nft: &NFT): u64 {
        nft.claimed_revenue
    }

    public fun get_last_epoch_claimed(nft: &NFT): u64 {
        nft.last_epoch_claimed
    }

    public fun get_total_supply(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(&collection.token_supplies, &token_id)
    }

    public fun get_revenue_balance(collection: &Collection, token_id: ID): u64 {
        balance::value(vec_map::get(&collection.revenues, &token_id))
    }

    public fun get_total_revenue(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(&collection.total_revenue, &token_id)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}    
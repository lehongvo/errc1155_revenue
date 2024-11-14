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
    const ENO_MINT_AUTHORITY: u64 = 1; // Only mint authority can perform this action
    const ENO_OPERATOR: u64 = 2; // Only operator can perform this action
    const ETOKEN_NOT_EXIST: u64 = 3; // Token does not exist
    const ENO_BALANCE: u64 = 4; // No balance to withdraw from token holder 
    const EINVALID_AMOUNT: u64 = 5; // Invalid amount for operation
    const ENO_NEW_REVENUE: u64 = 6; // No new revenue to withdraw
    const EINVALID_RECIPIENT: u64 = 7; // Invalid recipient for transfer operation 
    const EZERO_SUPPLY: u64 = 8; // Zero supply for token
    const EOVERFLOW: u64 = 12; // Overflow in safe math operation
    
    /*
    * RevenueEpoch struct represents an epoch period for revenue distribution and tracking
    * - epoch_id: Unique identifier for the revenue distribution epoch
    * - amount: Revenue amount allocated for distribution in this epoch
    * - total_supply: Total token supply snapshot when epoch was created
    * - withdrawn_addresses: Mapping of addresses that have claimed their share
    * - cumulative_amount: Total revenue distributed across all epochs up to this one
    * - timestamp: Unix timestamp when epoch was created
    */
    public struct RevenueEpoch has store {
        epoch_id: u64,
        amount: u64,
        total_supply: u64,
        withdrawn_addresses: VecMap<address, bool>,
        cumulative_amount: u64,
        timestamp: u64
    }
    
    /*
    * WithdrawalInfo struct contains withdrawal and earnings tracking information
    * - withdrawable_amount: Total amount currently available for withdrawal
    * - withdrawn_epochs: List of epoch IDs that have been withdrawn from
    * - remaining_unclaimed: Amount of tokens still unclaimed from all epochs
    * - total_shares: Total number of shares/tokens used for calculating earnings
    */
    public struct WithdrawalInfo has drop {
        withdrawable_amount: u64,
        withdrawn_epochs: vector<u64>,
        remaining_unclaimed: u64,
        total_shares: u64
    }
    
    /*
    * NFT struct represents a token with revenue claiming capabilities
    * - id: Unique identifier for this NFT instance
    * - token_id: ID of the token type this NFT represents
    * - balance: Current token balance owned by this NFT
    * - claimed_revenue: Total amount of revenue claimed by this NFT
    * - epochs_withdrawn: List of epoch IDs this NFT has withdrawn from
    * - last_epoch_claimed: ID of the most recent epoch claimed
    * - created_at: Timestamp when this NFT was created
    * - last_transfer_time: Timestamp of the most recent transfer
    */
    public struct NFT has key, store {
        id: UID,
        token_id: ID,
        balance: u64,
        claimed_revenue: u64,
        epochs_withdrawn: vector<u64>,
        last_epoch_claimed: u64,
        created_at: u64,
        last_transfer_time: u64,
    }

    /*
    * Collection struct represents the main container for managing tokens and revenue
    * - id: Unique identifier for the collection
    * - mint_authority: Address authorized to mint new tokens
    * - operators: List of addresses with operational privileges
    * - token_supplies: Mapping of token IDs to their total supply
    * - token_metadata: Bag storing metadata for all tokens
    * - revenues: Mapping of token IDs to their SUI balance
    * - holder_balances: Nested mapping of address -> token ID -> balance
    * - revenue_epochs: Mapping of token IDs to their revenue distribution epochs
    * - epoch_counter: Mapping of token IDs to their current epoch number
    * - total_revenue: Mapping of token IDs to their total historical revenue
    * - created_at: Timestamp when collection was created
    */
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

    /*
    * TokenMetadata struct contains descriptive information about a token
    * - name: Token name
    * - description: Detailed description of the token
    * - uri: URI pointing to token's external metadata
    * - created_at: Timestamp when metadata was created
    * - properties: Optional additional key-value properties
    */
    public struct TokenMetadata has store {
        name: String,
        description: String,
        uri: String,
        created_at: u64,
        properties: Option<VecMap<String, String>>
    }

    /*
    * TokenMinted event struct for tracking token minting operations
    * - token_id: ID of the minted token
    * - creator: Address that created the token
    * - recipient: Address receiving the minted tokens
    * - amount: Quantity of tokens minted
    * - metadata: Associated token metadata
    * - timestamp: When minting occurred
    */
    public struct TokenMinted has copy, drop {
        token_id: ID,
        creator: address,
        recipient: address,
        amount: u64,
        metadata: TokenMetadataEvent,
        timestamp: u64
    }

    /*
    * TokenMetadataEvent struct for emitting metadata updates
    * - name: Updated token name
    * - description: Updated token description
    * - uri: Updated metadata URI
    */
    public struct TokenMetadataEvent has copy, drop {
        name: String,
        description: String,
        uri: String
    }

    /*
    * RevenueDeposited event struct for tracking revenue deposits
    * - token_id: ID of token receiving revenue
    * - operator: Address depositing the revenue
    * - amount: Amount of revenue deposited
    * - total_supply: Total token supply at deposit time
    * - epoch_id: ID of the revenue epoch
    * - cumulative_amount: Total revenue including this deposit
    * - timestamp: When deposit occurred
    */
    public struct RevenueDeposited has copy, drop {
        token_id: ID,
        operator: address,
        amount: u64,
        total_supply: u64,
        epoch_id: u64,
        cumulative_amount: u64,
        timestamp: u64
    }

    /*
    * RevenueWithdrawn event struct for tracking revenue withdrawals
    * - token_id: ID of token revenue is withdrawn from
    * - holder: Address withdrawing revenue
    * - amount: Amount withdrawn
    * - epochs: List of epochs included in withdrawal
    * - remaining_balance: Holder's remaining token balance
    * - remaining_unclaimed: Revenue still unclaimed
    * - remaining_claimable: Revenue available to claim
    * - total_claimed: Total revenue claimed by holder
    * - holder_balance: Current token balance of holder
    * - timestamp: When withdrawal occurred
    */
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

    /*
    * TokenTransferred event struct for tracking token transfers
    * - token_id: ID of transferred token
    * - from: Sender address
    * - to: Recipient address
    * - amount: Amount of tokens transferred
    * - transferred_revenue: Revenue rights transferred
    * - epoch_context: List of relevant epoch IDs
    * - timestamp: When transfer occurred
    */
    public struct TokenTransferred has copy, drop {
        token_id: ID,
        from: address,
        to: address,
        amount: u64,
        transferred_revenue: u64,
        epoch_context: vector<u64>,
        timestamp: u64
    }

    /* Core functions for managing the token collection and minting process */

    /*
    * Initializes a new Collection object and shares it
    * - Creates collection with default empty values
    * - Sets sender as mint authority
    * - Shares collection object for public access
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
            revenue_epochs: vec_map::empty(),
            epoch_counter: vec_map::empty(),
            total_revenue: vec_map::empty(),
            created_at: tx_context::epoch(ctx)
        };
        transfer::share_object(collection);
    }

    /*
    * Adds a new operator to the collection
    * - Only callable by mint authority
    * - Prevents duplicate operator addresses
    * Parameters:
    * - collection: Collection to modify
    * - operator: Address to add as operator
    * - ctx: Transaction context
    */
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

    /*
    * Removes an operator from the collection
    * - Only callable by mint authority
    * - Safely handles non-existent operators
    * Parameters:
    * - collection: Collection to modify
    * - operator: Address to remove from operators
    * - ctx: Transaction context
    */
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

    /*
    * Mints new tokens and creates associated NFT
    * - Only callable by mint authority
    * - Creates new token with metadata
    * - Initializes all tracking maps for the token
    * - Creates and transfers NFT to recipient
    * - Emits TokenMinted event
    * 
    * Parameters:
    * - collection: Collection to mint in
    * - name: Token name in UTF-8 bytes
    * - description: Token description in UTF-8 bytes
    * - uri: Metadata URI in UTF-8 bytes
    * - amount: Amount of tokens to mint
    * - recipient: Address to receive the NFT
    * - ctx: Transaction context
    *
    * Flow:
    * 1. Validate authority and amount
    * 2. Create token ID and metadata
    * 3. Initialize token tracking maps
    * 4. Create and configure NFT
    * 5. Update holder balances
    * 6. Emit minting event
    * 7. Transfer NFT to recipient
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
       
        // Initialize token tracking maps and NFT
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
        
        // Emit minting event
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

    /*
    * Deposits revenue (in SUI) for a specific token ID in the collection
    * - Only operators can deposit revenue
    * - Creates a new revenue epoch for distribution
    * - Updates cumulative revenue tracking
    * - Emits RevenueDeposited event
    * 
    * Parameters:
    * - collection: Collection containing the token
    * - token_id: ID of token to deposit revenue for
    * - payment: SUI coin to deposit as revenue
    * - amount: Amount of SUI to deposit
    * - ctx: Transaction context
    *
    * Flow:
    * 1. Validate operator permissions and token existence
    * 2. Verify token supply and payment amount
    * 3. Update total revenue tracking
    * 4. Create new revenue epoch
    * 5. Add revenue to token's balance
    * 6. Emit deposit event
    * 
    * Reverts if:
    * - Sender is not an operator (ENO_OPERATOR)
    * - Token doesn't exist (ETOKEN_NOT_EXIST)
    * - Token has zero supply (EZERO_SUPPLY)
    * - Invalid payment amount (EINVALID_AMOUNT)
    */
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

        // Add epoch to collection
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
    
    /*
    * Withdraws accumulated revenue for an NFT holder
    * - Calculates and distributes revenue share based on token balance
    * - Updates withdrawal history and claimed amounts
    * - Handles revenue distribution across multiple epochs
    * - Emits RevenueWithdrawn event
    *
    * Parameters:
    * - collection: Collection containing the token
    * - nft: NFT representing holder's token balance and claims
    * - ctx: Transaction context
    *
    * Flow:
    * 1. Validate token existence and holder balance
    * 2. Check for new revenue epochs since last claim
    * 3. Calculate claimable amounts across epochs
    * 4. Update withdrawal records for each epoch
    * 5. Update NFT state (claimed amounts, epochs)
    * 6. Transfer revenue to holder
    * 7. Emit withdrawal event
    *
    * Reverts if:
    * - Token doesn't exist (ETOKEN_NOT_EXIST)
    * - NFT has zero balance (ENO_BALANCE)
    * - No new revenue since last claim (ENO_NEW_REVENUE)
    * - Invalid withdrawal amount (EINVALID_AMOUNT)
    */
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
    
    /*
    * Transfers tokens between addresses with revenue claim rights
    * - Transfers specified amount of tokens to recipient
    * - Calculates and transfers proportional claimed revenue rights
    * - Creates new NFT for recipient with transferred balance and rights
    * - Updates withdrawal history for both sender and recipient
    * - Emits TokenTransferred event
    *
    * Parameters:
    * - collection: Collection containing the token
    * - nft: NFT representing sender's tokens and claims
    * - amount: Amount of tokens to transfer
    * - recipient: Address to receive the tokens
    * - ctx: Transaction context
    *
    * Flow:
    * 1. Validate transfer requirements (balance, amount, addresses)
    * 2. Calculate revenue share to transfer
    * 3. Copy withdrawal history for recipient
    * 4. Create new NFT for recipient
    * 5. Update sender's NFT state
    * 6. Update holder balances in collection
    * 7. Update epoch withdrawal records
    * 8. Transfer NFT and emit event
    *
    * Reverts if:
    * - Insufficient balance (ENO_BALANCE)
    * - Invalid transfer amount (EINVALID_AMOUNT)
    * - Invalid recipient (EINVALID_RECIPIENT)
    * - Token doesn't exist (ETOKEN_NOT_EXIST)
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

        // Update sender's epochs with withdrawn status
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
    
    /*
    * Calculates withdrawal amounts and tracks epochs for revenue distribution
    * - Processes each epoch to determine claimable revenue
    * - Handles per-epoch withdrawal tracking
    * - Calculates shares based on holder balance
    *
    * Parameters:
    * - revenue_epochs: Vector of all revenue epochs for the token
    * - holder_balance: Current token balance of the holder
    * - last_claimed: Last epoch ID claimed by holder
    * - current_epoch: Current epoch ID
    * - sender: Address of the holder claiming revenue
    *
    * Returns:
    * WithdrawalInfo struct containing:
    * - withdrawable_amount: Total amount that can be withdrawn
    * - withdrawn_epochs: Vector of epoch IDs processed in this withdrawal
    * - remaining_unclaimed: Amount that remains unclaimed after this withdrawal
    * - total_shares: Total amount of shares calculated for this withdrawal
    *
    * Flow:
    * 1. Initialize tracking variables
    * 2. Process each unclaimed epoch
    * 3. For each epoch:
    *    - Check if already withdrawn
    *    - Calculate holder's share
    *    - Track withdrawable amounts
    *    - Record processed epochs
    * 4. Return consolidated withdrawal info
    */
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
        
        // Process each unclaimed epoch for withdrawal
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
    
    /*
    * Updates or initializes a holder's balance for a specific token
    * - Creates holder balance mapping if not exists
    * - Updates token balance for holder
    *
    * Parameters:
    * - collection: Collection containing holder balances
    * - holder: Address of the token holder
    * - token_id: ID of the token to update balance for
    * - amount: New balance amount to set
    *
    * Flow:
    * 1. Initialize holder's balance map if first time
    * 2. Get holder's balance mapping
    * 3. Create or update token balance
    *
    * Example:
    * Holder A with Token 1:
    * - First transfer: Creates map + sets balance
    * - Later transfer: Updates existing balance
    */
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
    
    /*
    * Safely adds two u64 numbers with overflow checking
    * - Reverts if result would overflow u64
    * 
    * Parameters:
    * - a: First number to add
    * - b: Second number to add
    *
    * Returns:
    * - Sum of a and b if no overflow
    * 
    * Reverts if:
    * - Result would be greater than u64 max (EOVERFLOW)
    */
    fun safe_add(a: u64, b: u64): u64 {
        let c = a + b;
        assert!(c >= a, EOVERFLOW);
        c
    }
    
    /*
    * Safely subtracts two u64 numbers with underflow checking
    * 
    * Parameters:
    * - a: Number to subtract from (minuend)
    * - b: Number to subtract (subtrahend)
    *
    * Returns:
    * - u64: The result of a - b if no underflow occurs
    *
    * Error Handling:
    * - Reverts with EOVERFLOW if a < b (underflow)
    * 
    * Examples:
    * - safe_sub(10, 5) -> 5 (Success)
    * - safe_sub(5, 10) -> revert EOVERFLOW (Fails)
    * - safe_sub(5, 5) -> 0 (Success)
    *
    * Use Cases:
    * - Balance deductions
    * - Token transfers
    * - Revenue calculations
    * - Share computations
    */
    fun safe_sub(a: u64, b: u64): u64 {
        assert!(a >= b, EOVERFLOW);
        a - b
    }
    
    /*
    * Safely multiplies an amount by a ratio (numerator/denominator) with overflow protection
    * Calculates: amount * numerator / denominator
    * 
    * Parameters:
    * - amount: Base amount for calculation (e.g. total revenue)
    * - numerator: Top part of ratio (e.g. holder's balance)
    * - denominator: Bottom part of ratio (e.g. total supply)
    *
    * Returns:
    * - u64: Result of (amount * numerator / denominator)
    *
    * Error Handling:
    * - Reverts with EZERO_SUPPLY if denominator is zero
    * 
    * Overflow Protection:
    * - Uses u128 for intermediate calculations to prevent overflow
    * - Steps: 
    *   1. Cast u64 inputs to u128
    *   2. Perform multiplication safely in u128
    *   3. Perform division in u128
    *   4. Cast result back to u64
    *
    * Examples:
    * - amount: 1000, numerator: 600, denominator: 1000 -> 600 (60%)
    * - amount: 100, numerator: 25, denominator: 100 -> 25 (25%)
    * - amount: 50, numerator: 10, denominator: 0 -> revert EZERO_SUPPLY
    *
    * Common Use Cases:
    * - Calculating holder's share of revenue
    * - Computing proportional token amounts
    * - Determining fractional distributions
    */
    fun safe_multiply_ratio(amount: u64, numerator: u64, denominator: u64): u64 {
        assert!(denominator > 0, EZERO_SUPPLY);
        ((((amount as u128) * (numerator as u128)) / (denominator as u128)) as u64)
    }
    
    /*
    * Calculates a holder's share of an amount and the remaining unclaimed portion
    * Used for revenue distribution and token transfer calculations
    * 
    * Parameters:
    * - amount: Total amount to calculate share from (e.g. revenue to distribute)
    * - balance: Holder's token balance (numerator in ratio)
    * - total_supply: Total token supply (denominator in ratio)
    *
    * Returns:
    * Tuple of:
    * - share: Holder's calculated portion (amount * balance / total_supply)
    * - unclaimed: Remaining amount after share is removed (amount - share)
    *
    * Error Handling:
    * - Reverts with EZERO_SUPPLY if total_supply is zero
    * - Uses safe_multiply_ratio() for overflow protection
    * - Uses safe_sub() for underflow protection
    *
    * Examples:
    * 1. Equal Distribution:
    *    - amount: 1000, balance: 500, total_supply: 1000
    *    - share = 500 (50%), unclaimed = 500
    *
    * 2. Minority Holder:
    *    - amount: 1000, balance: 100, total_supply: 1000
    *    - share = 100 (10%), unclaimed = 900
    *
    * 3. Single Holder:
    *    - amount: 1000, balance: 1000, total_supply: 1000
    *    - share = 1000 (100%), unclaimed = 0
    *
    * Use Cases:
    * - Revenue distribution calculations
    * - Token transfer share calculations
    * - Proportional reward distributions
    * - Balance-based allocations
    *
    * Formula:
    * share = amount * (balance / total_supply)
    * unclaimed = amount - share
    */
    fun safe_calculate_share(amount: u64, balance: u64, total_supply: u64): (u64, u64) {
        assert!(total_supply > 0, EZERO_SUPPLY);
        let share = safe_multiply_ratio(amount, balance, total_supply);
        let unclaimed = safe_sub(amount, share);
        (share, unclaimed)
    }

    /* 
    * View Functions
    * Read-only functions to query contract state
    * No state modifications, only returns data
    */

    /*
    * Checks if a token exists in the collection
    * Parameters:
    * - collection: Collection to check
    * - token_id: ID of token to verify
    * Returns: true if token exists, false otherwise
    */
    public fun token_exists(collection: &Collection, token_id: ID): bool {
        vec_map::contains(&collection.token_supplies, &token_id)
    }

    /*
    * Verifies if an address is an operator of the collection
    * Parameters:
    * - collection: Collection to check
    * - addr: Address to verify operator status
    * Returns: true if address is operator, false otherwise
    */
    public fun is_operator(collection: &Collection, addr: address): bool {
        vector::contains(&collection.operators, &addr)
    }

    /*
    * Gets the token balance held by an NFT
    * Parameters:
    * - nft: NFT to check balance for
    * Returns: Current token balance in the NFT
    */
    public fun get_token_balance(nft: &NFT): u64 {
        nft.balance
    }

    /*
    * Gets the total revenue claimed by an NFT
    * Parameters:
    * - nft: NFT to check claimed revenue for
    * Returns: Total amount of revenue claimed by this NFT
    */
    public fun get_claimed_revenue(nft: &NFT): u64 {
        nft.claimed_revenue
    }

    /*
    * Gets the last epoch ID claimed by an NFT
    * Parameters:
    * - nft: NFT to check last claimed epoch
    * Returns: ID of the last epoch claimed by this NFT
    */
    public fun get_last_epoch_claimed(nft: &NFT): u64 {
        nft.last_epoch_claimed
    }

    /*
    * Gets the total supply of a specific token
    * Parameters:
    * - collection: Collection containing the token
    * - token_id: ID of token to check supply
    * Returns: Total supply of the token
    */
    public fun get_total_supply(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(&collection.token_supplies, &token_id)
    }

    /*
    * Gets the current revenue balance for a token
    * Parameters:
    * - collection: Collection containing the token
    * - token_id: ID of token to check revenue
    * Returns: Current undistributed revenue balance for the token
    */
    public fun get_revenue_balance(collection: &Collection, token_id: ID): u64 {
        balance::value(vec_map::get(&collection.revenues, &token_id))
    }

    /*
    * Gets the total historical revenue for a token
    * Parameters:
    * - collection: Collection containing the token
    * - token_id: ID of token to check total revenue
    * Returns: Total revenue ever generated by the token
    */
    public fun get_total_revenue(collection: &Collection, token_id: ID): u64 {
        *vec_map::get(&collection.total_revenue, &token_id)
    }

    public fun get_token_id(nft: &NFT): ID {
        nft.token_id
    }

    public fun get_balance(nft: &NFT): u64 {
        nft.balance
    }

    /*
    * Initializes collection for testing purposes
    * Only available in test environment
    * Parameters:
    * - ctx: Transaction context for initialization
    */
    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx)
    }
}    
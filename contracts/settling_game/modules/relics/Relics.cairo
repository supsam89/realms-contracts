// -----------------------------------
//   Module.L02___RELIC
//   Logic around Relics
//
// MIT License
// -----------------------------------

%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_lt

from starkware.cairo.common.bool import TRUE

from openzeppelin.upgrades.library import Proxy

from contracts.settling_game.library.library_module import Module
from contracts.settling_game.modules.relics.library import Relics

from contracts.settling_game.interfaces.IRealms import IRealms
from contracts.settling_game.interfaces.imodules import IModuleController
from contracts.settling_game.utils.game_structs import ModuleIds, RealmData, ExternalContractIds

// -----------------------------------
// Events
// -----------------------------------

@event
func RelicUpdate(relic_id: Uint256, owner_token_id: Uint256) {
}

// -----------------------------------
// Storage
// -----------------------------------

@storage_var
func storage_relic_holder(relic_id: Uint256) -> (owner_token_id: Uint256) {
}

@storage_var
func owned_relics_len(owner_token_id: Uint256) -> (res: felt) {
}

@storage_var
func owned_relics(owner_token_id: Uint256, index: felt) -> (relic_id: Uint256) {
}

// -----------------------------------
// INITIALIZER & UPGRADE
// -----------------------------------

// @notice Module initializer
// @param address_of_controller: Controller/arbiter address
// @proxy_admin: Proxy admin address
@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address_of_controller: felt, proxy_admin: felt
) {
    Module.initializer(address_of_controller);
    Proxy.initializer(proxy_admin);
    return ();
}

// @notice Set new proxy implementation
// @dev Can only be set by the arbiter
// @param new_implementation: New implementation contract address
@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
    return ();
}

// -----------------------------------
// EXTERNAL
// -----------------------------------

// @notice set relic holder external function
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param winner_token_id: winning realm id of battle
// @param loser_token_id: loosing realm id of battle
@external
func set_relic_holder{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    winner_token_id: Uint256, loser_token_id: Uint256
) {
    alloc_locals;
    // Only combat
    Module.only_approved();

    let (controller) = Module.controller_address();

    let (current_relic_owner) = get_current_relic_holder(loser_token_id);

    let (is_equal) = uint256_eq(current_relic_owner, loser_token_id);

    // Capture Relic if owned by loser
    // If Relic is owned by loser, send to victor
    if (is_equal == TRUE) {
        _set_relic_holder(loser_token_id, winner_token_id);
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    }

    let (realms_address) = IModuleController.get_external_contract_address(
        controller, ExternalContractIds.Realms
    );

    let (winner_realm_data: RealmData) = IRealms.fetch_realm_data(realms_address, winner_token_id);

    let (loser_relics_len) = owned_relics_len.read(loser_token_id);

    return loop_claim_order_relic(
        0, realms_address, winner_realm_data, loser_token_id, loser_relics_len
    );
}

// @notice loop loser relic and return if order of winner matches holder
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param index: index of owner relics to check, starting at 0
// @param realms_address: realms token address
// @param winner_realm_data: realm data of the winner
// @param loser_token_id: realm id of loser
// @param loser_relics_len: length of relics array of loser
func loop_claim_order_relic{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    index: felt,
    realms_address: felt,
    winner_realm_data: RealmData,
    loser_token_id: Uint256,
    loser_relics_len: felt,
) {
    if (index == loser_relics_len) {
        return ();
    }

    let (relic_id) = owned_relics.read(loser_token_id, index);

    let (relic_owner_data: RealmData) = IRealms.fetch_realm_data(realms_address, relic_id);

    if (winner_realm_data.order == relic_owner_data.order) {
        _set_relic_holder(relic_id, relic_id);
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    }

    return loop_claim_order_relic(
        index + 1, realms_address, winner_realm_data, loser_token_id, loser_relics_len
    );
}

// @notice return held relics to original owners
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param realms_token_id: realm id that needs assets returned
@external
func return_relics{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    realms_token_id: Uint256
) {
    // Only Settling
    Module.only_approved();
    let (relics_len) = owned_relics_len.read(realms_token_id);

    return loop_return_relics(0, realms_token_id, relics_len);
}

// @notice loop relic held and return it to original owner
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param index: index of relic held
// @param realms_token_id: realm id holding the relics
// @param relics_len: length of relic array held by realm id
func loop_return_relics{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index: felt, realms_token_id: Uint256, relics_len: felt
) {
    if (index == relics_len) {
        return ();
    }

    let (relic_id) = owned_relics.read(realms_token_id, index);

    _set_relic_holder(relic_id, relic_id);

    return loop_return_relics(index + 1, realms_token_id, relics_len);
}

// -----------------------------------
// SETTERS
// -----------------------------------

// @notice get index of relic in the array of relics held
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param relic_id: relic id, original relic owner realm id
// @param owner_token_id: realm id of new owner
func _set_relic_holder{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    relic_id: Uint256, owner_token_id: Uint256
) {
    alloc_locals;
    // Get old relic holder, then update array
    let (old_owner_token_id) = storage_relic_holder.read(relic_id);
    let (old_relics_len) = owned_relics_len.read(old_owner_token_id);

    // If old owner exists, update array
    let (check_exists) = uint256_lt(Uint256(0, 0), old_owner_token_id);
    if (check_exists == TRUE) {
        loop_remove_relic(0, 0, old_relics_len, old_owner_token_id, relic_id);
        owned_relics_len.write(old_owner_token_id, old_relics_len - 1);
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
    }

    // Store in as usual storage value
    storage_relic_holder.write(relic_id, owner_token_id);

    // Array stored for multiple relic returns
    let (relics_len) = owned_relics_len.read(owner_token_id);
    owned_relics.write(owner_token_id, relics_len, relic_id);
    owned_relics_len.write(owner_token_id, relics_len + 1);

    // Emit update whenever Relic changes hands
    RelicUpdate.emit(relic_id, owner_token_id);
    return ();
}

// @notice remove relic from array
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param old_index: index in old (current) owned relic array
// @param new_index: index in new owned relic array
// @param relics_len: length of old owned relic array
// @param owner_token_id: realm id of old relic owner
// @param relic_id: relic id, original relic owner realm id
func loop_remove_relic{pedersen_ptr: HashBuiltin*, syscall_ptr: felt*, range_check_ptr}(
    old_index: felt, new_index: felt, relics_len: felt, owner_token_id: Uint256, relic_id: Uint256
) {
    alloc_locals;
    let check = is_le(relics_len, old_index);
    if (check == TRUE) {
        return ();
    }
    let (stored_relic_id) = owned_relics.read(owner_token_id, old_index);
    let (check) = uint256_eq(stored_relic_id, relic_id);
    if (check == TRUE) {
        let (shift_stored_relic_id) = owned_relics.read(owner_token_id, old_index + 1);
        owned_relics.write(owner_token_id, new_index, shift_stored_relic_id);
        return loop_remove_relic(old_index + 2, new_index + 1, relics_len, owner_token_id, relic_id);
    } else {
        owned_relics.write(owner_token_id, new_index, stored_relic_id);
        return loop_remove_relic(old_index + 1, new_index + 1, relics_len, owner_token_id, relic_id);
    }
}

// -----------------------------------
// GETTERS
// -----------------------------------

// @notice gets current relic holder
// @implicit syscall_ptr
// @implicit range_check_ptr
// @param relic_id: id of relic, pass in realm id
// @return token_id: returns realm id of owning relic
@view
func get_current_relic_holder{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    relic_id: Uint256
) -> (token_id: Uint256) {
    alloc_locals;

    let (holder_id) = storage_relic_holder.read(relic_id);

    let (data) = Relics._current_relic_holder(relic_id, holder_id);

    return (data,);
}
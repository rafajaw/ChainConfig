// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title TestManifest
 * @notice Central registry of ALL test functions across the test suite.
 * @dev This file provides a bird's-eye view of test coverage without implementation pollution.
 *      Each test contract implements a subset of these tests as documented in their sections.
 *
 *      NAMING CONVENTION:
 *      - test_<function>_<scenario>_<expected_outcome>
 *      - testFuzz_<function>_<property>
 *      - invariant_<property>
 *
 *      CURRENT STATS:
 *      - 131 manifest tests.
 *      - 131 implemented tests.
 *      - 57 ChainConfig tests.
 *      - 33 HashLib tests.
 *      - 16 SignatureValidator tests.
 *      - 13 integration tests (IChainConfig drop-in interface).
 *      - 9 fuzz tests.
 *      - 3 stateful invariants (driven by InvariantHandler).
 */


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CHAINCONFIG.SOL - Typed chain-specific configuration registry
// Implemented in: test/ChainConfig/ChainConfig.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface IChainConfigTests {
    // ─── write_config() ──────────────────────────────────────────────────────────
    function test_write_config_writes_address() external;
    function test_write_config_writes_bytes32() external;
    function test_write_config_writes_uint() external;
    function test_write_config_writes_multiple_types() external;
    function test_write_config_writes_under_msg_sender() external;
    function test_write_config_emits_address_written() external;
    function test_write_config_emits_bytes32_written() external;
    function test_write_config_emits_uint_written() external;
    function test_write_config_reverts_on_empty_config() external;
    function test_write_config_reverts_on_wrong_chain_id() external;
    function test_write_config_reverts_on_future_timestamp() external;
    function test_write_config_reverts_on_stale_timestamp() external;
    function test_write_config_reverts_on_same_timestamp() external;
    function test_write_config_allows_newer_timestamp() external;
    function test_write_config_reverts_on_empty_key() external;
    function test_write_config_reverts_on_key_longer_than_32_bytes() external;
    function test_write_config_allows_type_change_with_newer_timestamp() external;
    function test_write_config_reverts_on_type_change_with_stale_timestamp() external;
    function test_write_config_allows_same_key_for_different_signers() external;
    function test_write_config_reverts_on_duplicate_key_same_type_in_payload() external;
    function test_write_config_reverts_on_duplicate_key_across_type_arrays_in_payload() external;
    function test_write_config_reverts_atomically_on_partial_stale_config() external;

    // ─── write_config_as() ───────────────────────────────────────────────────────
    function test_write_config_as_accepts_valid_ecdsa_signature() external;
    function test_write_config_as_accepts_valid_eip1271_signature() external;
    function test_write_config_as_writes_under_signer_not_relayer() external;
    function test_write_config_as_reverts_on_invalid_signature() external;
    function test_write_config_as_reverts_on_wrong_signer() external;
    function test_write_config_as_reverts_on_wrong_chain_id_even_with_valid_signature() external;
    function test_write_config_as_reverts_on_future_timestamp_even_with_valid_signature() external;
    function test_write_config_as_rejects_invalid_signature_before_writing() external;

    // ─── read_address() ──────────────────────────────────────────────────────────
    function test_read_address_with_string_key_returns_value() external;
    function test_read_address_with_bytes32_key_returns_value() external;
    function test_read_address_reverts_if_key_not_set() external;
    function test_read_address_reverts_on_type_mismatch() external;
    function test_read_address_reverts_on_empty_string_key() external;
    function test_read_address_reverts_on_string_key_longer_than_32_bytes() external;

    // ─── read_bytes32() ──────────────────────────────────────────────────────────
    function test_read_bytes32_with_string_key_returns_value() external;
    function test_read_bytes32_with_bytes32_key_returns_value() external;
    function test_read_bytes32_reverts_if_key_not_set() external;
    function test_read_bytes32_reverts_on_type_mismatch() external;
    function test_read_bytes32_reverts_on_empty_string_key() external;
    function test_read_bytes32_reverts_on_string_key_longer_than_32_bytes() external;

    // ─── read_uint() ─────────────────────────────────────────────────────────────
    function test_read_uint_with_string_key_returns_value() external;
    function test_read_uint_with_bytes32_key_returns_value() external;
    function test_read_uint_reverts_if_key_not_set() external;
    function test_read_uint_reverts_on_type_mismatch() external;
    function test_read_uint_reverts_on_empty_string_key() external;
    function test_read_uint_reverts_on_string_key_longer_than_32_bytes() external;

    // ─── EIP-712 Helpers ─────────────────────────────────────────────────────────
    function test_DOMAIN_SEPARATOR_returns_nonzero_domain_separator() external;
    function test_DOMAIN_SEPARATOR_changes_across_chain_ids() external;
    function test___OFF_CHAIN__hash_config_matches_reference_eip712_digest() external;
    function test___OFF_CHAIN__hash_config_changes_with_chain_id_field() external;
    function test___OFF_CHAIN__hash_config_changes_with_timestamp() external;
    function test___OFF_CHAIN__hash_config_changes_with_entry_value() external;
    function test___OFF_CHAIN__hash_config_changes_with_entry_order() external;
    function test___OFF_CHAIN__hash_config_reverts_on_empty_key() external;
    function test___OFF_CHAIN__hash_config_reverts_on_key_longer_than_32_bytes() external;
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HASHLIB.SOL - EIP-712 struct hashing utilities
// Implemented in: test/HashLib/HashLib.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface IHashLibTests {
    // ─── calc_config_struct_hash() ────────────────────────────────────────────────
    function test_calc_config_struct_hash_matches_solidity_reference() external;
    function test_calc_config_struct_hash_empty_arrays_matches_reference() external;
    function test_calc_config_struct_hash_multiple_entries_matches_reference() external;
    function test_calc_config_struct_hash_deterministic() external;
    function test_calc_config_struct_hash_different_chain_id_different_hash() external;
    function test_calc_config_struct_hash_different_timestamp_different_hash() external;

    // ─── hash_address_entries() ──────────────────────────────────────────────────
    function test_hash_address_entries_matches_solidity_reference_single() external;
    function test_hash_address_entries_matches_solidity_reference_multiple() external;
    function test_hash_address_entries_empty_matches_reference() external;
    function test_hash_address_entries_different_order_different_hash() external;
    function test_hash_address_entries_reverts_on_empty_key() external;
    function test_hash_address_entries_reverts_on_key_longer_than_32_bytes() external;

    // ─── hash_bytes32_entries() ──────────────────────────────────────────────────
    function test_hash_bytes32_entries_matches_solidity_reference_single() external;
    function test_hash_bytes32_entries_matches_solidity_reference_multiple() external;
    function test_hash_bytes32_entries_empty_matches_reference() external;
    function test_hash_bytes32_entries_different_order_different_hash() external;
    function test_hash_bytes32_entries_reverts_on_empty_key() external;
    function test_hash_bytes32_entries_reverts_on_key_longer_than_32_bytes() external;

    // ─── hash_uint_entries() ─────────────────────────────────────────────────────
    function test_hash_uint_entries_matches_solidity_reference_single() external;
    function test_hash_uint_entries_matches_solidity_reference_multiple() external;
    function test_hash_uint_entries_empty_matches_reference() external;
    function test_hash_uint_entries_different_order_different_hash() external;
    function test_hash_uint_entries_reverts_on_empty_key() external;
    function test_hash_uint_entries_reverts_on_key_longer_than_32_bytes() external;

    // ─── hash_address_entry() ────────────────────────────────────────────────────
    function test_hash_address_entry_matches_solidity_reference() external;
    function test_hash_address_entry_hashes_string_key_per_eip712() external;
    function test_hash_address_entry_different_value_different_hash() external;

    // ─── hash_bytes32_entry() ────────────────────────────────────────────────────
    function test_hash_bytes32_entry_matches_solidity_reference() external;
    function test_hash_bytes32_entry_hashes_string_key_per_eip712() external;
    function test_hash_bytes32_entry_different_value_different_hash() external;

    // ─── hash_uint_entry() ───────────────────────────────────────────────────────
    function test_hash_uint_entry_matches_solidity_reference() external;
    function test_hash_uint_entry_hashes_string_key_per_eip712() external;
    function test_hash_uint_entry_different_value_different_hash() external;
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SIGNATUREVALIDATOR.SOL - ECDSA and EIP-1271 signature validation
// Implemented in: test/SignatureValidator/SignatureValidator.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface ISignatureValidatorTests {
    // ─── is_valid_signature() ────────────────────────────────────────────────────
    function test_is_valid_signature_rejects_zero_hash() external;
    function test_is_valid_signature_rejects_zero_signer() external;
    function test_is_valid_signature_dispatches_to_ecdsa_when_is_eip1271_is_false() external;
    function test_is_valid_signature_dispatches_to_eip1271_when_is_eip1271_is_true() external;

    // ─── is_valid_ecdsa_signature() ──────────────────────────────────────────────
    function test_is_valid_ecdsa_signature_accepts_valid_signature() external;
    function test_is_valid_ecdsa_signature_rejects_wrong_signer() external;
    function test_is_valid_ecdsa_signature_rejects_wrong_hash() external;
    function test_is_valid_ecdsa_signature_rejects_malformed_signature() external;
    function test_is_valid_ecdsa_signature_rejects_empty_signature() external;

    // ─── is_valid_contract_signature() ───────────────────────────────────────────
    function test_is_valid_contract_signature_accepts_valid_eip1271_wallet() external;
    function test_is_valid_contract_signature_rejects_invalid_eip1271_wallet() external;
    function test_is_valid_contract_signature_rejects_reverting_eip1271_wallet() external;
    function test_is_valid_contract_signature_rejects_eoa() external;
    function test_is_valid_contract_signature_rejects_zero_address() external;
    function test_is_valid_contract_signature_rejects_precompile_address() external;
    function test_is_valid_contract_signature_rejects_contract_returning_wrong_magic_value() external;
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FUZZ - Input-space properties for keys, timestamps, values, and signatures
// Implemented in: test/Fuzz/Fuzz.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface IFuzzTests {
    function testFuzz_write_config_round_trips_address_value( string calldata key, address value, uint256 timestamp ) external;
    function testFuzz_write_config_round_trips_bytes32_value( string calldata key, bytes32 value, uint256 timestamp ) external;
    function testFuzz_write_config_round_trips_uint_value( string calldata key, uint256 value, uint256 timestamp ) external;
    function testFuzz_write_config_accepts_keys_up_to_32_bytes( string calldata key ) external;
    function testFuzz_write_config_rejects_keys_longer_than_32_bytes( string calldata key ) external;
    function testFuzz_write_config_rejects_non_increasing_timestamps( uint256 older_timestamp, uint256 newer_timestamp ) external;
    function testFuzz___OFF_CHAIN__hash_config_matches_reference_for_arbitrary_values( address address_value, bytes32 bytes32_value, uint256 uint_value, uint256 timestamp ) external;
    function testFuzz_write_config_as_accepts_signatures_from_expected_signer( uint256 signer_private_key, uint256 timestamp ) external;
    function testFuzz_write_config_as_rejects_signatures_from_wrong_signer( uint256 signer_private_key, uint256 wrong_private_key, uint256 timestamp ) external;
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// INVARIANTS - Cross-call safety properties
// Implemented in: test/Invariants/Invariants.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface IInvariantTests {
    function invariant_ghost_state_mirrors_onchain_state() external;
    function invariant_string_and_bytes32_reads_agree() external;
    function invariant_only_ghost_type_succeeds_for_reads() external;
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// INTEGRATIONS - Drop-in consumer interface (src/integrations/IChainConfig.sol)
// Implemented in: test/integrations/IChainConfig.t.sol
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

interface IIntegrationTests {
    // ─── Typed-constant routing (interface signature integrity) ──────────────────
    function test_typed_constant_points_to_canonical_address() external;
    function test_read_address_via_typed_constant_returns_written_value() external;
    function test_read_bytes32_via_typed_constant_returns_written_value() external;
    function test_read_uint_via_typed_constant_returns_written_value() external;
    function test_string_key_overload_works_via_typed_constant() external;
    function test_bytes32_key_overload_works_via_typed_constant() external;

    // ─── DAO-as-signer pattern (contract publishing under its own namespace) ─────
    function test_dao_publishes_address_under_its_own_namespace() external;
    function test_dao_publishes_uint_under_its_own_namespace() external;
    function test_two_daos_have_isolated_namespaces() external;
    function test_dao_updates_value_with_newer_timestamp() external;
    function test_dao_changes_type_with_newer_timestamp() external;

    // ─── Downstream consumer pattern (constructor-time read + immutable cache) ───
    function test_downstream_consumer_reads_dao_address_in_constructor() external;
    function test_downstream_consumer_reads_dao_uint_in_constructor() external;
}

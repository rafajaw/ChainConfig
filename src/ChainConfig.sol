// SPDX-License-Identifier: MIT
pragma solidity =0.8.35;

/*
         ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗     ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
        ██╔════╝██║  ██║██╔══██╗██║████╗  ██║    ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
        ██║     ███████║███████║██║██╔██╗ ██║    ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
        ██║     ██╔══██║██╔══██║██║██║╚██╗██║    ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
        ╚██████╗██║  ██║██║  ██║██║██║ ╚████║    ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
         ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
        ━━━━━━━━━━━━━━━━━━━━━━  canonical chain-specific configuration  ━━━━━━━━━━━━━━━━━━━━━━
*/


import { Config, EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION, ValueType } from "./Definitions.sol";
import { Core, InvalidSignature } from "./Core.sol";
import { SignatureValidator } from "./utils/SignatureValidator.sol";


/**
 * @title ChainConfig
 * @notice Canonical EVM registry for typed, chain-specific constants. Same CREATE2 address on every EVM chain so downstream init code stays identical.
 *
 * @dev TRUST MODEL:
 *      - ChainConfig does not decide what is true — the signer does.
 *      - Consumers must hardcode (or otherwise deterministically choose) the trusted signer per key/namespace they read.
 *      - There is no owner, admin, upgrade path, or pause switch.
 *
 * @dev WRITE NAMESPACES:
 *      - Each `signer` address is its own isolated namespace; the same key under two different signers stores two independent values.
 *      - `write_config()` writes under `msg.sender` (EOAs, DAOs, timelocks, contracts).
 *      - `write_config_as()` writes under `signer` after verifying an ECDSA or EIP-1271 signature.
 *
 * @dev KEY ENCODING:
 *      - Keys are signed as strings (≤ 32 bytes, non-empty) for wallet readability.
 *      - Keys are stored as `bytes32` (left-justified ASCII).
 *      - Each (signer, key) holds one value type at a time. The signer can change it in any later write.
 */
contract ChainConfig is Core {

    constructor( )
    Core( EIP712_DOMAIN_NAME, EIP712_DOMAIN_VERSION ) { }


    // ━━━━  WRITE FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /**
     * @notice Write a typed config under `msg.sender`'s namespace.
     * @param config Config payload — chain id, signer-attested timestamp, and entries by type.
     *
     * @dev TIMESTAMP SEMANTICS:
     *      - `config.timestamp` must be <= `block.timestamp` (no future-dated writes).
     *      - `config.timestamp` must be strictly greater than the prior timestamp recorded for every (signer, key) being touched.
     *      - A key's value AND its type are both mutable across writes — the signer is trusted with full authority within their namespace, gated only by strict-monotonic timestamps.
     *
     * @dev EMITTED EVENTS:
     *      - `AddressWritten(signer, key, value)` per address entry.
     *      - `Bytes32Written(signer, key, value)` per bytes32 entry.
     *      - `UintWritten(signer, key, value)` per uint entry.
     *
     * @dev ERROR CODES:
     *      - `EmptyConfig()` if the payload has no entries across all three types.
     *      - `ChainIdMismatch(signed_chain_id, block_chain_id)` if `config.chain_id != block.chainid`.
     *      - `TimestampInFuture(signed_timestamp, block_timestamp)` if `config.timestamp > block.timestamp`.
     *      - `StaleConfig(signer, key, signed_timestamp, prev_timestamp)` if the timestamp does not strictly increase.
     *      - `EmptyKey()` if any entry key is the empty string.
     *      - `KeyTooLong(key, length)` if any entry key exceeds 32 bytes.
     */
    function write_config( Config calldata config )
    external
    {
        _write_config_internal( config, msg.sender );
    }

    /**
     * @notice Write a typed config under `signer`'s namespace, authorized by signature.
     * @param config Config payload — chain id, signer-attested timestamp, and entries by type.
     * @param signer Namespace owner whose entries are being written (the EIP-712 message signer).
     * @param signature EIP-712 signature over the digest returned by `__OFF_CHAIN__hash_config`.
     * @param is_eip1271 `true` for contract signers (Safe / DAO / EIP-1271); `false` for EOA and EIP-7702 ECDSA.
     *
     * @dev RELAYED AUTHORIZATION:
     *      - Anyone may call this — `msg.sender` has no authority over the resulting state.
     *      - All entries are written under `signer`, not under `msg.sender`.
     *      - The relayer cannot alter the payload without invalidating the signature.
     *
     * @dev EIP-712 DOMAIN:
     *      - name:               "ChainConfig"
     *      - version:            "1"
     *      - chainId:            `block.chainid`
     *      - verifyingContract:  ChainConfig address
     *      The signed `Config` also carries `chain_id`; the contract rejects payloads where `config.chain_id != block.chainid`.
     *      This double-binding catches mismatches between payload creation and the wallet's signing context.
     *
     * @dev EMITTED EVENTS:
     *      - Same as `write_config`.
     *
     * @dev ERROR CODES:
     *      - `InvalidSignature(signer, digest, signature)` if ECDSA or EIP-1271 verification fails.
     *      - All error codes from `write_config` apply.
     */
    function write_config_as( Config calldata config, address signer, bytes calldata signature, bool is_eip1271 )
    external
    {
        bytes32 digest  =  _hash_config( config );

        bool is_valid_signature  =  SignatureValidator.is_valid_signature( signer, digest, signature, is_eip1271 );
        if(  is_valid_signature == false  )  revert InvalidSignature({ signer: signer, digest: digest, signature: signature });

        _write_config_internal( config, signer );
    }


    // ━━━━  READ FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /**
     * @notice Read an address value from `signer`'s namespace using a string key.
     * @param signer Namespace owner whose value is being read.
     * @param key Human-readable key (≤ 32 bytes, non-empty), e.g. `"USDC_ADDRESS"`.
     * @return value Address stored at (signer, key).
     *
     * @dev STRING vs BYTES32 KEY OVERLOADS:
     *      Prefer string overloads for off-chain calls and inspection. Prefer the `bytes32` overload inside constructors to avoid string allocation costs.
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     *      - `EmptyKey()` if `key` is the empty string.
     *      - `KeyTooLong(key, length)` if `key` exceeds 32 bytes.
     */
    function read_address( address signer, string calldata key )
    external view returns ( address value )
    {
        return read_address({ signer: signer, key: _key_to_bytes32( key ) });
    }

    /**
     * @notice Read an address value from `signer`'s namespace using a `bytes32` key.
     * @param signer Namespace owner whose value is being read.
     * @param key Left-justified ASCII key bytes, e.g. `bytes32("USDC_ADDRESS")`.
     * @return value Address stored at (signer, key).
     * @dev Prefer this overload inside constructors to avoid string allocation costs.
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     */
    function read_address( address signer, bytes32 key )
    public view returns ( address value )
    {
        _validate_key_read({ signer: signer, key: key, expected_value_type: ValueType.ADDRESS });

        return _addresses[ signer ][ key ];
    }

    /**
     * @notice Read a bytes32 value from `signer`'s namespace using a string key.
     * @param signer Namespace owner whose value is being read.
     * @param key Human-readable key (≤ 32 bytes, non-empty).
     * @return value Bytes32 stored at (signer, key).
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     *      - `EmptyKey()` if `key` is the empty string.
     *      - `KeyTooLong(key, length)` if `key` exceeds 32 bytes.
     */
    function read_bytes32( address signer, string calldata key )
    external view returns ( bytes32 value )
    {
        return read_bytes32({ signer: signer, key: _key_to_bytes32( key ) });
    }

    /**
     * @notice Read a bytes32 value from `signer`'s namespace using a `bytes32` key.
     * @param signer Namespace owner whose value is being read.
     * @param key Left-justified ASCII key bytes.
     * @return value Bytes32 stored at (signer, key).
     * @dev Prefer this overload inside constructors to avoid string allocation costs.
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     */
    function read_bytes32( address signer, bytes32 key )
    public view returns ( bytes32 value )
    {
        _validate_key_read({ signer: signer, key: key, expected_value_type: ValueType.BYTES32 });

        return _bytes32s[ signer ][ key ];
    }

    /**
     * @notice Read a uint256 value from `signer`'s namespace using a string key.
     * @param signer Namespace owner whose value is being read.
     * @param key Human-readable key (≤ 32 bytes, non-empty).
     * @return value Uint256 stored at (signer, key).
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     *      - `EmptyKey()` if `key` is the empty string.
     *      - `KeyTooLong(key, length)` if `key` exceeds 32 bytes.
     */
    function read_uint( address signer, string calldata key )
    external view returns ( uint256 value )
    {
        return read_uint({ signer: signer, key: _key_to_bytes32( key ) });
    }

    /**
     * @notice Read a uint256 value from `signer`'s namespace using a `bytes32` key.
     * @param signer Namespace owner whose value is being read.
     * @param key Left-justified ASCII key bytes.
     * @return value Uint256 stored at (signer, key).
     * @dev Prefer this overload inside constructors to avoid string allocation costs.
     *
     * @dev ERROR CODES:
     *      - `KeyNotSet(signer, key)` if no value has ever been written for this (signer, key).
     *      - `KeyTypeMismatch(signer, key, current_value_type, expected_value_type)` if the key is stored under a different type.
     */
    function read_uint( address signer, bytes32 key )
    public view returns ( uint256 value )
    {
        _validate_key_read({ signer: signer, key: key, expected_value_type: ValueType.UINT });

        return _uints[ signer ][ key ];
    }


    // ━━━━  OFF-CHAIN HELPER FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// @notice EIP-712 domain separator bound to this deployment.
    function DOMAIN_SEPARATOR( )
    external view returns ( bytes32 )
    {
        return _domainSeparatorV4( );
    }

    /**
     * @notice Compute the EIP-712 digest of a `Config` payload for off-chain signing.
     * @param config Config payload to hash.
     * @return digest The digest that `write_config_as` will verify against.
     *
     * @dev Frontends and signing libraries use this to confirm their local digest computation matches the on-chain one before requesting a wallet signature.
     *
     * @dev ERROR CODES:
     *      - `EmptyKey()` if any entry key is the empty string.
     *      - `KeyTooLong(key, length)` if any entry key exceeds 32 bytes.
     */
    function __OFF_CHAIN__hash_config( Config calldata config )
    public view returns ( bytes32 digest )
    {
        return _hash_config( config );
    }


    // ━━━━  FALLBACK  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /**
     * @notice Reject accidental native token deposits.
     */
    receive( )
    external  payable
    {
        revert( "Direct transfers not allowed" );
    }

}

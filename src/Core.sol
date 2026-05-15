// SPDX-License-Identifier: MIT
pragma solidity =0.8.35;

import { EIP712 } from "openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { AddressEntry, Bytes32Entry, Config, EmptyKey, KeyMetadata, KeyTooLong, UintEntry, ValueType } from "./Definitions.sol";
import { HashLib } from "./HashLib.sol";


// ━━━━  ERRORS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

error ChainIdMismatch( uint256 signed_chain_id, uint256 block_chain_id );
error EmptyConfig( );
error InvalidSignature( address signer, bytes32 digest, bytes signature );
error KeyNotSet( address signer, bytes32 key );
error KeyTypeMismatch( address signer, bytes32 key, ValueType current_value_type, ValueType expected_value_type );
error StaleConfig( address signer, bytes32 key, uint256 signed_timestamp, uint256 prev_timestamp );
error TimestampInFuture( uint256 signed_timestamp, uint256 block_timestamp );


// ━━━━  EVENTS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

event AddressWritten( address indexed signer, bytes32 indexed key, address value );
event Bytes32Written( address indexed signer, bytes32 indexed key, bytes32 value );
event UintWritten( address indexed signer, bytes32 indexed key, uint256 value );


abstract contract Core is EIP712 {

    mapping( address => mapping(bytes32=>KeyMetadata) ) internal _key_metadata;
    mapping( address => mapping(bytes32=>address) ) internal _addresses;
    mapping( address => mapping(bytes32=>bytes32) ) internal _bytes32s;
    mapping( address => mapping(bytes32=>uint256) ) internal _uints;

    constructor( string memory name, string memory version )
    EIP712( name, version ) { }


    // ━━━━  INTERNAL WRITE FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _write_config_internal( Config calldata config, address signer ) internal
    {
        _validate_config( config );

        uint256 signed_timestamp  =  config.timestamp;

        for(  uint i = 0  ;  i < config.addresses.length  ;  i++  )  _write_address( signer, config.addresses[ i ], signed_timestamp );
        for(  uint i = 0  ;  i < config.bytes32s.length   ;  i++  )  _write_bytes32( signer, config.bytes32s[ i ], signed_timestamp );
        for(  uint i = 0  ;  i < config.uints.length      ;  i++  )  _write_uint( signer, config.uints[ i ], signed_timestamp );
    }

    // *NOTE*  -  Type changes are allowed (gated only by strict-monotonic timestamp). On a type change the prior-type
    //         -  slot in `_addresses` / `_bytes32s` / `_uints` is intentionally left untouched: reads are type-gated by
    //         -  `_key_metadata.value_type` so the orphan data is unreachable, and a single uniform write path beats
    //         -  per-type clearing branches.

    function _write_address( address signer, AddressEntry calldata entry, uint256 signed_timestamp ) private
    {
        bytes32 key  =  _key_to_bytes32( entry.key );

        _validate_key_write( signer, key, signed_timestamp );

        _key_metadata[ signer ][ key ]  =  KeyMetadata({
            value_type:     ValueType.ADDRESS,
            timestamp:      signed_timestamp
        });

        _addresses[ signer ][ key ]  =  entry.value;

        emit AddressWritten( signer, key, entry.value );
    }

    function _write_bytes32( address signer, Bytes32Entry calldata entry, uint256 signed_timestamp ) private
    {
        bytes32 key  =  _key_to_bytes32( entry.key );

        _validate_key_write( signer, key, signed_timestamp );

        _key_metadata[ signer ][ key ]  =  KeyMetadata({
            value_type:     ValueType.BYTES32,
            timestamp:      signed_timestamp
        });

        _bytes32s[ signer ][ key ]  =  entry.value;

        emit Bytes32Written( signer, key, entry.value );
    }

    function _write_uint( address signer, UintEntry calldata entry, uint256 signed_timestamp ) private
    {
        bytes32 key  =  _key_to_bytes32( entry.key );

        _validate_key_write( signer, key, signed_timestamp );

        _key_metadata[ signer ][ key ]  =  KeyMetadata({
            value_type:     ValueType.UINT,
            timestamp:      signed_timestamp
        });

        _uints[ signer ][ key ]  =  entry.value;

        emit UintWritten( signer, key, entry.value );
    }


    // ━━━━  INTERNAL HELPER FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _hash_config( Config calldata config ) internal view returns ( bytes32 digest )
    {
        bytes32 struct_hash  =  HashLib.calc_config_struct_hash( config );

        return _hashTypedDataV4( struct_hash );
    }


    // ━━━━  VALIDATION FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _validate_key_write( address signer, bytes32 key, uint256 signed_timestamp ) private view
    {
        KeyMetadata storage key_metadata  =  _key_metadata[ signer ][ key ];
        if(  signed_timestamp <= key_metadata.timestamp  )  revert StaleConfig({ signer: signer, key: key, signed_timestamp: signed_timestamp, prev_timestamp: key_metadata.timestamp });
    }

    function _validate_config( Config calldata config ) private view
    {
        if(  config.addresses.length + config.bytes32s.length + config.uints.length == 0  )  revert EmptyConfig( );
        if(  config.chain_id != block.chainid  )              revert ChainIdMismatch({ signed_chain_id: config.chain_id, block_chain_id: block.chainid });
        if(  config.timestamp > block.timestamp  )            revert TimestampInFuture({ signed_timestamp: config.timestamp, block_timestamp: block.timestamp });
    }

    function _validate_key_read( address signer, bytes32 key, ValueType expected_value_type ) internal view
    {
        KeyMetadata storage key_metadata  =  _key_metadata[ signer ][ key ];
        if(  key_metadata.timestamp == 0  )  revert KeyNotSet({ signer: signer, key: key });
        if(  key_metadata.value_type != expected_value_type  )
        {
            revert KeyTypeMismatch({ signer: signer, key: key, current_value_type: key_metadata.value_type, expected_value_type: expected_value_type });
        }
    }


    // ━━━━  KEY FUNCTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _key_to_bytes32( string calldata key )
    internal pure returns ( bytes32 key_bytes32 )
    {
        bytes calldata key_bytes  =  bytes(key);
        if(  key_bytes.length == 0  )   revert EmptyKey( );
        if(  key_bytes.length > 32  )   revert KeyTooLong({ key: key, length: key_bytes.length });

        // Casting is safe because key_bytes.length is checked to be at most 32.
        // forge-lint: disable-next-line(unsafe-typecast)
        return bytes32(key_bytes);
    }
}

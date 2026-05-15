// SPDX-License-Identifier: MIT
pragma solidity =0.8.35;

import { AddressEntry, Bytes32Entry, Config, EmptyKey, KeyTooLong, UintEntry } from "./Definitions.sol";


/**
 * @title HashLib
 * @notice EIP-712 struct hashing for `Config` and its entry types.
 * @dev Off-chain signers must reproduce `calc_config_struct_hash` exactly so `write_config_as` accepts the signature.
 * @dev Keys are hashed as `keccak256(bytes(key))` per EIP-712 dynamic-bytes rules — not as the left-justified `bytes32` form used for on-chain reads.
 */
library HashLib {

    bytes32 private constant _ADDRESS_ENTRY_TYPEHASH  =  keccak256("AddressEntry(string key,address value)");
    bytes32 private constant _BYTES32_ENTRY_TYPEHASH  =  keccak256("Bytes32Entry(string key,bytes32 value)");
    bytes32 private constant _UINT_ENTRY_TYPEHASH     =  keccak256("UintEntry(string key,uint256 value)");
    bytes32 private constant _CONFIG_TYPEHASH         =  keccak256("Config(uint256 chain_id,uint256 timestamp,AddressEntry[] addresses,Bytes32Entry[] bytes32s,UintEntry[] uints)AddressEntry(string key,address value)Bytes32Entry(string key,bytes32 value)UintEntry(string key,uint256 value)");

    function calc_config_struct_hash( Config calldata config )
    internal pure returns ( bytes32 result )
    {
        bytes32 addresses_hash      =  hash_address_entries( config.addresses );
        bytes32 bytes32s_hash       =  hash_bytes32_entries( config.bytes32s );
        bytes32 uints_hash          =  hash_uint_entries( config.uints );
        bytes32 type_hash           =  _CONFIG_TYPEHASH;
        uint256 chain_id            =  config.chain_id;
        uint256 signed_timestamp    =  config.timestamp;

        assembly ("memory-safe")  // *GAS SAVING*  -  Assembly avoids abi.encode overhead for the fixed-width EIP-712 struct.
        {
            let ptr  :=  mload( 0x40 )
            mstore( ptr,              type_hash )
            mstore( add(ptr, 0x20),   chain_id )
            mstore( add(ptr, 0x40),   signed_timestamp )
            mstore( add(ptr, 0x60),   addresses_hash )
            mstore( add(ptr, 0x80),   bytes32s_hash )
            mstore( add(ptr, 0xa0),   uints_hash )

            result  :=  keccak256( ptr, 0xc0 )

            calldatacopy( ptr, calldatasize(), 0xc0 )  // *SECURITY*  -  Clears memory; reading past calldata returns 0 per EVM spec.
        }
    }

    function hash_address_entries( AddressEntry[] calldata entries )
    internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  hash_address_entry( entries[ i ] );
        }

        assembly ("memory-safe")  // *GAS SAVING*  -  Hash array elements directly without Solidity abi.encodePacked overhead.
        {
            let hashes_start_pointer  :=  add( entry_hashes, 0x20 )
            let hashes_size_in_bytes  :=  mul( mload(entry_hashes), 0x20 )

            result  :=  keccak256( hashes_start_pointer, hashes_size_in_bytes )
        }
    }

    function hash_bytes32_entries( Bytes32Entry[] calldata entries )
    internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  hash_bytes32_entry( entries[ i ] );
        }

        assembly ("memory-safe")  // *GAS SAVING*  -  Hash array elements directly without Solidity abi.encodePacked overhead.
        {
            let hashes_start_pointer  :=  add( entry_hashes, 0x20 )
            let hashes_size_in_bytes  :=  mul( mload(entry_hashes), 0x20 )

            result  :=  keccak256( hashes_start_pointer, hashes_size_in_bytes )
        }
    }

    function hash_uint_entries( UintEntry[] calldata entries )
    internal pure returns ( bytes32 result )
    {
        bytes32[] memory entry_hashes  =  new bytes32[]( entries.length );

        for(  uint256 i = 0  ;  i < entries.length  ;  i++  )
        {
            entry_hashes[ i ]  =  hash_uint_entry( entries[ i ] );
        }

        assembly ("memory-safe")  // *GAS SAVING*  -  Hash array elements directly without Solidity abi.encodePacked overhead.
        {
            let hashes_start_pointer  :=  add( entry_hashes, 0x20 )
            let hashes_size_in_bytes  :=  mul( mload(entry_hashes), 0x20 )

            result  :=  keccak256( hashes_start_pointer, hashes_size_in_bytes )
        }
    }

    function hash_address_entry( AddressEntry calldata entry )
    internal pure returns ( bytes32 result )
    {
        bytes32 type_hash  =  _ADDRESS_ENTRY_TYPEHASH;
        bytes32 key_hash   =  _validate_and_hash_key( entry.key );
        address value      =  entry.value;

        assembly ("memory-safe")  // *GAS SAVING*  -  Assembly avoids abi.encode overhead for the fixed-width EIP-712 struct.
        {
            let free_ptr  :=  mload( 0x40 )
            mstore( 0x00, type_hash )
            mstore( 0x20, key_hash )
            mstore( 0x40, value )
            result  :=  keccak256( 0x00, 0x60 )
            mstore( 0x40, free_ptr )
        }
    }

    function hash_bytes32_entry( Bytes32Entry calldata entry )
    internal pure returns ( bytes32 result )
    {
        bytes32 type_hash  =  _BYTES32_ENTRY_TYPEHASH;
        bytes32 key_hash   =  _validate_and_hash_key( entry.key );
        bytes32 value      =  entry.value;

        assembly ("memory-safe")  // *GAS SAVING*  -  Assembly avoids abi.encode overhead for the fixed-width EIP-712 struct.
        {
            let free_ptr  :=  mload( 0x40 )
            mstore( 0x00, type_hash )
            mstore( 0x20, key_hash )
            mstore( 0x40, value )
            result  :=  keccak256( 0x00, 0x60 )
            mstore( 0x40, free_ptr )
        }
    }

    function hash_uint_entry( UintEntry calldata entry )
    internal pure returns ( bytes32 result )
    {
        bytes32 type_hash  =  _UINT_ENTRY_TYPEHASH;
        bytes32 key_hash   =  _validate_and_hash_key( entry.key );
        uint256 value      =  entry.value;

        assembly ("memory-safe")  // *GAS SAVING*  -  Assembly avoids abi.encode overhead for the fixed-width EIP-712 struct.
        {
            let free_ptr  :=  mload( 0x40 )
            mstore( 0x00, type_hash )
            mstore( 0x20, key_hash )
            mstore( 0x40, value )
            result  :=  keccak256( 0x00, 0x60 )
            mstore( 0x40, free_ptr )
        }
    }

    function _validate_and_hash_key( string calldata key )
    private pure returns ( bytes32 key_hash )
    {
        bytes calldata key_bytes  =  bytes(key);
        if(  key_bytes.length == 0  )  revert EmptyKey( );
        if(  key_bytes.length > 32  )  revert KeyTooLong({ key: key, length: key_bytes.length });

        key_hash  =  keccak256( key_bytes );  // forge-lint: disable-line(asm-keccak256)
    }
}

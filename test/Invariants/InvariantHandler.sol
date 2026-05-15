// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Vm } from "forge-std/Vm.sol";
import { ChainConfig } from "../../src/ChainConfig.sol";
import { AddressEntry, Bytes32Entry, Config, UintEntry } from "../../src/Definitions.sol";


/**
 * @notice Stateful fuzz handler for ChainConfig.
 * @dev    Each public function is an action the Foundry invariant runner may call with random
 *         arguments. The handler maintains a ghost-state mirror of what should be true on-chain,
 *         which the invariant tests compare against the actual ChainConfig state after every call.
 */
contract InvariantHandler {

    Vm internal constant vm  =  Vm( address( uint160( uint256( keccak256("hevm cheat code") ) ) ) );

    uint256 internal constant NUM_SIGNERS  =  4;
    uint256 internal constant NUM_KEYS     =  4;

    // *NOTE*  -  Warp far into the future so monotonically-incrementing config timestamps
    //         -  always satisfy `signed_timestamp <= block.timestamp` for the whole run.
    uint256 internal constant FAR_FUTURE_BLOCK_TIMESTAMP  =  4_102_444_800;  // 2100-01-01 UTC.
    uint256 internal constant INITIAL_CLOCK               =  1_700_000_000;  // 2023-11-15 UTC.

    enum GhostType { NONE, ADDRESS, BYTES32, UINT }

    ChainConfig public immutable chain_config;

    uint256[NUM_SIGNERS] internal _private_keys;
    address[NUM_SIGNERS] internal _signers;
    string[NUM_KEYS]     internal _key_strings;
    bytes32[NUM_KEYS]    internal _key_bytes32;

    mapping( address => mapping( bytes32 => GhostType ) ) public ghost_type;
    mapping( address => mapping( bytes32 => uint256   ) ) public ghost_timestamp;
    mapping( address => mapping( bytes32 => address   ) ) public ghost_address;
    mapping( address => mapping( bytes32 => bytes32   ) ) public ghost_bytes32;
    mapping( address => mapping( bytes32 => uint256   ) ) public ghost_uint;

    address[] public touched_signers_list;
    bytes32[] public touched_keys_list;
    mapping( address => bool ) internal _signer_in_list;
    mapping( bytes32 => bool ) internal _key_in_list;

    uint256 public clock;
    uint256 public num_attempts;
    uint256 public num_successful_writes;
    uint256 public num_stale_rejected;
    uint256 public num_invalid_sig_rejected;


    constructor( ChainConfig _chain_config )
    {
        chain_config  =  _chain_config;
        clock         =  INITIAL_CLOCK;

        _private_keys[0]  =  uint256( keccak256("chainconfig.invariant.signer.1") );
        _private_keys[1]  =  uint256( keccak256("chainconfig.invariant.signer.2") );
        _private_keys[2]  =  uint256( keccak256("chainconfig.invariant.signer.3") );
        _private_keys[3]  =  uint256( keccak256("chainconfig.invariant.signer.4") );

        for(  uint256 i = 0  ;  i < NUM_SIGNERS  ;  i++  )
        {
            _signers[ i ]  =  vm.addr( _private_keys[ i ] );
        }

        _key_strings[0]  =  "ALPHA";
        _key_strings[1]  =  "BETA";
        _key_strings[2]  =  "GAMMA";
        _key_strings[3]  =  "DELTA";

        for(  uint256 i = 0  ;  i < NUM_KEYS  ;  i++  )
        {
            _key_bytes32[ i ]  =  _string_to_bytes32( _key_strings[ i ] );
        }

        vm.warp( FAR_FUTURE_BLOCK_TIMESTAMP );
    }


    // ━━━━  ACTIONS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // *NOTE*  -  Type changes are valid writes (gated only by strict-monotonic timestamp), so the actions below
    //         -  never expect a type-conflict revert. The ghost is updated to the new type on every successful write.

    function write_address_direct( uint256 signer_index, uint256 key_index, address value )
    external
    {
        ( address signer, string memory key, bytes32 key_b32 )  =  _resolve( signer_index, key_index );
        uint256 signed_timestamp  =  _next_clock( );

        Config memory config  =  _build_address_config( key, value, signed_timestamp );

        num_attempts  =  num_attempts + 1;

        vm.prank( signer );
        chain_config.write_config( config );

        _record_address_write( signer, key_b32, value, signed_timestamp );
    }

    function write_bytes32_direct( uint256 signer_index, uint256 key_index, bytes32 value )
    external
    {
        ( address signer, string memory key, bytes32 key_b32 )  =  _resolve( signer_index, key_index );
        uint256 signed_timestamp  =  _next_clock( );

        Config memory config  =  _build_bytes32_config( key, value, signed_timestamp );

        num_attempts  =  num_attempts + 1;

        vm.prank( signer );
        chain_config.write_config( config );

        _record_bytes32_write( signer, key_b32, value, signed_timestamp );
    }

    function write_uint_direct( uint256 signer_index, uint256 key_index, uint256 value )
    external
    {
        ( address signer, string memory key, bytes32 key_b32 )  =  _resolve( signer_index, key_index );
        uint256 signed_timestamp  =  _next_clock( );

        Config memory config  =  _build_uint_config( key, value, signed_timestamp );

        num_attempts  =  num_attempts + 1;

        vm.prank( signer );
        chain_config.write_config( config );

        _record_uint_write( signer, key_b32, value, signed_timestamp );
    }

    function write_address_as_relayed( uint256 signer_index, uint256 key_index, address value )
    external
    {
        uint256 si  =  signer_index % NUM_SIGNERS;
        ( address signer, string memory key, bytes32 key_b32 )  =  _resolve( signer_index, key_index );
        uint256 signed_timestamp  =  _next_clock( );

        Config memory config    =  _build_address_config( key, value, signed_timestamp );
        bytes memory signature  =  _sign( config, _private_keys[ si ] );

        num_attempts  =  num_attempts + 1;

        chain_config.write_config_as( config, signer, signature, false );

        _record_address_write( signer, key_b32, value, signed_timestamp );
    }

    function attempt_invalid_signature_write( uint256 signer_index, uint256 key_index, address value, uint256 garbage_seed )
    external
    {
        ( address signer, string memory key,  )  =  _resolve( signer_index, key_index );
        uint256 signed_timestamp  =  _next_clock( );

        Config memory config  =  _build_address_config( key, value, signed_timestamp );

        // *NOTE*  -  Deterministic 65-byte garbage; vanishing probability of matching a real signature.
        bytes memory garbage  =  abi.encodePacked(
            keccak256( abi.encode( garbage_seed, "r" ) ),
            keccak256( abi.encode( garbage_seed, "s" ) ),
            uint8( 27 + uint8( garbage_seed % 2 ) )
        );

        num_attempts  =  num_attempts + 1;

        try chain_config.write_config_as( config, signer, garbage, false )
        {
            revert("invariant violated: invalid-signature write should have reverted");
        }
        catch
        {
            num_invalid_sig_rejected  =  num_invalid_sig_rejected + 1;
        }
    }

    function attempt_stale_timestamp_write( uint256 signer_index, uint256 key_index, uint256 value )
    external
    {
        ( address signer, string memory key, bytes32 key_b32 )  =  _resolve( signer_index, key_index );
        uint256 prev_timestamp  =  ghost_timestamp[ signer ][ key_b32 ];
        if(  prev_timestamp == 0  )  return;  // Nothing yet exists for this (signer, key) to be stale against.

        GhostType current  =  ghost_type[ signer ][ key_b32 ];

        Config memory config;
        if(  current == GhostType.ADDRESS  )  config  =  _build_address_config( key, address( uint160( value ) ), prev_timestamp );
        if(  current == GhostType.BYTES32  )  config  =  _build_bytes32_config( key, bytes32( value ), prev_timestamp );
        if(  current == GhostType.UINT     )  config  =  _build_uint_config(    key, value,                     prev_timestamp );

        num_attempts  =  num_attempts + 1;

        vm.prank( signer );
        try chain_config.write_config( config )
        {
            revert("invariant violated: stale-timestamp write should have reverted");
        }
        catch
        {
            num_stale_rejected  =  num_stale_rejected + 1;
        }
    }


    // ━━━━  ENUMERATION HELPERS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function touched_signers_length( )
    external view returns ( uint256 )
    {
        return touched_signers_list.length;
    }

    function touched_keys_length( )
    external view returns ( uint256 )
    {
        return touched_keys_list.length;
    }


    // ━━━━  GHOST RECORDING  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _record_address_write( address signer, bytes32 key_b32, address value, uint256 signed_timestamp ) internal
    {
        ghost_type[ signer ][ key_b32 ]       =  GhostType.ADDRESS;
        ghost_timestamp[ signer ][ key_b32 ]  =  signed_timestamp;
        ghost_address[ signer ][ key_b32 ]    =  value;

        _mark_touched( signer, key_b32 );
        num_successful_writes  =  num_successful_writes + 1;
    }

    function _record_bytes32_write( address signer, bytes32 key_b32, bytes32 value, uint256 signed_timestamp ) internal
    {
        ghost_type[ signer ][ key_b32 ]       =  GhostType.BYTES32;
        ghost_timestamp[ signer ][ key_b32 ]  =  signed_timestamp;
        ghost_bytes32[ signer ][ key_b32 ]    =  value;

        _mark_touched( signer, key_b32 );
        num_successful_writes  =  num_successful_writes + 1;
    }

    function _record_uint_write( address signer, bytes32 key_b32, uint256 value, uint256 signed_timestamp ) internal
    {
        ghost_type[ signer ][ key_b32 ]       =  GhostType.UINT;
        ghost_timestamp[ signer ][ key_b32 ]  =  signed_timestamp;
        ghost_uint[ signer ][ key_b32 ]       =  value;

        _mark_touched( signer, key_b32 );
        num_successful_writes  =  num_successful_writes + 1;
    }

    function _mark_touched( address signer, bytes32 key_b32 ) internal
    {
        if(  _signer_in_list[ signer ] == false  )
        {
            _signer_in_list[ signer ]  =  true;
            touched_signers_list.push( signer );
        }
        if(  _key_in_list[ key_b32 ] == false  )
        {
            _key_in_list[ key_b32 ]  =  true;
            touched_keys_list.push( key_b32 );
        }
    }


    // ━━━━  INTERNAL HELPERS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _resolve( uint256 signer_index, uint256 key_index )
    internal view returns ( address signer, string memory key, bytes32 key_b32 )
    {
        uint256 si  =  signer_index % NUM_SIGNERS;
        uint256 ki  =  key_index % NUM_KEYS;
        signer    =  _signers[ si ];
        key       =  _key_strings[ ki ];
        key_b32   =  _key_bytes32[ ki ];
    }

    function _next_clock( ) internal returns ( uint256 )
    {
        clock  =  clock + 1;
        return clock;
    }

    function _build_address_config( string memory key, address value, uint256 signed_timestamp )
    internal view returns ( Config memory config )
    {
        config.chain_id    =  block.chainid;
        config.timestamp   =  signed_timestamp;
        config.addresses   =  new AddressEntry[](1);
        config.bytes32s    =  new Bytes32Entry[](0);
        config.uints       =  new UintEntry[](0);
        config.addresses[0]  =  AddressEntry({ key: key, value: value });
    }

    function _build_bytes32_config( string memory key, bytes32 value, uint256 signed_timestamp )
    internal view returns ( Config memory config )
    {
        config.chain_id    =  block.chainid;
        config.timestamp   =  signed_timestamp;
        config.addresses   =  new AddressEntry[](0);
        config.bytes32s    =  new Bytes32Entry[](1);
        config.uints       =  new UintEntry[](0);
        config.bytes32s[0]  =  Bytes32Entry({ key: key, value: value });
    }

    function _build_uint_config( string memory key, uint256 value, uint256 signed_timestamp )
    internal view returns ( Config memory config )
    {
        config.chain_id    =  block.chainid;
        config.timestamp   =  signed_timestamp;
        config.addresses   =  new AddressEntry[](0);
        config.bytes32s    =  new Bytes32Entry[](0);
        config.uints       =  new UintEntry[](1);
        config.uints[0]  =  UintEntry({ key: key, value: value });
    }

    function _sign( Config memory config, uint256 private_key )
    internal view returns ( bytes memory signature )
    {
        bytes32 digest  =  chain_config.__OFF_CHAIN__hash_config( config );

        ( uint8 v, bytes32 r, bytes32 s )  =  vm.sign( private_key, digest );

        signature  =  abi.encodePacked( r, s, v );
    }

    function _string_to_bytes32( string memory s )
    internal pure returns ( bytes32 result )
    {
        bytes memory b  =  bytes(s);
        require( b.length <= 32, "InvariantHandler: key too long" );

        assembly ("memory-safe")
        {
            result  :=  mload( add( b, 0x20 ) )
        }
    }
}

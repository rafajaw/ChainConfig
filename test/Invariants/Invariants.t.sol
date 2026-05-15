// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { ChainConfig } from "../../src/ChainConfig.sol";

import { IInvariantTests } from "../TestManifest.sol";
import { InvariantHandler } from "./InvariantHandler.sol";


/**
 * @notice Stateful invariant suite — drives a randomized sequence of writes via InvariantHandler
 *         and asserts that the on-chain ChainConfig state always matches the handler's ghost mirror.
 */
contract InvariantTest is Test, IInvariantTests {

    ChainConfig internal chain_config;
    InvariantHandler internal handler;


    function setUp( )
    public
    {
        vm.chainId( 31_337 );

        chain_config  =  new ChainConfig();
        handler       =  new InvariantHandler( chain_config );

        bytes4[] memory selectors  =  new bytes4[](6);
        selectors[0]  =  InvariantHandler.write_address_direct.selector;
        selectors[1]  =  InvariantHandler.write_bytes32_direct.selector;
        selectors[2]  =  InvariantHandler.write_uint_direct.selector;
        selectors[3]  =  InvariantHandler.write_address_as_relayed.selector;
        selectors[4]  =  InvariantHandler.attempt_invalid_signature_write.selector;
        selectors[5]  =  InvariantHandler.attempt_stale_timestamp_write.selector;

        targetSelector( StdInvariant.FuzzSelector({ addr: address(handler), selectors: selectors }) );
        targetContract( address(handler) );
    }


    // ━━━━  INVARIANTS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// @notice For every (signer, key) the handler has successfully written, the on-chain value
    ///         must equal the ghost value, across all three value types.
    function invariant_ghost_state_mirrors_onchain_state( )
    external view
    {
        uint256 num_signers  =  handler.touched_signers_length( );
        uint256 num_keys     =  handler.touched_keys_length( );

        for(  uint256 i = 0  ;  i < num_signers  ;  i++  )
        {
            address signer  =  handler.touched_signers_list( i );

            for(  uint256 j = 0  ;  j < num_keys  ;  j++  )
            {
                bytes32 key_b32  =  handler.touched_keys_list( j );

                InvariantHandler.GhostType ghost_t  =  handler.ghost_type( signer, key_b32 );
                if(  ghost_t == InvariantHandler.GhostType.NONE  )  continue;

                if(  ghost_t == InvariantHandler.GhostType.ADDRESS  )
                {
                    address expected  =  handler.ghost_address( signer, key_b32 );
                    address actual    =  chain_config.read_address( signer, key_b32 );
                    assertEq( actual, expected, "address ghost mismatch" );
                }
                else if(  ghost_t == InvariantHandler.GhostType.BYTES32  )
                {
                    bytes32 expected  =  handler.ghost_bytes32( signer, key_b32 );
                    bytes32 actual    =  chain_config.read_bytes32( signer, key_b32 );
                    assertEq( actual, expected, "bytes32 ghost mismatch" );
                }
                else if(  ghost_t == InvariantHandler.GhostType.UINT  )
                {
                    uint256 expected  =  handler.ghost_uint( signer, key_b32 );
                    uint256 actual    =  chain_config.read_uint( signer, key_b32 );
                    assertEq( actual, expected, "uint ghost mismatch" );
                }
            }
        }
    }

    /// @notice For every (signer, key, type) tracked, the bytes32-key read and the string-key
    ///         read must return the same value. This guards against any drift between the two
    ///         key-encoding paths.
    function invariant_string_and_bytes32_reads_agree( )
    external view
    {
        uint256 num_signers  =  handler.touched_signers_length( );
        uint256 num_keys     =  handler.touched_keys_length( );

        for(  uint256 i = 0  ;  i < num_signers  ;  i++  )
        {
            address signer  =  handler.touched_signers_list( i );

            for(  uint256 j = 0  ;  j < num_keys  ;  j++  )
            {
                bytes32 key_b32   =  handler.touched_keys_list( j );
                string memory key_s  =  _bytes32_to_string( key_b32 );

                InvariantHandler.GhostType ghost_t  =  handler.ghost_type( signer, key_b32 );
                if(  ghost_t == InvariantHandler.GhostType.NONE  )  continue;

                if(  ghost_t == InvariantHandler.GhostType.ADDRESS  )
                {
                    assertEq( chain_config.read_address( signer, key_b32 ), chain_config.read_address( signer, key_s ), "address read overloads disagree" );
                }
                else if(  ghost_t == InvariantHandler.GhostType.BYTES32  )
                {
                    assertEq( chain_config.read_bytes32( signer, key_b32 ), chain_config.read_bytes32( signer, key_s ), "bytes32 read overloads disagree" );
                }
                else if(  ghost_t == InvariantHandler.GhostType.UINT  )
                {
                    assertEq( chain_config.read_uint( signer, key_b32 ), chain_config.read_uint( signer, key_s ), "uint read overloads disagree" );
                }
            }
        }
    }

    /// @notice For every (signer, key) with a known ghost type, reads against the OTHER two
    ///         types must revert with KeyTypeMismatch. This proves only the current active type is readable.
    function invariant_only_ghost_type_succeeds_for_reads( )
    external view
    {
        uint256 num_signers  =  handler.touched_signers_length( );
        uint256 num_keys     =  handler.touched_keys_length( );

        for(  uint256 i = 0  ;  i < num_signers  ;  i++  )
        {
            address signer  =  handler.touched_signers_list( i );

            for(  uint256 j = 0  ;  j < num_keys  ;  j++  )
            {
                bytes32 key_b32  =  handler.touched_keys_list( j );

                InvariantHandler.GhostType ghost_t  =  handler.ghost_type( signer, key_b32 );
                if(  ghost_t == InvariantHandler.GhostType.NONE  )  continue;

                bool address_succeeds  =  _try_read_address( signer, key_b32 );
                bool bytes32_succeeds  =  _try_read_bytes32( signer, key_b32 );
                bool uint_succeeds     =  _try_read_uint( signer, key_b32 );

                if(  ghost_t == InvariantHandler.GhostType.ADDRESS  )
                {
                    assertTrue(  address_succeeds, "address read should have succeeded" );
                    assertEq(    bytes32_succeeds, false, "bytes32 read should have reverted" );
                    assertEq(    uint_succeeds,    false, "uint read should have reverted"    );
                }
                else if(  ghost_t == InvariantHandler.GhostType.BYTES32  )
                {
                    assertEq(    address_succeeds, false, "address read should have reverted" );
                    assertTrue(  bytes32_succeeds, "bytes32 read should have succeeded" );
                    assertEq(    uint_succeeds,    false, "uint read should have reverted"    );
                }
                else if(  ghost_t == InvariantHandler.GhostType.UINT  )
                {
                    assertEq(    address_succeeds, false, "address read should have reverted" );
                    assertEq(    bytes32_succeeds, false, "bytes32 read should have reverted" );
                    assertTrue(  uint_succeeds, "uint read should have succeeded" );
                }
            }
        }
    }


    // ━━━━  INTERNAL HELPERS  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    function _try_read_address( address signer, bytes32 key ) internal view returns ( bool success )
    {
        try chain_config.read_address( signer, key ) returns ( address )  { return true; }
        catch                                                              { return false; }
    }

    function _try_read_bytes32( address signer, bytes32 key ) internal view returns ( bool success )
    {
        try chain_config.read_bytes32( signer, key ) returns ( bytes32 )  { return true; }
        catch                                                              { return false; }
    }

    function _try_read_uint( address signer, bytes32 key ) internal view returns ( bool success )
    {
        try chain_config.read_uint( signer, key ) returns ( uint256 )  { return true; }
        catch                                                           { return false; }
    }

    function _bytes32_to_string( bytes32 key_b32 ) internal pure returns ( string memory )
    {
        uint256 len  =  0;
        while(  len < 32  &&  key_b32[ len ] != 0  )  len  =  len + 1;

        bytes memory out  =  new bytes( len );
        for(  uint256 i = 0  ;  i < len  ;  i++  )  out[ i ]  =  key_b32[ i ];

        return string( out );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity =0.8.35;


error EmptyKey( );
error KeyTooLong( string key, uint256 length );


string constant EIP712_DOMAIN_NAME     =  "ChainConfig";
string constant EIP712_DOMAIN_VERSION  =  "1";


struct AddressEntry {
    string key;
    address value;
}


struct Bytes32Entry {
    string key;
    bytes32 value;
}


struct UintEntry {
    string key;
    uint256 value;
}


struct Config {
    uint256 chain_id;  // *SECURITY*  -  Enforce payload creation and signing context consistency over the intended chain config.
    uint256 timestamp;  // *SECURITY*  -  Signer-attested config time; must increase per key and must not be greater than block.timestamp.
    AddressEntry[] addresses;
    Bytes32Entry[] bytes32s;
    UintEntry[] uints;
}


enum ValueType {
    NONE,  // Sentinel — key has never been written. Once a key is written with any other type, it can never become NONE again.
    ADDRESS,
    BYTES32,
    UINT
}


struct KeyMetadata {
    ValueType value_type;
    uint256 timestamp;
}

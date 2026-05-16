# ChainConfig

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

```
 ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗     ██████╗ ██████╗ ███╗   ██╗███████╗██╗ ██████╗
██╔════╝██║  ██║██╔══██╗██║████╗  ██║    ██╔════╝██╔═══██╗████╗  ██║██╔════╝██║██╔════╝
██║     ███████║███████║██║██╔██╗ ██║    ██║     ██║   ██║██╔██╗ ██║█████╗  ██║██║  ███╗
██║     ██╔══██║██╔══██║██║██║╚██╗██║    ██║     ██║   ██║██║╚██╗██║██╔══╝  ██║██║   ██║
╚██████╗██║  ██║██║  ██║██║██║ ╚████║    ╚██████╗╚██████╔╝██║ ╚████║██║     ██║╚██████╔╝
 ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝     ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     ╚═╝ ╚═════╝
━━━━━━━━━━━━━━━━━━━━━━  canonical chain-specific configuration  ━━━━━━━━━━━━━━━━━━━━━━
```

ChainConfig is a canonical EVM registry for typed, chain-specific constants.

Deploy it at the same address on every EVM-compatible chain. Then deploy downstream contracts with identical CREATE2 bytecode and let their constructors read local chain config from ChainConfig.

Result: same source, same init code, same CREATE2 salt, same downstream address, with explicit chain-local values such as `USDC_ADDRESS`.

> [!NOTE]
> **ChainConfig has not been audited by a major auditing firm.** It is designed to be small, immutable, and easy to inspect.

---

## TL;DR

**The problem:** Constructor arguments change CREATE2 init code. If a contract needs different USDC addresses per chain, passing those addresses into the constructor breaks same-address deployment.

**The solution:** Put chain-specific values in a canonical ChainConfig registry. Constructors read from the registry instead of receiving chain-specific constructor args.

- **Same init code everywhere:** no chain-specific constructor args.
- **Same downstream addresses:** normal CREATE2 works because init code stays fixed.
- **Canonical config:** many contracts can share the same chain constants.
- **Typed values:** `address`, `bytes32`, and `uint256`.
- **Readable signing:** EIP-712 payloads use string keys like `"USDC_ADDRESS"`.
- **Readable reads:** contracts can read with `bytes32("USDC_ADDRESS")`.
- **Constructor-time caching:** downstream contracts can store config as `immutable` and avoid later `SLOAD`s.
- **SecOps friendly:** chain id, type, key, value, and timestamp are explicit and auditable.
- **DAO compatible:** contracts can write directly or authorize relayed writes through EIP-1271.
- **Immutable primitive:** no owner, no admin keys, no upgrades.

---

## How It Works

1. Deploy `ChainConfig` at the same deterministic address on every chain.
2. A trusted namespace owner writes chain-specific config directly, or signs it for relaying.
3. Anyone can relay an authorized config with `write_config_as`.
4. Downstream constructors read typed values from the canonical registry.

```solidity
address usdc  =  ChainConfig(CHAIN_CONFIG).read_address(
    CONFIG_SIGNER,
    bytes32("USDC_ADDRESS")
);
```

The constructor call reads chain-local state. The constructor bytecode remains the same.

---

## Why ChainConfig

ChainConfig is not just an address trick. It is a deployment discipline.

Same-address systems should make chain-specific variation explicit. ChainConfig moves that variation into signed, typed, timestamped on-chain config, instead of hiding it inside per-chain deployment calldata.

**Security and ops advantages:**

- **Explicit chain intent:** config has `chain_id`, and EIP-712 also binds the signing domain to `chainId`.
- **Wrong-chain configs fail:** the contract rejects payloads where `config.chain_id != block.chainid`.
- **Direct DAO writes:** governance contracts can execute `write_config` and publish config under their own namespace.
- **Relayed authorization:** EOAs, Safes, DAOs, and other EIP-1271 contracts can authorize `write_config_as`.
- **No opaque key hashes:** consumers can use `bytes32("USDC_ADDRESS")`.
- **No type ambiguity:** a key has one active type at a time.
- **Replay ordering:** each signer/key has a monotonic timestamp.
- **Audit trail:** every key write emits a typed event: `AddressWritten`, `Bytes32Written`, or `UintWritten`.
- **Shared source of truth:** one registry can configure a whole deployment family.

---

## Config Shape

```solidity
struct Config {
    uint256 chain_id;
    uint256 timestamp;
    AddressEntry[] addresses;
    Bytes32Entry[] bytes32s;
    UintEntry[] uints;
}

struct AddressEntry {
    string key;
    address value;
}
```

Keys are signed as strings for wallet readability, but stored as `bytes32` keys. Keys must be non-empty and at most 32 bytes.

Use:

```solidity
bytes32("USDC_ADDRESS")
```

not an opaque hash.

---

## Signing Semantics

There are two write paths:

```solidity
write_config( Config calldata config )
write_config_as( Config calldata config, address signer, bytes calldata signature, bool is_eip1271 )
```

`write_config` writes under `msg.sender`. This is the direct path for EOAs, DAOs, timelocks, and contracts publishing their own config.

`write_config_as` writes under `signer`. Anyone can relay it, but only with valid signer authorization.

ChainConfig uses OpenZeppelin EIP-712 with:

```text
name:              ChainConfig
version:           1
chainId:           block.chainid
verifyingContract: ChainConfig address
```

The signed `Config` also includes `chain_id`.

This is intentional:

- `domain.chainId` binds the EIP-712 signature to the signing context.
- `config.chain_id` binds the operator-authored payload to the intended chain config.
- The contract requires `config.chain_id == block.chainid`.

That catches mismatches between payload creation and wallet signing context.

For `write_config_as`, authorization is checked with ECDSA for EOAs or EIP-1271 for contract signers. This lets a Safe, DAO, or timelock be the trusted config namespace without trusting the relayer.

Minimal ethers signing example:

```javascript
const domain = {
  name: "ChainConfig",
  version: "1",
  chainId,
  verifyingContract: CHAIN_CONFIG,
};

const types = {
  AddressEntry: [
    { name: "key", type: "string" },
    { name: "value", type: "address" },
  ],
  Bytes32Entry: [
    { name: "key", type: "string" },
    { name: "value", type: "bytes32" },
  ],
  UintEntry: [
    { name: "key", type: "string" },
    { name: "value", type: "uint256" },
  ],
  Config: [
    { name: "chain_id", type: "uint256" },
    { name: "timestamp", type: "uint256" },
    { name: "addresses", type: "AddressEntry[]" },
    { name: "bytes32s", type: "Bytes32Entry[]" },
    { name: "uints", type: "UintEntry[]" },
  ],
};

const config = {
  chain_id: chainId,
  timestamp: Math.floor(Date.now() / 1000) - 60,
  addresses: [{ key: "USDC_ADDRESS", value: USDC }],
  bytes32s: [],
  uints: [],
};

const signature = await signer.signTypedData(domain, types, config);
await chainConfig.write_config_as(config, await signer.getAddress(), signature, false);
```

`timestamp` is signer-attested config time. The contract enforces:

- it must not be greater than `block.timestamp`;
- it must increase per signer/key;
- it applies across all value types, so the same key cannot read as both an address and a uint at the same time.

---

## Read API

Each type has string and `bytes32` overloads:

```solidity
read_address( address signer, string calldata key ) returns ( address )
read_address( address signer, bytes32 key ) returns ( address )

read_bytes32( address signer, string calldata key ) returns ( bytes32 )
read_bytes32( address signer, bytes32 key ) returns ( bytes32 )

read_uint( address signer, string calldata key ) returns ( uint256 )
read_uint( address signer, bytes32 key ) returns ( uint256 )
```

Use string reads for scripts and inspection. Use `bytes32("KEY")` reads inside constructors.

---

## CREATE3 Comparison

CREATE3 is useful, but it solves a different problem.

CREATE3 can deploy a contract to the same final address even when the final init code differs. That means chain-specific constructor args can vary while the address stays the same.

That is powerful, but it creates deployment footguns:

- the same address does not prove the same init code was deployed;
- a wrong constructor argument can permanently occupy the canonical address;
- deployment scripts must enforce chain-specific args correctly on every chain;
- if constructor args become `immutable`, runtime bytecode can differ per chain;
- config intent may live only in deployment calldata, not in a reusable on-chain registry.

ChainConfig chooses the opposite tradeoff:

- downstream init code stays identical;
- chain-specific values are signed and stored before deployment;
- constructors read explicit config from canonical state;
- wrong-chain config signatures are rejected by the registry;
- many contracts can reuse the same audited config values.

CREATE3 preserves addresses despite different init code. ChainConfig preserves addresses by keeping init code the same and moving chain-specific facts into canonical signed state.

---

## Trust Model

ChainConfig does not decide what is true. The signer does.

Consumers must hardcode or otherwise deterministically choose:

- the canonical `ChainConfig` address;
- the trusted config signer;
- the expected key and type.

A signer namespace can be an EOA, a Safe, a DAO, a timelock, or any contract that writes directly or validates EIP-1271 signatures.

Anyone can relay a valid `write_config_as` signature. Relayers have no authority.

---

## Development

```bash
forge build
forge test
```

The test suite includes unit, fuzz, invariant, and reference-hash cross-checks across `ChainConfig`, `HashLib`, and `SignatureValidator`.

---

## Build & Verify

ChainConfig is designed for byte-identical reproducible builds. The canonical bytecode is determined by:

- **Solidity:** `=0.8.35` (pinned in source pragmas)
- **Compiler settings:** see `foundry.toml` (`via_ir = true`, `optimizer_runs = 1_000_000_000`, `evm_version = "london"`)

To reproduce, clone the repo and run `forge build`. The resulting init code hash must match:

```
0x645aea6490075d66530b3f76be94e7970ab0ebfa0328300879e73cf8d79bedbe
```

See `deploy/INSTRUCTIONS.md` for the canonical CREATE2 deployment at address `0x5Afec0de00EB1c5323C7faA110f67499F744467b`.

---

## License

MIT License. See [LICENSE](LICENSE).

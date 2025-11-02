# TinyDiamond: Minimal Selector Proxy for Smart Contracts

TinyDiamond is a minimalistic implementation of the Diamond Pattern (EIP-2535). It provides selector-based routing with access control in a lightweight, gas-efficient package.

Author: Martin Monperrus - mab.xyz

## Overview

The [Diamond Pattern (EIP-2535)](https://eips.ethereum.org/EIPS/eip-2535) uses a mapping to route function calls to different implementation contracts (called facets) based on their 4-byte function selectors. This allows you to:

- Split functionality across multiple specialized contracts
- Maintain a single entry point with a stable address
- Upgrade individual functions independently
- Bypass the 24KB contract size limit

### How It Works

1. When a function is called on the proxy, the `fallback()` function intercepts it
2. It extracts the function selector (first 4 bytes of calldata)
3. Looks up the target contract address for that selector
4. Optionally checks access restrictions
5. Delegates the call to the target contract using `delegatecall`

TinyDiamond implements the core Diamond principle—the essence, nothing more.

## Installation

```bash
# Using Foundry
forge install

# Run tests
forge test
```

## Core Interface

```solidity
interface ITinyDiamond {
    /**
     * @notice Set or update the target contract for a specific selector
     * To remove a selector, set the target address to address(0)
     * @param selector The function selector (4 bytes)
     * @param target The target contract address
     */
    function sharpCut(bytes4 selector, address target) external;

    /**
     * @notice Restrict access to a function to a specific authorized address
     * Set to address(0) to remove the restriction
     * @param selector The function selector (4 bytes)
     * @param target The address allowed to call this selector
     */
    function restrict(bytes4 selector, address target) external;
}
```

## Usage

### Basic Setup

```solidity
// Deploy TinyDiamond
TinyDiamond diamond = new TinyDiamond();

// Deploy your facet contracts
MyFacet facet1 = new MyFacet();
AnotherFacet facet2 = new AnotherFacet();

// Map function selectors to facets
diamond.sharpCut(MyFacet.myFunction.selector, address(facet1));
diamond.sharpCut(AnotherFacet.anotherFunction.selector, address(facet2));

// Call functions through the diamond
MyFacet(address(diamond)).myFunction();
AnotherFacet(address(diamond)).anotherFunction();
```

### Updating Functions

```solidity
// Deploy new implementation
MyFacetV2 facetV2 = new MyFacetV2();

// Update the selector mapping
diamond.sharpCut(MyFacet.myFunction.selector, address(facetV2));

// Calls now go to the new implementation
MyFacet(address(diamond)).myFunction(); // Uses facetV2
```

### Removing Functions

```solidity
// Remove a function by setting target to address(0)
diamond.sharpCut(MyFacet.myFunction.selector, address(0));

// Calls to this function will now revert
```

## Access Control

The contract deployer is automatically set as admin using the EIP-1967 admin slot. Only the admin can call `sharpCut()` and `restrict()`.

### Function-Level Restrictions

Restrict specific functions to authorized addresses:

- **Admin functions**: Create more admin functions than `sharpCut` and `restrict`
- **Integration control**: Restrict certain functions to authorized contracts

```solidity
// Restrict a function to a specific user
diamond.restrict(MyFacet.sensitiveFunction.selector, authorizedUser);

// Restrict a function to internal calls
diamond.restrict(MyFacet.sensitiveFunction.selector, address(diamond));

// Remove restriction, now anyone can call again
diamond.restrict(MyFacet.sensitiveFunction.selector, address(0));


```


## Security Considerations

### Critical: Facet Trust

**Facets have complete control over the diamond's storage via `delegatecall`.** A malicious facet can:

- Modify the admin address
- Change selector mappings and restrictions
- Access and modify all storage

**Always audit facets thoroughly before adding them to your diamond.**

### Admin Key Security

The admin has complete control over the diamond:

- Can add, update, or remove any function
- Can set or remove restrictions
- Admin address is stored in EIP-1967 slot for tooling compatibility

Protect the admin key with appropriate security measures (multisig, timelock, etc.).

### Selector Collisions

Be aware of potential selector collisions:

- Different function signatures can produce the same 4-byte selector (rare but possible)
- Always verify selectors before adding them
- Use `getTarget()` to check current mappings

## Comparison with EIP-2535

TinyDiamond implements the core concept of EIP-2535 but omits several features for simplicity:

| Feature | TinyDiamond | Full EIP-2535 |
|---------|-------------|---------------|
| Selector routing | ✅ | ✅ |
| `delegatecall` to facets | ✅ | ✅ |
| Simple function mapping | ✅ | ❌ |
| Batch updates (`diamondCut`) | ❌ | ✅ |
| Introspection (`IDiamondLoupe`) | ❌ | ✅ |
| Per-selector access control | ✅ | ❌ |
| Gas cost per call | Lower | Higher |

When to Use TinyDiamond:

- You want minimal gas overhead
- You want per-function access control
- You prefer simplicity
- You're prototyping or learning the pattern

When to Use Full EIP-2535:

- You need batch updates with initialization
- You want standardized introspection
- You require full EIP-2535 tooling compatibility
- You're building a complex system with many facets

## Future Enhancements

Possible sophistications that could be added:

- **Batch Updates**: Support the standard `diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata)` method
- **Introspection**: Implement `IDiamondLoupe` for querying facets and functions
- **Immutability**: Support sealing to prevent further modifications
- **Gas Limits**: Per-selector gas budgets
- **Events**: Enhanced event emission for better off-chain tracking
- **Storage Isolation**: Patterns to prevent facet storage collisions

## License

MIT


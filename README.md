# TinyDiamond: Selector Proxy for Smart Contracts.

The [Diamond Pattern (EIP-2535)](https://eips.ethereum.org/EIPS/eip-2535) uses a mapping to route function calls to different implementation contracts (called facets) based on their 4-byte function selectors, allowing you to split functionality across multiple specialized contracts while maintaining a single entry point. When a function is called, the diamond proxy uses `delegatecall` to forward the call to the appropriate target contract. This pattern individual functions to be upgraded or replaced independently. A diamond works as follows:

1. When a function is called on the proxy, the `fallback()` function intercepts it
2. It extracts the function selector (first 4 bytes of calldata)
3. Looks up the target contract address for that selector
4. Delegates the call to the target contract using `delegatecall`

TinyDiamond is the most simple implementation of the Diamond Pattern.

Author: mab.xyz

## Core Interface

A TinyDiamond has a simple method `sharpCut()`

```
interface ITinyDiamond {
    /**
     * @notice Set or update the target contract for a specific selector
     * To remove a selector, set the target address to address(0)
     * @param selector The function selector (4 bytes)
     * @param target The target contract address
     */
    function sharpCut(bytes4 selector, address target) external;
}
```

## Implementation 

`TinyDiamond` implements the core Diamond principle. The essence. Nothing more.

Possible sophistications: 
- support the more complex method `diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata)`
- support the introspection methods of `IDiamondLoupe`
- support sealing for sake of immutability
- support specific gas budget per selector


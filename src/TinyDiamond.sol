// SPDX-License-Identifier: MIT

interface ITinyDiamond {
    /**
     * @notice Set or update the target contract for a specific selector
     * To remove a selector, set the target address to address(0)
     * @param selector The function selector (4 bytes)
     * @param target The target contract address
     */
    function sharpCut(bytes4 selector, address target) external;
}
/**
 * @title SelectorProxy
 * @notice A proxy contract that routes function calls to different target contracts
 * based on function selectors (first 4 bytes of calldata)
 */
contract TinyDiamond is ITinyDiamond {
    event SelectorMappingUpdated(bytes4 indexed selector, address indexed oldTarget, address indexed newTarget);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    // Mapping from function selector to target contract address
    mapping(bytes4 => address) public selectorToFacet;
    
    
    function sharpCut(bytes4 selector, address target) external onlyAdmin {
        address oldTarget = selectorToFacet[selector];
        selectorToFacet[selector] = target;
        emit SelectorMappingUpdated(selector, oldTarget, target);
    }
    
    // keccak256("eip1967.proxy.admin") - 1
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    function admin() public view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin(), "SelectorProxy: caller is not admin");
        _;
    }
    
    constructor() {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, caller())
        }
    }
    
    /**
     * @notice Change the admin address
     * @param newAdmin The new admin address
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "SelectorProxy: new admin is zero address");
        address oldAdmin = admin();
        assembly {
            sstore(ADMIN_SLOT, newAdmin)
        }
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @notice Get the target contract for a specific selector
     * @param selector The function selector
     * @return target The target contract address
     */
    function getTarget(bytes4 selector) external view returns (address target) {
        return selectorToFacet[selector];
    }
    
    /**
     * @notice Fallback function that delegates calls to the appropriate target contract
     */
    fallback() external payable {
        bytes4 selector = msg.sig;
        address target = selectorToFacet[selector];
        
        require(target != address(0), "SelectorProxy: selector not found");
        
        // Delegate call to the target contract
        assembly {
            // Copy calldata to memory
            calldatacopy(0, 0, calldatasize())
            
            // Delegate call to target
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            
            // Copy return data to memory
            returndatacopy(0, 0, returndatasize())
            
            // Return or revert based on result
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
    
    /**
     * @notice Receive function to accept ETH
     */
    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Test facets for Diamond testing

contract TestFacet1 {
    event TestEvent1(string message);

    function function1() external pure returns (string memory) {
        return "function1";
    }

    function function2() external pure returns (uint256) {
        return 42;
    }

    function emitEvent1(string memory message) external {
        emit TestEvent1(message);
    }
}

contract TestFacet2 {
    event TestEvent2(uint256 value);

    function function3() external pure returns (bool) {
        return true;
    }

    function function4(uint256 value) external pure returns (uint256) {
        return value * 2;
    }

    function emitEvent2(uint256 value) external {
        emit TestEvent2(value);
    }
}

contract TestFacet3 {
    function function1() external pure returns (string memory) {
        return "facet3/function1";
    }
    function function5() external pure returns (address) {
        return address(0x123);
    }

    function function6(string memory str) external pure returns (string memory) {
        return string(abi.encodePacked("Hello, ", str));
    }
}

// Facet with a reverting function for testing
contract RevertFacet {
    error CustomError(string message);

    function revertingFunction() external pure {
        revert("Intentional revert");
    }

    function revertingFunctionWithCustomError() external pure {
        revert CustomError("Custom error message");
    }
}

// Initializer contract for testing diamond initialization
contract DiamondInit {
    event Initialized(string message, uint256 value);

    function init(string memory message, uint256 value) external {
        emit Initialized(message, value);
    }
}

// Initializer that reverts for testing
contract RevertInit {
    error InitializationFailed();

    function init() external pure {
        revert InitializationFailed();
    }
}

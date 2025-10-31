// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TinyDiamond.sol";
import "./TestFacets.sol";

contract TinyDiamondTest is Test {
    TinyDiamond public diamond;
    TestFacet1 public facet1;
    TestFacet2 public facet2;
    TestFacet3 public facet3;
    RevertFacet public revertFacet;

    address public admin;
    address public user;

    event SelectorMappingUpdated(bytes4 indexed selector, address indexed oldTarget, address indexed newTarget);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    function setUp() public {
        admin = address(this);
        user = address(0x1234);

        // Deploy diamond and facets
        diamond = new TinyDiamond();
        facet1 = new TestFacet1();
        facet2 = new TestFacet2();
        facet3 = new TestFacet3();
        revertFacet = new RevertFacet();
    }

    // ============ Constructor & Admin Tests ============

    function test_ConstructorSetsAdmin() public view {
        assertEq(diamond.admin(), admin, "Admin should be set to deployer");
    }

    function test_AdminSlotMatchesEIP1967() public view {
        // keccak256("eip1967.proxy.admin") - 1
        bytes32 expectedSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 actualSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        assertEq(actualSlot, expectedSlot, "Admin slot should match EIP-1967");
    }

    // ============ sharpCut Tests ============

    function test_SharpCut_AddNewSelector() public {
        bytes4 selector = TestFacet1.function1.selector;

        vm.expectEmit(true, true, true, true);
        emit SelectorMappingUpdated(selector, address(0), address(facet1));

        diamond.sharpCut(selector, address(facet1));

        assertEq(diamond.selectorToFacet(selector), address(facet1), "Selector should map to facet1");
        assertEq(diamond.getTarget(selector), address(facet1), "getTarget should return facet1");
    }

    function test_SharpCut_UpdateExistingSelector() public {
        bytes4 selector = TestFacet1.function1.selector;

        // First add
        diamond.sharpCut(selector, address(facet1));

        // Then update
        vm.expectEmit(true, true, true, true);
        emit SelectorMappingUpdated(selector, address(facet1), address(facet3));

        diamond.sharpCut(selector, address(facet3));

        assertEq(diamond.selectorToFacet(selector), address(facet3), "Selector should now map to facet3");
    }

    function test_SharpCut_RemoveSelector() public {
        bytes4 selector = TestFacet1.function1.selector;

        // First add
        diamond.sharpCut(selector, address(facet1));

        // Then remove by setting to address(0)
        vm.expectEmit(true, true, true, true);
        emit SelectorMappingUpdated(selector, address(facet1), address(0));

        diamond.sharpCut(selector, address(0));

        assertEq(diamond.selectorToFacet(selector), address(0), "Selector should be removed");
    }

    function test_SharpCut_OnlyAdmin() public {
        bytes4 selector = TestFacet1.function1.selector;

        vm.prank(user);
        vm.expectRevert("SelectorProxy: caller is not admin");
        diamond.sharpCut(selector, address(facet1));
    }

    function test_SharpCut_MultipleSelectors() public {
        bytes4 selector1 = TestFacet1.function1.selector;
        bytes4 selector2 = TestFacet1.function2.selector;
        bytes4 selector3 = TestFacet2.function3.selector;

        diamond.sharpCut(selector1, address(facet1));
        diamond.sharpCut(selector2, address(facet1));
        diamond.sharpCut(selector3, address(facet2));

        assertEq(diamond.selectorToFacet(selector1), address(facet1));
        assertEq(diamond.selectorToFacet(selector2), address(facet1));
        assertEq(diamond.selectorToFacet(selector3), address(facet2));
    }

    // ============ changeAdmin Tests ============

    function test_ChangeAdmin_Success() public {
        address newAdmin = address(0x5678);

        vm.expectEmit(true, true, false, false);
        emit AdminChanged(admin, newAdmin);

        diamond.changeAdmin(newAdmin);

        assertEq(diamond.admin(), newAdmin, "Admin should be updated");
    }

    function test_ChangeAdmin_OnlyAdmin() public {
        address newAdmin = address(0x5678);

        vm.prank(user);
        vm.expectRevert("SelectorProxy: caller is not admin");
        diamond.changeAdmin(newAdmin);
    }

    function test_ChangeAdmin_RevertZeroAddress() public {
        vm.expectRevert("SelectorProxy: new admin is zero address");
        diamond.changeAdmin(address(0));
    }

    function test_ChangeAdmin_NewAdminCanManage() public {
        address newAdmin = address(0x5678);
        bytes4 selector = TestFacet1.function1.selector;

        // Change admin
        diamond.changeAdmin(newAdmin);

        // Old admin cannot manage
        vm.expectRevert("SelectorProxy: caller is not admin");
        diamond.sharpCut(selector, address(facet1));

        // New admin can manage
        vm.prank(newAdmin);
        diamond.sharpCut(selector, address(facet1));

        assertEq(diamond.selectorToFacet(selector), address(facet1));
    }

    // ============ getTarget Tests ============

    function test_GetTarget_ReturnsCorrectTarget() public {
        bytes4 selector = TestFacet1.function1.selector;

        diamond.sharpCut(selector, address(facet1));

        assertEq(diamond.getTarget(selector), address(facet1));
    }

    function test_GetTarget_ReturnsZeroForUnsetSelector() public view {
        bytes4 selector = bytes4(keccak256("nonexistent()"));

        assertEq(diamond.getTarget(selector), address(0));
    }

    // ============ Fallback/Delegation Tests ============

    function test_Fallback_DelegateCallReturnsValue() public {
        bytes4 selector = TestFacet1.function1.selector;
        diamond.sharpCut(selector, address(facet1));

        // Call through diamond
        (bool success, bytes memory result) = address(diamond).call(
            abi.encodeWithSelector(selector)
        );

        assertTrue(success, "Call should succeed");
        assertEq(abi.decode(result, (string)), "function1", "Should return correct value");
    }

    function test_Fallback_DelegateCallWithParameters() public {
        bytes4 selector = TestFacet2.function4.selector;
        diamond.sharpCut(selector, address(facet2));

        uint256 inputValue = 21;
        (bool success, bytes memory result) = address(diamond).call(
            abi.encodeWithSelector(selector, inputValue)
        );

        assertTrue(success, "Call should succeed");
        assertEq(abi.decode(result, (uint256)), 42, "Should return value * 2");
    }

    function test_Fallback_DelegateCallWithStringParameter() public {
        bytes4 selector = TestFacet3.function6.selector;
        diamond.sharpCut(selector, address(facet3));

        string memory input = "World";
        (bool success, bytes memory result) = address(diamond).call(
            abi.encodeWithSelector(selector, input)
        );

        assertTrue(success, "Call should succeed");
        assertEq(abi.decode(result, (string)), "Hello, World", "Should concatenate strings");
    }

    function test_Fallback_RevertWhenSelectorNotFound() public {
        bytes4 selector = TestFacet1.function1.selector;
        // Don't set selector mapping

        vm.expectRevert("SelectorProxy: selector not found");
        address(diamond).call(abi.encodeWithSelector(selector));
    }

    function test_Fallback_PropagatesRevertFromTarget() public {
        bytes4 selector = RevertFacet.revertingFunction.selector;
        diamond.sharpCut(selector, address(revertFacet));

        vm.expectRevert("Intentional revert");
        address(diamond).call(abi.encodeWithSelector(selector));
    }

    function test_Fallback_PropagatesCustomErrorFromTarget() public {
        bytes4 selector = RevertFacet.revertingFunctionWithCustomError.selector;
        diamond.sharpCut(selector, address(revertFacet));

        vm.expectRevert(
            abi.encodeWithSelector(RevertFacet.CustomError.selector, "Custom error message")
        );
        address(diamond).call(abi.encodeWithSelector(selector));
    }

    function test_Fallback_MultipleFacetInteraction() public {
        // Set up multiple facets
        diamond.sharpCut(TestFacet1.function1.selector, address(facet1));
        diamond.sharpCut(TestFacet1.function2.selector, address(facet1));
        diamond.sharpCut(TestFacet2.function3.selector, address(facet2));

        // Call function1
        (bool success1, bytes memory result1) = address(diamond).call(
            abi.encodeWithSelector(TestFacet1.function1.selector)
        );
        assertTrue(success1);
        assertEq(abi.decode(result1, (string)), "function1");

        // Call function2
        (bool success2, bytes memory result2) = address(diamond).call(
            abi.encodeWithSelector(TestFacet1.function2.selector)
        );
        assertTrue(success2);
        assertEq(abi.decode(result2, (uint256)), 42);

        // Call function3
        (bool success3, bytes memory result3) = address(diamond).call(
            abi.encodeWithSelector(TestFacet2.function3.selector)
        );
        assertTrue(success3);
        assertEq(abi.decode(result3, (bool)), true);
    }

    function test_Fallback_SelectorOverride() public {
        bytes4 selector = TestFacet1.function1.selector;

        // First set to facet1
        diamond.sharpCut(selector, address(facet1));

        (bool success1, bytes memory result1) = address(diamond).call(
            abi.encodeWithSelector(selector)
        );
        assertTrue(success1);
        assertEq(abi.decode(result1, (string)), "function1");

        // Override with facet3 (which has different implementation)
        diamond.sharpCut(selector, address(facet3));

        (bool success2, bytes memory result2) = address(diamond).call(
            abi.encodeWithSelector(selector)
        );
        assertTrue(success2);
        assertEq(abi.decode(result2, (string)), "facet3/function1");
    }

    // ============ Receive Function Tests ============

    function test_Receive_AcceptsEther() public {
        uint256 amount = 1 ether;

        (bool success,) = address(diamond).call{value: amount}("");

        assertTrue(success, "Should accept ether");
        assertEq(address(diamond).balance, amount, "Balance should be updated");
    }

    function test_Receive_MultipleDeposits() public {
        uint256 amount1 = 1 ether;
        uint256 amount2 = 2 ether;

        (bool success1,) = address(diamond).call{value: amount1}("");
        (bool success2,) = address(diamond).call{value: amount2}("");

        assertTrue(success1 && success2, "Should accept multiple deposits");
        assertEq(address(diamond).balance, amount1 + amount2, "Balance should accumulate");
    }

    // ============ Edge Cases & Security Tests ============

    function test_EdgeCase_SameTargetMultipleSelectors() public {
        bytes4 selector1 = TestFacet1.function1.selector;
        bytes4 selector2 = TestFacet1.function2.selector;

        diamond.sharpCut(selector1, address(facet1));
        diamond.sharpCut(selector2, address(facet1));

        assertEq(diamond.selectorToFacet(selector1), address(facet1));
        assertEq(diamond.selectorToFacet(selector2), address(facet1));
    }

    function test_EdgeCase_RemoveAndReAdd() public {
        bytes4 selector = TestFacet1.function1.selector;

        // Add
        diamond.sharpCut(selector, address(facet1));
        assertEq(diamond.selectorToFacet(selector), address(facet1));

        // Remove
        diamond.sharpCut(selector, address(0));
        assertEq(diamond.selectorToFacet(selector), address(0));

        // Re-add
        diamond.sharpCut(selector, address(facet1));
        assertEq(diamond.selectorToFacet(selector), address(facet1));
    }

    function test_Security_CannotCallAdminFunctionsThroughFallback() public {
        // Even if we try to set sharpCut selector, it shouldn't work
        // because sharpCut is a direct function, not delegated
        bytes4 sharpCutSelector = ITinyDiamond.sharpCut.selector;

        // This should fail because sharpCut requires admin
        vm.prank(user);
        vm.expectRevert("SelectorProxy: caller is not admin");
        diamond.sharpCut(sharpCutSelector, address(facet1));
    }

    function test_Security_DelegateCallCanChangeAdmin() public {
        // WARNING: This test demonstrates a security risk!
        // Delegatecall allows facets to modify the diamond's storage.
        // This is why you must only add trusted facets to the diamond.

        MaliciousFacet malicious = new MaliciousFacet();
        bytes4 selector = MaliciousFacet.tryToChangeAdmin.selector;

        diamond.sharpCut(selector, address(malicious));

        address adminBefore = diamond.admin();

        // Call through diamond - this WILL change the admin
        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(selector, user)
        );

        // The call succeeds and admin DOES change via delegatecall
        // This demonstrates why facets must be carefully vetted
        assertTrue(success);
        assertEq(diamond.admin(), user, "Admin was changed by delegatecall");
    }

    // ============ Fuzz Tests ============

    function testFuzz_SharpCut_ArbitrarySelectors(bytes4 selector, address target) public {
        vm.assume(target != address(0)); // Avoid testing removal in this fuzz test

        diamond.sharpCut(selector, target);
        assertEq(diamond.selectorToFacet(selector), target);
    }

    function testFuzz_ChangeAdmin_ArbitraryAddress(address newAdmin) public {
        vm.assume(newAdmin != address(0));

        diamond.changeAdmin(newAdmin);
        assertEq(diamond.admin(), newAdmin);
    }

    function testFuzz_Receive_ArbitraryAmounts(uint256 amount) public {
        vm.assume(amount <= address(this).balance);

        (bool success,) = address(diamond).call{value: amount}("");
        assertTrue(success);
        assertEq(address(diamond).balance, amount);
    }
}

// Helper contract for security testing
contract MaliciousFacet {
    bytes32 private constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function tryToChangeAdmin(address newAdmin) external {
        assembly {
            sstore(ADMIN_SLOT, newAdmin)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/SimpleMockFactory.sol";
import "../src/NewTokenPairSpamTrap.sol";
import "../src/ResponseContract.sol";

/**
 * @title DeployAll
 * @notice Complete deployment script for the trap system
 * @dev Deploys: MockFactory → ResponseContract → Trap (with factory address)
 */
contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy Mock Factory
        SimpleMockFactory factory = new SimpleMockFactory();
        console.log("==============================================");
        console.log("SimpleMockFactory deployed at:");
        console.log(address(factory));
        console.log("==============================================");

        // Step 2: Deploy ResponseContract
        ResponseContract responseContract = new ResponseContract();
        console.log("ResponseContract deployed at:");
        console.log(address(responseContract));
        console.log("==============================================");

        // Step 3: Deploy Trap
        // NOTE: You MUST update FACTORY constant in NewTokenPairSpamTrap.sol
        //       with the factory address printed above before deploying trap
        NewTokenPairSpamTrap trap = new NewTokenPairSpamTrap();
        console.log("NewTokenPairSpamTrap deployed at:");
        console.log(address(trap));
        console.log("==============================================");

        console.log("");
        console.log("Deployment Summary:");
        console.log("---");
        console.log("MockFactory:", address(factory));
        console.log("ResponseContract:", address(responseContract));
        console.log("Trap:", address(trap));
        console.log("---");
        console.log("");
        console.log("NEXT STEPS:");
        console.log("1. Update NewTokenPairSpamTrap.sol line 30:");
        console.log(
            "   address public constant FACTORY =",
            address(factory),
            ";"
        );
        console.log("");
        console.log("2. Rebuild: forge build");
        console.log("");
        console.log("3. Update drosera.toml:");
        console.log(
            "   response_contract =",
            vm.toString(address(responseContract))
        );
        console.log("");
        console.log("4. Test spam detection:");
        console.log(
            "   cast send",
            address(factory),
            '"batchCreatePairs(uint256)" 150 --rpc-url $HOODI_RPC_URL --private-key $PRIVATE_KEY'
        );
        console.log("==============================================");

        vm.stopBroadcast();
    }
}

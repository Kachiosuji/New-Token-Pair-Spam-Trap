// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/NewTokenPairSpamTrap.sol";
import "../src/ResponseContract.sol";

/**
 * @title Deploy
 * @notice Deployment script for NewTokenPairSpamTrap and ResponseContract
 * @dev This script deploys both contracts to the Hoodi testnet
 */
contract Deploy is Script {
    function run() external {
        // Get the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ResponseContract first
        ResponseContract responseContract = new ResponseContract();
        console.log("==============================================");
        console.log("ResponseContract deployed at:");
        console.log(address(responseContract));
        console.log("==============================================");

        // Deploy NewTokenPairSpamTrap
        NewTokenPairSpamTrap trap = new NewTokenPairSpamTrap();
        console.log("NewTokenPairSpamTrap deployed at:");
        console.log(address(trap));
        console.log("==============================================");

        // Optional: Set initial values for testing
        // Uncomment the following lines if you want to set initial values during deployment
        // trap.setInitialPairCount(50);
        // trap.updateSimulatedCount(50);

        console.log("Deployment Summary:");
        console.log("---");
        console.log("ResponseContract:", address(responseContract));
        console.log("NewTokenPairSpamTrap:", address(trap));
        console.log("---");
        console.log("Initial Pair Count:", trap.initialPairCount());
        console.log("Simulated Pair Count:", trap.simulatedPairCount());
        console.log("Safety Threshold:", trap.SAFETY_THRESHOLD());
        console.log("==============================================");
        console.log("");
        console.log(
            "IMPORTANT: Update the RESPONSE_CONTRACT address in NewTokenPairSpamTrap.sol"
        );
        console.log("with the deployed ResponseContract address:");
        console.log(address(responseContract));
        console.log("");
        console.log("Then update the drosera.toml file with:");
        console.log(
            "- response_contract =",
            vm.toString(address(responseContract))
        );
        console.log('- response_function = "alertSpamDetection(uint256)"');
        console.log("==============================================");

        vm.stopBroadcast();
    }
}

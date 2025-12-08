// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ITrap
 * @notice Official Drosera Trap interface
 * @dev Minimal interface for Drosera v2.0 compatibility
 */
interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(
        bytes[] calldata data
    ) external pure returns (bool, bytes memory);
}

/**
 * @title IUniV2Factory
 * @notice UniswapV2-style factory interface
 * @dev Used to read pair count from factory contracts
 */
interface IUniV2Factory {
    function allPairsLength() external view returns (uint256);
}

/**
 * @title NewTokenPairSpamTrap
 * @notice Drosera trap that detects rapid pair creation on DEX factories
 * @dev Monitors factory pair count and triggers when growth exceeds threshold
 *      Uses official ITrap interface and reads real on-chain factory data
 */
contract NewTokenPairSpamTrap is ITrap {
    // Factory to monitor (SimpleMockFactory deployed on Hoodi testnet)
    address public constant FACTORY = 0xe4Ec2cdC6c312dA357abC40aBC47A5FE16aEa902; // UPDATE AFTER DEPLOYING SimpleMockFactory

    // Maximum new pairs allowed within the monitoring window
    uint256 public constant SAFETY_THRESHOLD = 100;

    /**
     * @notice Collects current factory state
     * @dev Reads pair count from factory and returns with block number
     *      This is a view function with no external dependencies beyond the factory read
     * @return Encoded data containing (pairCount, blockNumber)
     */
    function collect() external view override returns (bytes memory) {
        uint256 count = 0;

        // Read from factory with try-catch for safety
        try IUniV2Factory(FACTORY).allPairsLength() returns (uint256 c) {
            count = c;
        } catch {
            // If factory call fails, return 0 (trap won't trigger on error)
        }
        return abi.encode(count, block.number);
    }

    /**
     * @notice Determines if spam condition is met
     * @dev Compares newest sample vs previous and triggers if delta > threshold
     *      Pure function - no state reads, fully deterministic
     * @param data Array of encoded samples from collect() - data[0] is newest, data[1] is previous
     * @return shouldTrigger True if spam detected
     * @return payload Encoded alert data (newest count, delta, blockNumber)
     */
    function shouldRespond(
        bytes[] calldata data
    )
        external
        pure
        override
        returns (bool shouldTrigger, bytes memory payload)
    {
        // Planner-safety: check we have at least 2 samples and they're not empty
        if (data.length < 2 || data[0].length == 0 || data[1].length == 0) {
            return (false, "");
        }

        // Decode newest and previous samples
        (uint256 newestCount, uint256 newestBlock) = abi.decode(
            data[0],
            (uint256, uint256)
        );
        (uint256 previousCount, ) = abi.decode(data[1], (uint256, uint256));

        // Calculate new pairs created between samples
        uint256 delta = newestCount > previousCount
            ? newestCount - previousCount
            : 0;

        // Trigger if delta exceeds threshold
        if (delta > SAFETY_THRESHOLD) {
            return (true, abi.encode(newestCount, delta, newestBlock));
        }

        return (false, "");
    }
}

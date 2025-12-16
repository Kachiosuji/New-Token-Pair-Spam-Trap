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
    address public constant FACTORY =
        0xe4Ec2cdC6c312dA357abC40aBC47A5FE16aEa902;

    // Maximum new pairs allowed within the monitoring window
    uint256 public constant SAFETY_THRESHOLD = 100;

    /**
     * @notice Collects current factory state
     * @dev Reads pair count from factory and returns with block number and validity flag
     *      This is a view function with no external dependencies beyond the factory read
     * @return Encoded data containing (pairCount, blockNumber, success)
     */
    function collect() external view override returns (bytes memory) {
        uint256 count = 0;
        bool success = false;

        // Read from factory with try-catch for safety
        try IUniV2Factory(FACTORY).allPairsLength() returns (uint256 c) {
            count = c;
            success = true;
        } catch {
            // If factory call fails, success remains false
        }
        return abi.encode(count, block.number, success);
    }

    /**
     * @notice Determines if spam condition is met
     * @dev Compares newest sample vs previous and triggers if pairs-per-block rate > threshold
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

        // Decode newest and previous samples with validity flags
        (uint256 newestCount, uint256 newestBlock, bool newestOk) = abi.decode(
            data[0],
            (uint256, uint256, bool)
        );
        (uint256 previousCount, uint256 previousBlock, bool previousOk) = abi
            .decode(data[1], (uint256, uint256, bool));

        // Skip if either sample is invalid
        if (!newestOk || !previousOk) {
            return (false, "");
        }

        // Calculate new pairs created between samples
        uint256 delta = newestCount > previousCount
            ? newestCount - previousCount
            : 0;

        // Calculate block difference (prevent division by zero)
        uint256 blockDiff = newestBlock > previousBlock
            ? newestBlock - previousBlock
            : 1;

        // Calculate pairs per block rate
        uint256 pairsPerBlock = delta / blockDiff;

        // Trigger if pairs-per-block rate exceeds threshold
        // This prevents gaming by spreading pairs across blocks
        if (pairsPerBlock > SAFETY_THRESHOLD) {
            return (true, abi.encode(newestCount, delta, newestBlock));
        }

        return (false, "");
    }
}

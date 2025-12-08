// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SimpleMockFactory
 * @notice A minimal mock factory contract for testing pair creation spam detection
 * @dev Implements the UniswapV2 factory interface (allPairsLength) for trap testing
 *      This is a mock for demonstration - can be replaced with a real factory address
 */
contract SimpleMockFactory {
    uint256 private pairCount;
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    
    /**
     * @notice Simulates creating a new pair
     * @dev Increments the pair count to simulate factory pair creation
     */
    function createPair() external {
        pairCount++;
        emit PairCreated(address(0), address(0), address(0), pairCount);
    }
    
    /**
     * @notice Returns the total number of pairs created
     * @dev This is the standard UniswapV2 factory interface that traps monitor
     * @return The total number of pairs
     */
    function allPairsLength() external view returns (uint256) {
        return pairCount;
    }
    
    /**
     * @notice Batch create multiple pairs (for testing spam scenarios)
     * @param count Number of pairs to create
     */
    function batchCreatePairs(uint256 count) external {
        for (uint256 i = 0; i < count; i++) {
            pairCount++;
            emit PairCreated(address(0), address(0), address(0), pairCount);
        }
    }
}
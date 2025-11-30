// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct EventLog {
    // The topics of the log, including the signature, if any.
    bytes32[] topics;
    // The raw data of the log.
    bytes data;
    // The address of the log's emitter.
    address emitter;
}

struct EventFilter {
    // The address of the contract to filter logs from.
    address contractAddress;
    // The topics to filter logs by.
    string signature;
}

abstract contract Trap {
    EventLog[] private eventLogs;

    function collect() external view virtual returns (bytes memory);

    function shouldRespond(
        bytes[] calldata data
    ) external pure virtual returns (bool, bytes memory);

    function shouldAlert(
        bytes[] calldata data
    ) external pure virtual returns (bool, bytes memory);

    function eventLogFilters() public view virtual returns (EventFilter[] memory) {
        EventFilter[] memory filters = new EventFilter[](0);
        return filters;
    }

    function version() public pure returns (string memory) {
        return "2.0";
    }

    function setEventLogs(EventLog[] calldata logs) public {
        EventLog[] storage storageArray = eventLogs;

        // Set new logs
        for (uint256 i = 0; i < logs.length; i++) {
            storageArray.push(EventLog({
                emitter: logs[i].emitter,
                topics: logs[i].topics,
                data: logs[i].data
            }));
        }
    }

    function getEventLogs() public view returns (EventLog[] memory) {
        EventLog[] storage storageArray = eventLogs;
        EventLog[] memory logs = new EventLog[](storageArray.length);

        for (uint256 i = 0; i < storageArray.length; i++) {
            logs[i] = EventLog({
                emitter: storageArray[i].emitter,
                topics: storageArray[i].topics,
                data: storageArray[i].data
            });
        }
        return logs;
    }
}

/**
 * @title NewTokenPairSpamTrap
 * @notice A Drosera Network security trap that detects "New Token Pair Spam" attacks
 * @dev This trap monitors a simulated factory by tracking pair creation count
 *      and triggers when the number of new pairs exceeds a safety threshold
 */
contract NewTokenPairSpamTrap is Trap {
    // State variables
    uint256 public initialPairCount;      // Baseline pair count at initialization
    uint256 public simulatedPairCount;    // Current simulated pair count
    uint256 public constant SAFETY_THRESHOLD = 100; // Maximum allowed new pairs
    address public owner;                 // Contract owner for updates

    // Hardcoded response contract address (will be updated after deployment)
    address private constant RESPONSE_CONTRACT = address(0x4582470e4071E61fe4FED4f49F5F47bEcbAD89e8);
    
    // Events
    event PairCountUpdated(uint256 newCount);
    event TrapTriggered(uint256 initialCount, uint256 currentCount, uint256 difference);

    /**
     * @notice Constructor - empty to pass Drosera operator dry-run simulations
     */
    constructor() {
        owner = msg.sender;
        initialPairCount = 0;
        simulatedPairCount = 0;
    }

    /**
     * @notice Modifier to restrict access to owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @notice Updates the simulated pair count for testing purposes
     * @param _newCount The new simulated pair count to set
     */
    function updateSimulatedCount(uint256 _newCount) external onlyOwner {
        simulatedPairCount = _newCount;
        emit PairCountUpdated(_newCount);
    }

    /**
     * @notice Sets the initial baseline pair count
     * @param _initialCount The baseline pair count to set
     */
    function setInitialPairCount(uint256 _initialCount) external onlyOwner {
        initialPairCount = _initialCount;
    }

    /**
     * @notice Collects current state data from the contract
     * @dev This is a view function that reads internal state variables only
     *      No external network calls are made to ensure Drosera operator compatibility
     * @return Encoded data containing initialPairCount and simulatedPairCount
     */
    function collect() external view override returns (bytes memory) {
        // Return encoded state variables for analysis
        return abi.encode(initialPairCount, simulatedPairCount);
    }

    /**
     * @notice Determines if the trap should trigger a response based on collected data
     * @dev Pure function that decodes data and checks if new pair count exceeds threshold
     * @param data Array of encoded data from previous collect() calls (newest first)
     * @return shouldTrigger True if the trap should respond, false otherwise
     * @return payload Encoded data to pass to the response contract
     */
    function shouldRespond(
        bytes[] calldata data
    ) external pure override returns (bool shouldTrigger, bytes memory payload) {
        // Decode the most recent data (first element in array)
        if (data.length == 0) {
            return (false, abi.encode(""));
        }

        (uint256 initial, uint256 current) = abi.decode(data[0], (uint256, uint256));
        
        // Calculate the difference (number of new pairs)
        uint256 newPairs = current > initial ? current - initial : 0;

        // Check if difference exceeds the safety threshold
        if (newPairs > SAFETY_THRESHOLD) {
            // Trigger response and pass the current pair count
            return (true, abi.encode(current));
        }

        return (false, abi.encode(""));
    }

    /**
     * @notice Alert function for notifications (optional implementation)
     * @param data Array of encoded data from previous collect() calls
     * @return shouldTrigger True if alert should be sent
     * @return payload Encoded alert data
     */
    function shouldAlert(
        bytes[] calldata data
    ) external pure override returns (bool shouldTrigger, bytes memory payload) {
        // Same logic as shouldRespond for alerts
        if (data.length == 0) {
            return (false, abi.encode(""));
        }

        (uint256 initial, uint256 current) = abi.decode(data[0], (uint256, uint256));
        uint256 newPairs = current > initial ? current - initial : 0;

        if (newPairs > SAFETY_THRESHOLD) {
            return (true, abi.encode(current, newPairs));
        }

        return (false, abi.encode(""));
    }

    /**
     * @notice Returns the response contract address
     * @return The address of the response contract
     */
    function getResponseContract() external pure returns (address) {
        return RESPONSE_CONTRACT;
    }

    /**
     * @notice Returns the response function signature
     * @return The function signature to call on the response contract
     */
    function getResponseFunction() external pure returns (string memory) {
        return "alertSpamDetection(uint256)";
    }

    /**
     * @notice Returns the response function arguments (placeholder)
     * @return Empty bytes as arguments are passed via shouldRespond payload
     */
    function getResponseArguments() external pure returns (bytes memory) {
        return abi.encode("");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ResponseContract
 * @notice Contract that receives alerts from the NewTokenPairSpamTrap
 * @dev This contract is called by Drosera operators when the trap is triggered
 */
contract ResponseContract {
    // Events
    event SpamDetectionAlert(
        uint256 indexed pairCount,
        uint256 timestamp,
        address indexed triggeredBy
    );
    event EmergencyAction(
        uint256 indexed pairCount,
        string action,
        uint256 timestamp
    );

    // State variables
    address public owner;
    uint256 public totalAlertsReceived;
    uint256 public lastAlertTimestamp;
    uint256 public lastAlertPairCount;
    uint256 public lastAlertDelta;
    uint256 public lastAlertBlock;

    // Mapping to track alert history
    mapping(uint256 => Alert) public alertHistory;

    struct Alert {
        uint256 pairCount;
        uint256 delta;
        uint256 sampleBlock;
        uint256 timestamp;
        address triggeredBy;
        bool processed;
    }

    /**
     * @notice Constructor
     */
    constructor() {
        owner = msg.sender;
        totalAlertsReceived = 0;
    }

    /**
     * @notice Modifier to restrict access to owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @notice Main response function called by Drosera operators when trap triggers
     * @param _pairCount The current pair count that triggered the spam detection
     * @param _delta The number of new pairs created since previous sample
     * @param _sampleBlock The block number of the sample that triggered
     */
    function alertSpamDetection(uint256 _pairCount, uint256 _delta, uint256 _sampleBlock) external {
        // Record the alert
        totalAlertsReceived++;
        lastAlertTimestamp = block.timestamp;
        lastAlertPairCount = _pairCount;
        lastAlertDelta = _delta;
        lastAlertBlock = _sampleBlock;

        // Store alert in history
        alertHistory[totalAlertsReceived] = Alert({
            pairCount: _pairCount,
            delta: _delta,
            sampleBlock: _sampleBlock,
            timestamp: block.timestamp,
            triggeredBy: msg.sender,
            processed: false
        });

        // Emit event for monitoring systems
        emit SpamDetectionAlert(_pairCount, block.timestamp, msg.sender);
        emit EmergencyAction(
            _pairCount,
            "New Token Pair Spam Detected",
            block.timestamp
        );
    }

    /**
     * @notice Manually mark an alert as processed
     * @param _alertId The ID of the alert to mark as processed
     */
    function markAlertProcessed(uint256 _alertId) external onlyOwner {
        require(
            _alertId > 0 && _alertId <= totalAlertsReceived,
            "Invalid alert ID"
        );
        require(!alertHistory[_alertId].processed, "Alert already processed");

        alertHistory[_alertId].processed = true;
    }

    /**
     * @notice Get alert details by ID
     * @param _alertId The ID of the alert to retrieve
     * @return Alert struct containing alert details
     */
    function getAlert(uint256 _alertId) external view returns (Alert memory) {
        require(
            _alertId > 0 && _alertId <= totalAlertsReceived,
            "Invalid alert ID"
        );
        return alertHistory[_alertId];
    }

    /**
     * @notice Get the latest alert information
     * @return pairCount The pair count from the last alert
     * @return timestamp The timestamp of the last alert
     * @return triggeredBy The address that triggered the last alert
     */
    function getLastAlert()
        external
        view
        returns (uint256 pairCount, uint256 timestamp, address triggeredBy)
    {
        if (totalAlertsReceived > 0) {
            Alert memory lastAlert = alertHistory[totalAlertsReceived];
            return (
                lastAlert.pairCount,
                lastAlert.timestamp,
                lastAlert.triggeredBy
            );
        }
        return (0, 0, address(0));
    }

    /**
     * @notice Get total number of alerts received
     * @return Total count of alerts
     */
    function getTotalAlerts() external view returns (uint256) {
        return totalAlertsReceived;
    }
}

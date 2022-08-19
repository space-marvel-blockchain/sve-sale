// SPDX-License-Identifier: MIT
/*
Unlock over 60 months							
*/
pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SVETeamAdvisorClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public SVE;

    uint256 public FULL_LOCK = 86400 * 30 * 12; //12 months
    uint256 public VESTING_DURATION = 86400 * 30 * 36; //36 months

    uint256 public startTime;
    uint256 public endTime;

    uint8 public stage;

    address public constant TEAM_ADVISOR_ADDRESS =
        0x43cbB65cc934360c6ECA0Fa19a100380A6d221B2;
    uint256 lock;
    uint256 released;

    event Claim(address indexed account, uint256 amount, uint256 time);

    constructor(IERC20 _sve) {
        SVE = IERC20(_sve);
        stage = 0;
        lock = 230 * (10**6) * (10**18); // 230,000,000 SVE 18 decimals
    }

    function setTgeTime(uint256 _tge) public onlyOwner {
        require(stage == 0, "Can not setup tge");
        startTime = _tge + FULL_LOCK;
        endTime = startTime + VESTING_DURATION;

        stage = 1;
    }

    function claim() external nonReentrant {
        require(stage == 1, "Can not claim now");
        require(block.timestamp > startTime, "still locked");
        require(_msgSender() == TEAM_ADVISOR_ADDRESS, "Address invalid");
        require(lock > released, "no locked");

        uint256 amount = canUnlockAmount();
        require(amount > 0, "Nothing to claim");

        released += amount;

        SVE.safeTransfer(_msgSender(), amount);

        emit Claim(_msgSender(), amount, block.timestamp);
    }

    function canUnlockAmount() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= endTime) {
            return lock - released;
        } else {
            uint256 releasedTime = releasedTimes();
            uint256 totalVestingTime = endTime - startTime;
            return ((lock * releasedTime) / totalVestingTime) - released;
        }
    }

    function releasedTimes() public view returns (uint256) {
        uint256 targetNow = (block.timestamp >= endTime)
            ? endTime
            : block.timestamp;
        uint256 releasedTime = targetNow - startTime;
        return releasedTime;
    }

    function info()
        external
        view
        returns (
            uint8,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (stage == 0) return (stage, startTime, endTime, lock, released, 0);
        return (stage, startTime, endTime, lock, released, canUnlockAmount());
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SVEPrivateSaleClaim is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    IERC20 public SVE;

    uint256 public TGE_RELEASE = 30;
    uint256 public VESTING_DURATION = 86400 * 30 * 3; //3 months

    uint256 public startTime;
    uint256 public endTime;

    uint8 public stage;

    address[] private whilelists;
    mapping(address => uint256) private locks; // SVE
    mapping(address => uint256) private released; // SVE

    event Claim(address indexed account, uint256 amount, uint256 time);

    constructor(IERC20 _mat) {
        SVE = IERC20(_mat);
        stage = 0;
    }

    modifier canClaim() {
        require(stage == 1, "Can not claim now");
        _;
    }

    modifier canSetup() {
        require(stage == 0, "Can not setup now");
        _;
    }

    function setTgeTime(uint256 _tge) public canSetup onlyOwner {
        startTime = _tge;
        endTime = startTime + VESTING_DURATION;

        stage = 1;

        //transfer 30% for whilelists;
        for (uint256 i = 0; i < whilelists.length; i++) {
            uint256 matAmount = (locks[whilelists[i]] * TGE_RELEASE) / 100;
            locks[whilelists[i]] -= matAmount;
            SVE.transfer(whilelists[i], matAmount);
        }
    }

    function setWhilelist(address[] calldata _users, uint256[] calldata _sves)
        public
        canSetup
        onlyOwner
    {
        require(_users.length == _busds.length, "Invalid input");
        for (uint256 i = 0; i < _users.length; i++) {
            locks[_users[i]] += _sves[i];
            whilelists.push(_users[i]);
        }
    }

    function claim() external canClaim nonReentrant {
        require(block.timestamp > startTime, "still locked");
        require(locks[_msgSender()] > released[_msgSender()], "no locked");

        uint256 amount = canUnlockAmount(_msgSender());
        require(amount > 0, "Nothing to claim");

        released[_msgSender()] += amount;

        SVE.transfer(_msgSender(), amount);

        emit Claim(_msgSender(), amount, block.timestamp);
    }

    function canUnlockAmount(address _account) public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= endTime) {
            return locks[_account] - released[_account];
        } else {
            uint256 releasedTime = releasedTimes();
            uint256 totalVestingTime = endTime - startTime;
            return
                (((locks[_account]) * releasedTime) / totalVestingTime) -
                released[_account];
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
            uint256
        )
    {
        return (stage, startTime, endTime);
    }

    //For FE
    function infoWallet(address _user)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        if (stage == 0) return (locks[_user], released[_user], 0);
        return (locks[_user], released[_user], canUnlockAmount(_user));
    }

    /* ========== EMERGENCY ========== */
    function governanceRecoverUnsupported(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(_token != address(SVE), "Token invalid");
        IERC20(_token).transfer(_to, _amount);
    }
}

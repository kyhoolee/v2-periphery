pragma solidity =0.6.6;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './interfaces/IUniswapV2Router02.sol';
import './libraries/UniswapV2Library.sol';
import './libraries/SafeMath.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract UniswapV2Router02 is IUniswapV2Router02 {
    using SafeMath for uint;

    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH) public {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****

    /**
    0. Utility function to calculate the amount of tokenA and tokenB to add as liquidity
    - API to calculate the amount of tokenA and tokenB to add as liquidity
    address tokenA: address of the first token
    address tokenB: address of the second token
    uint amountADesired: the amount of tokenA to add as liquidity
    uint amountBDesired: the amount of tokenB to add as liquidity
    uint amountAMin: the minimum amount of tokenA to add as liquidity
    uint amountBMin: the minimum amount of tokenB to add as liquidity

    return:
    uint amountA: the amount of tokenA to add as liquidity
    uint amountB: the amount of tokenB to add as liquidity
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // 0. create the pair if it doesn't exist yet
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        // 1. Get the reserves of tokenA and tokenB
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);


        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {

            // 2. Calculate the amount of tokenA and tokenB to add as liquidity
            // amountA / amountB = reserveA / reserveB
            // amountA in range [amountAMin, amountADesired]
            // amountB in range [amountBMin, amountBDesired]
            // Get the maximal amount of tokenA and tokenB to add as liquidity

            // As formula for adding liquidity is:
            // amountB = amountA.mul(reserveB) / reserveA;
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);

            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {

                // As formula for adding liquidity is:
                // amountA = amountB.mul(reserveA) / reserveB;
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
    1.1. Add liquidity to the pool
    - API to mint liquidity tokens
    address tokenA: address of the first token
    address tokenB: address of the second token
    uint amountADesired: the amount of tokenA to add as liquidity
    uint amountBDesired: the amount of tokenB to add as liquidity
    uint amountAMin: the minimum amount of tokenA to add as liquidity
    uint amountBMin: the minimum amount of tokenB to add as liquidity
    address to: the address receiving the liquidity tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint amountA: the amount of tokenA to add as liquidity
    uint amountB: the amount of tokenB to add as liquidity
    uint liquidity: the number of liquidity tokens minted
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {

        // 0. Calculate the amount of tokenA and tokenB to add as liquidity
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
        // 1. Check if the pair exists, if not, create it, else get the pool of pair address
        // Need to use factory address to get the pair address
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        
        // 2. Transfer the tokenA and tokenB to the pair-address
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        // 3. Mint liquidity tokens - Uni tokens
        liquidity = IUniswapV2Pair(pair).mint(to);
    }


    /**
    1.2. Add liquidity to the pool with ETH - Pool of TokenA-ETH
    - API to mint liquidity tokens with ETH
    address token: address of the token
    uint amountTokenDesired: the amount of token to add as liquidity
    uint amountTokenMin: the minimum amount of token to add as liquidity
    uint amountETHMin: the minimum amount of ETH to add as liquidity
    address to: the address receiving the liquidity tokens
    uint deadline: the time by which the transaction must be included to effect the change
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        // 0. Calculate the amount of tokenA and tokenB to add as liquidity
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        // 1. Check if the pair exists, if not, create it, else get the pool of pair address
        address pair = UniswapV2Library.pairFor(factory, token, WETH);

        // 2. Transfer the tokenA and W(ETH) to the pair-address
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));

        // 3. Mint liquidity tokens - Uni tokens
        liquidity = IUniswapV2Pair(pair).mint(to);

        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    /**
    2.1. Remove liquidity from the pool
    - API to burn liquidity tokens
    address tokenA: address of the first token
    address tokenB: address of the second token
    uint liquidity: the number of liquidity tokens to remove
    uint amountAMin: the minimum amount of tokenA to receive
    uint amountBMin: the minimum amount of tokenB to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint amountA: the amount of tokenA to receive
    uint amountB: the amount of tokenB to receive

     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        // 1. Get the pair address
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        // 2. Transfer the liquidity tokens to the pair-address
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair

        // 3. Burn liquidity tokens
        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(to);

        // 4. Get the amount of tokenA and tokenB to receive
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);

        // 5. Assign the amount of tokenA and tokenB to receive
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);

        // 6. Check if the amount of tokenA and tokenB to receive is greater than the minimum amount
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }

    /**
    2.2. Remove liquidity from the pool with ETH - Pool of TokenA-ETH
    - API to burn liquidity tokens with ETH
    address token: address of the token
    uint liquidity: the number of liquidity tokens to remove
    uint amountTokenMin: the minimum amount of token to receive
    uint amountETHMin: the minimum amount of ETH to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint amountToken: the amount of token to receive
    uint amountETH: the amount of ETH to receive
     */
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        // 1. Remove liquidity from the pool - with ETH
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        // 2. Transfer the token to the recipient
        // 2.1. Transfer the token to the recipient
        TransferHelper.safeTransfer(token, to, amountToken);
        // 2.2. Transfer the ETH to the recipient
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    /** 3.1. Remove liquidity from the pool with permit
    - API to burn liquidity tokens with permit
    address tokenA: address of the first token
    address tokenB: address of the second token
    uint liquidity: the number of liquidity tokens to remove
    uint amountAMin: the minimum amount of tokenA to receive
    uint amountBMin: the minimum amount of tokenB to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change
    bool approveMax: whether to approve the maximum amount
    uint8 v: signature v
    bytes32 r: signature r
    bytes32 s: signature s

    - Return:
    uint amountA: the amount of tokenA to receive
    uint amountB: the amount of tokenB to receive
    
    */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        // 1. Get the pair address
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        // 2. Approve the maximum amount
        uint value = approveMax ? uint(-1) : liquidity;
        // 3. Permit the pair to spend the liquidity tokens
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        // 4. Remove liquidity from the pool
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /** 3.2. Remove liquidity from the pool with permit - Pool of TokenA-ETH
    - API to burn liquidity tokens with permit - with ETH
    address token: address of the token
    uint liquidity: the number of liquidity tokens to remove
    uint amountTokenMin: the minimum amount of token to receive
    uint amountETHMin: the minimum amount of ETH to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change
    bool approveMax: whether to approve the maximum amount
    uint8 v: signature v
    bytes32 r: signature r
    bytes32 s: signature s

    - Return:
    uint amountToken: the amount of token to receive
    uint amountETH: the amount of ETH to receive
    
    */
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        // 1. Get the pair address
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        // 2. Approve the maximum amount
        uint value = approveMax ? uint(-1) : liquidity;
        // 3. Permit the pair to spend the liquidity tokens
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        // 4. Remove liquidity from the pool - with ETH
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****

    /** 
    4.1. Remove liquidity from the pool with fee-on-transfer tokens
    - API to burn liquidity tokens with fee-on-transfer tokens
    address token: address of the first token
    uint liquidity: the number of liquidity tokens to remove
    uint amountAMin: the minimum amount of tokenA to receive
    uint amountETHMin: the minimum amount of tokenB to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        // 1. Call remove liquidity from the pool with ETH 
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        // 2. Transfer the token from Caller to the pair-address
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));

        // 3. Transfer the ETH to the Caller from the pair-address
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }



    /**
    4.2. Remove liquidity from the pool with permit and fee-on-transfer tokens
    - API to burn liquidity tokens with permit and fee-on-transfer tokens
    address token: address of the first token
    uint liquidity: the number of liquidity tokens to remove
    uint amountTokenMin: the minimum amount of token to receive
    uint amountETHMin: the minimum amount of ETH to receive
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change
    bool approveMax: whether to approve the maximum amount
    uint8 v: signature v
    bytes32 r: signature r
    bytes32 s: signature s

    - Return:
    uint amountETH: the amount of ETH to receive

     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        uint value = approveMax ? uint(-1) : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    /**
    1.0. Swap tokens for tokens - internal function
    - API to swap tokens for tokens - swap by the path of pair-address
    uint[] memory amounts: the amounts of tokens to swap 
    address[] memory path: the path of pair-pool-address
    address _to: the address receiving the tokens

     */
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        // 1. Loop through the path of pair-address
        for (uint i; i < path.length - 1; i++) {

            // 2. Get the input and output token address
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            
            // 3. Get the output swapped amount
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = (input == token0) ? (uint(0), amountOut) : (amountOut, uint(0));

            // 4. Get the next pair address or the recipient address - as last of the path
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;

            // 5. Swap the tokens - output token to: next pool or the last as recipient
            // Actually reduce amount0Out and amount1Out from the pool
            // Send amount0Out and amount1Out to the next pool or the recipient
            // Not do the calculattion logic of how much amount0Out and amount1Out 
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    /**
    1.1. Swap exact tokens for tokens
    - API to swap exact input tokens for output tokens
    uint amountIn: the amount of input tokens
    uint amountOutMin: the minimum amount of output tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint[] memory amounts: the amounts of tokens to swap

     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // 1. Calculate the amounts of tokens to swap
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 2. Transfer the input token to the pair-address
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        // 3. Swap the tokens between the pair-address and to the recipient
        _swap(amounts, path, to);

    }

    /**
    1.2. Swap tokens for exact tokens
    - API to swap input tokens for exact output tokens
    uint amountOut: the amount of output tokens
    uint amountInMax: the maximum amount of input tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint[] memory amounts: the amounts of tokens to swap

    */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    /**
    1.3. Swap exact ETH for tokens
    - API to swap exact ETH for output tokens
    uint amountOutMin: the minimum amount of output tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint[] memory amounts: the amounts of tokens to swap
     */
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    /**
    1.4. Swap tokens for exact ETH
    - API to swap input tokens for exact output ETH
    uint amountOut: the amount of output ETH
    uint amountInMax: the maximum amount of input tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens

    - Return:
    uint[] memory amounts: the amounts of tokens to swap

     */
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // 1. Calculate the input amounts of tokens to swap
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');

        // 2. Transfer the input token to the pair-address
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        // 3. Swap the tokens between the pair-address and to the current contract
        _swap(amounts, path, address(this));

        // 4. Transfer the WETH to the recipient from the current contract
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
    1.5. Swap exact tokens for ETH
    - API to swap exact input tokens for output ETH
    uint amountIn: the amount of input tokens
    uint amountOutMin: the minimum amount of output ETH
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint[] memory amounts: the amounts of tokens to swap

     */
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // 1. Calculate the amounts of tokens to swap
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

        // 2. Transfer the input token to the pair-address
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );

        // 3. Swap the tokens between the pair-address and to the current contract
        _swap(amounts, path, address(this));

        // 4. Transfer the WETH to the recipient from the current contract
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /**
    1.6. Swap ETH for exact tokens
    - API to swap exact ETH for output tokens
    uint amountOut: the amount of output tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    - Return:
    uint[] memory amounts: the amounts of tokens to swap

     */
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // 1. Calculate the amounts of tokens to swap
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');

        // 2. Deposit the WETH to the current contract
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));

        // 3. Swap the tokens between the pair-address and to the recipient
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }


    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    /**
    2.0. Swap tokens for tokens supporting fee-on-transfer tokens - internal function
    - API to swap tokens for tokens supporting fee-on-transfer tokens - swap by the path of pair-address
    uint[] memory amounts: the amounts of tokens to swap
    address[] memory path: the path of pair-pool-address
    address _to: the address receiving the tokens


    */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        // 1. Loop through the path of pair-address
        for (uint i; i < path.length - 1; i++) {
            // 2. Get the input and output token address
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            // 3. Get the pair address
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));

            // 4. Transfer the input token to the pair-address
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
                // 4.1. Get the reserves of tokenA and tokenB
                (uint reserve0, uint reserve1,) = pair.getReserves();
                // 4.2. Get the reserve of input and reserve of output
                (uint reserveInput, uint reserveOutput) = (input == token0) ? (reserve0, reserve1) : (reserve1, reserve0);
                // 4.3. Extract input amount from the pair - due to the change of balance happend in the previous swap
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                // 4.4. Calculate the output amount
                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }

            // 5. check if the input token is the token0 to get the amount0Out and amount1Out
            (uint amount0Out, uint amount1Out) = (input == token0) ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            
            // 6. Swap the tokens - output token to: next pool or the last as recipient
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }


    /**
    2.1. Swap exact tokens for tokens supporting fee-on-transfer tokens
    - API to swap exact input tokens for output tokens supporting fee-on-transfer tokens
    uint amountIn: the amount of input tokens
    uint amountOutMin: the minimum amount of output tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

    */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        // 1. Transfer the input token to the pair-address
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );

        // 2. Balance of recipient before swap
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        // 3. Swap the tokens between the pair-address and to the recipient
        _swapSupportingFeeOnTransferTokens(path, to);

        // 4. Check if the output token is greater than the minimum amount
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }


    /**
    2.2. Swap exact ETH for tokens supporting fee-on-transfer tokens
    - API to swap exact ETH for output tokens supporting fee-on-transfer tokens
    uint amountOutMin: the minimum amount of output tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens
    uint deadline: the time by which the transaction must be included to effect the change

     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {

        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        // 1. Deposit the WETH to the current contract
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));

        // 2. Balance of recipient before swap
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

        // 3. Swap the tokens between the pair-address and to the recipient
        _swapSupportingFeeOnTransferTokens(path, to);

        // 4. Check if the output token is greater than the minimum amount
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }


    /**
    2.3. Swap tokens for exact ETH supporting fee-on-transfer tokens
    - API to swap input tokens for exact output ETH supporting fee-on-transfer tokens
    uint amountOut: the amount of output ETH
    uint amountInMax: the maximum amount of input tokens
    address[] calldata path: the path of pair-pool-address
    address to: the address receiving the tokens

     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        /**
        msg.data (bytes calldata): complete calldata
        msg.sender (address): sender of the message (current call)
        msg.value (uint): number of wei sent with the message
         */
        // 1. Transfer the input token to the pair-address
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );

        // 2. Swap the tokens between the pair-address and to the current contract
        _swapSupportingFeeOnTransferTokens(path, address(this));

        // 3. Balance of WETH of the current contract - after swap
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

        // 4. Withdraw the WETH to the recipient from the current contract
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    /**
    0.1. Quote the amount of output tokens for the amount of input tokens
    - Formula 
    amountB = amountA.mul(reserveB) / reserveA
     */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /**
    0.2. Get the amount of output tokens for the amount of input tokens
    - Formula
    amountOut = amountIn * 997 * reserveOut / (1000 * reserveIn + 997 * amountIn)
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
    0.3. Get the amount of input tokens for the amount of output tokens
    - Formula
    amountIn = reserveIn * amountOut * 1000 / ((reserveOut - amountOut) * 997) + 1
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }
    
    /**
    0.4. Get the amount of output tokens for the amount of input tokens 
    - Swap by a path of pair-address
    - Logic:
        - Iterate through the path of pair-address
            - Get reserveIn and reserveOut
            - Calculate the amountOut by the formula
                - amountOut = amountIn * 997 * reserveOut / (1000 * reserveIn + 997 * amountIn)
     */
    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }
    
    /**
    0.5. Get the amount of input tokens for the amount of output tokens
    - Swap by a path of pair-address
    - Logic:
        - Iterate through the path of pair-address in revert order - to calculate the amountIn from the last pair
            - Get reserveIn and reserveOut
            - Calculate the amountIn by the formula
                - amountIn = reserveIn * amountOut * 1000 / ((reserveOut - amountOut) * 997) + 1
     */
    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}

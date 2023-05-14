// SPDX-License-Identifier: MIT
pragma solidity =0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SwapContract is Ownable {
    using SafeERC20 for IERC20;

    uint256 public balance;

    uint256 public minAmount;

    uint256 public valuation;
    uint256 public decimalsValuation;

    address public immutable token;
    IERC20 public immutable itoken;

    IERC20 public immutable oldToken;

    event TransferBurned(
        address indexed _fromAddr,
        address indexed _destAddr,
        uint256 _amount
    );
    event TransferSent(
        address indexed _fromAddr,
        address indexed _destAddr,
        uint256 _amount
    );

    constructor(IERC20 _itoken, IERC20 _oldToken) {
        token = address(_itoken);
        itoken = _itoken;
        oldToken = _oldToken;

        minAmount = 1000000000000000;
        valuation = 1;
        decimalsValuation = 6;
    }

    //Called after tokens are allocated.
    function init() public onlyOwner {
        _init();
    }

    function _init() internal {
        balance = itoken.balanceOf(address(this));
    }

    function changeMinAmount(uint256 newAmount) public onlyOwner {
        minAmount = newAmount;
    }

    //if decimals are used
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x > 1) {
            uint256 val = 10;
            for (uint256 i = 1; i < x; i++) {
                val *= 10;
            }
            return val;
        } else {
            return 10;
        }
    }

    //0.000001 => 1, 6
    function setValuation(uint256 _valuation, uint256 decimals)
        public
        onlyOwner
    {
        valuation = _valuation;
        decimalsValuation = decimals;
    }

    function calculateAmount(uint256 amount) internal view returns (uint256) {
        if (decimalsValuation == 0) {
            return amount * valuation;
        } else {
            return (amount * valuation) / sqrt(decimalsValuation);
        }
    }

    function SwapTokens(uint256 amount) public returns (uint256) {
        require(valuation > 0, "No valuation for token set");
        require(amount > 0, "Invalid amount");
        require(
            amount <= oldToken.balanceOf(msg.sender),
            "Not enough tokens for the swap."
        );
        require(amount >= minAmount, "Min amount");

        _init();
        uint256 calAmount = calculateAmount(amount);
        require(calAmount <= balance, "Not enough balance for the swap.");
        require(calAmount > 0, "Min amount");

        balance -= calAmount;

        oldToken.safeTransferFrom(msg.sender, address(0xdead), amount);
        emit TransferBurned(msg.sender, address(this), amount);
        itoken.safeTransfer(msg.sender, calAmount);
        emit TransferSent(address(this), msg.sender, calAmount);

        return calAmount;
    }

    function claimRemains(uint256 amount) public onlyOwner {
        require(amount > 0, "Invalid amount");
        _init();
        require(amount <= balance, "Amount exceedes balance");

        balance -= amount;

        itoken.safeTransfer(msg.sender, amount);
        emit TransferSent(address(this), msg.sender, amount);
    }
}

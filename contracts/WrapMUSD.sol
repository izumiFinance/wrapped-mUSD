// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.19;

/**
 * @dev interfaces of MUSD
 */
interface IMUSD {
    function sharesOf(address _account) external view returns (uint256);

    /**
     * @dev get share amount from amount of mUSD
     */
    function getSharesByRUSDY(
        uint256 _rUSDYAmount
    ) external view returns (uint256);

    function decimals() external view returns (uint8);

    /**
     * @dev transfer `amount` of mUSD
     */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) external returns (bool);
    /**
     * @dev transfer shares of mUSD directly
     */
    function transferShares(
        address _recipient,
        uint256 _sharesAmount
    ) external returns (uint256);
}

contract WrapMUSD {
    /**
     * name of this token
     */
    string public name;
    /**
     * symbol of this token
     */
    string public symbol;
    /**
     * decimals of this token, same as MUSD
     */
    uint8 public decimals;
    /**
     * address of musd token
     */
    address public mUSD;

    /**
     * @dev approve operation of this wrap token
     * @param src owner of token
     * @param guy operator
     * @param val amount of mUSD
     */
    event Approval(address indexed src, address indexed guy, uint256 val);

    /**
     * @dev transfer this wrap token
     * @param src source address
     * @param dst destination address
     * @param val amount of mUSD
     */
    event Transfer(address indexed src, address indexed dst, uint256 val);

    /**
     * @dev deposit musd to this wrapped token
     * @param dst destination address
     * @param val amount of token wrapped token
     */
    event Deposit(address indexed dst, uint256 val);

    /**
     * @dev withdraw musd from this wrap token
     * @param src address to get withdrawed musd
     * @param val amount of wrapped token
     */
    event Withdrawal(address indexed src, uint256 val);

    /**
     * balance of account
     */
    mapping(address => uint256) public balanceOf;

    /**
     * shares of account accumulated when deposit
     */
    mapping(address => uint256) public sharesOf;
    /**
     * allowance[src][spender] is max amount of token for spender to transfer
     * from src
     */
    mapping(address => mapping(address => uint256)) public allowance;
    /**
     * amount of shares chargeReceiver can collect
     */
    uint256 public chargeShares;
    /**
     * who can collect shares
     */
    address public chargeReceiver;
    /**
     * total amount of token
     */
    uint256 public totalSupply;

    /**
     * owner of this contract
     */
    address private _owner;

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev constructor of this contract, contract owner will be msg.sender
     * @param _name, name of token
     * @param _symbol, symbol of token
     * @param _mUSD, address of musd
     * @param _chargeReceiver, who collect charged shares
     */
    constructor(
        string memory _name, 
        string memory _symbol, 
        address _mUSD,
        address _chargeReceiver
    ) {
        name = _name;
        symbol = _symbol;
        mUSD = _mUSD;
        chargeReceiver = _chargeReceiver;
        decimals = IMUSD(mUSD).decimals();

        _transferOwnership(_msgSender());
    }

    function getShareLocal(uint256 share, uint256 balance, uint256 val) internal pure returns(uint256 shareLocal) {
        if (val >= balance) {
            return share;
        }
        if (share == 0) {
            return 0;
        }
        uint256 remain = type(uint256).max / share;
        if (val <= remain) {
            shareLocal = share * val / balance;
        } else {
            shareLocal = share * remain / balance * val / remain;
        }
    }
    /**
     * @dev change chargeReceiver, only owner can call this interface
     */
    function changeChargeReceiver(address _chargeReceiver) external onlyOwner {
        chargeReceiver = _chargeReceiver;
    }

    /**
     * @dev collect charged shares, only chargeReceiver can call this interface
     */
    function collectCharge() external {
        require(msg.sender == chargeReceiver, "not receiver");
        if (chargeShares > 0) {
            IMUSD(mUSD).transferShares(msg.sender, chargeShares);
            chargeShares = 0;
        }
    }

    /**
     * @dev deposit musd to this contract
     * @param val of musd to deposit
     */
    function deposit(uint256 val) external {
        require(val > 0, "val > 0");
        uint256 beforeTotShare = IMUSD(mUSD).sharesOf(address(this));
        IMUSD(mUSD).transferFrom(msg.sender, address(this), val);
        uint256 afterTotShare = IMUSD(mUSD).sharesOf(address(this));
        uint256 shares = afterTotShare - beforeTotShare;
        require(shares > 0, "shares > 0");
        sharesOf[msg.sender] += shares;
        balanceOf[msg.sender] += val;
        totalSupply += val;
        emit Deposit(msg.sender, val);
    }

    /**
     * @dev withdraw wrapped musd from this contract
     * @param val of musd to deposit
     * @param recipient address to receive withdrawed token
     */
    function withdraw(uint256 val, address recipient) external {
        if (val > 0) {
            uint256 balance = balanceOf[msg.sender];
            uint256 shares = sharesOf[msg.sender];
            require(balance >= val);
            // compute delta shares by current price
            uint256 dShares = IMUSD(mUSD).getSharesByRUSDY(val);
            // compute delta shares by share/balance rate
            uint256 dSharesLocal = getShareLocal(dShares, balance, val);
            if (dShares < dSharesLocal) {
                IMUSD(mUSD).transferShares(recipient, dShares);
                chargeShares += dSharesLocal - dShares;
                shares -= dSharesLocal;
                balance -= val;
            } else {
                // impossible
                IMUSD(mUSD).transferShares(recipient, dSharesLocal);
                shares -= dSharesLocal;
                balance -= val;
            }
            if (shares == 0) {
                balance = 0;
            } else if (balance == 0) {
                chargeShares += shares;
                shares = 0;
            }
            balanceOf[msg.sender] = balance;
            sharesOf[msg.sender] = shares;
            totalSupply -= val;
        }

        emit Withdrawal(msg.sender, val);
    }


    struct Balance {
        uint256 balance;
        uint256 shares;
    }

    function _transferFrom(address src, address dst, uint256 val) internal {
        if (val > 0) {
            Balance memory balanceSrc;
            Balance memory balanceDst;
            balanceSrc.balance = balanceOf[src];
            require(balanceSrc.balance >= val, "balance");

            balanceSrc.shares = sharesOf[src];

            balanceDst.balance = balanceOf[dst];
            balanceDst.shares = sharesOf[dst];

            // compute delta shares by current price
            uint256 dShares = IMUSD(mUSD).getSharesByRUSDY(val);
            // compute delta shares by share/balance rate
            uint256 dSharesLocal = getShareLocal(balanceSrc.shares, balanceSrc.balance, val);

            if (dShares < dSharesLocal) {
                chargeShares += dSharesLocal - dShares;
                balanceSrc.shares -= dSharesLocal;
                balanceDst.shares += dShares;
                balanceSrc.balance -= val;
                balanceDst.balance += val;
            } else {
                // impossible
                balanceSrc.shares -= dSharesLocal;
                balanceDst.shares += dSharesLocal;
                balanceSrc.balance -= val;
                balanceDst.balance += val;
            }
            if (balanceSrc.shares == 0) {
                balanceSrc.balance = 0;
            } else if (balanceSrc.balance == 0) {
                chargeShares += balanceSrc.shares;
                balanceSrc.shares = 0;
            }
            balanceOf[src] = balanceSrc.shares;
            sharesOf[src] = balanceSrc.balance;
            balanceOf[dst] = balanceDst.shares;
            sharesOf[dst] = balanceDst.balance;
        }
    }
    /**
     * @dev approve a spender to spend msg.sender's some amount of wrapped token
     * @param spender address of spender
     * @param val amount of wrapped musd
     */
    function approve(address spender, uint256 val) external returns (bool) {
        allowance[msg.sender][spender] = val;

        emit Approval(msg.sender, spender, val);

        return true;
    }

    /**
     * @dev transfer some wrapped musd to dst from msg.sender
     * @param dst, destination address
     * @param val, amount of wrapped musd
     */
    function transfer(address dst, uint256 val) external returns (bool) {
        return transferFrom(msg.sender, dst, val);
    }

    /**
     * @dev transfer some wrapped musd to dst from src
     * @param src, source address
     * @param dst, destination address
     * @param val, amount of wrapped musd
     */
    function transferFrom(
        address src,
        address dst,
        uint256 val
    ) public returns (bool) {
        require(balanceOf[src] >= val);

        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= val);

            unchecked {
                allowance[src][msg.sender] -= val;
            }
        }

        _transferFrom(src, dst, val);

        emit Transfer(src, dst, val);

        return true;
    }
}

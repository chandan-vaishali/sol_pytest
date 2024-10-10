// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IMultisigToken.sol";


/**
 * @dev An implementation of the ERC20 standard for a "Reichman University" Token.
 */
contract RUToken is IERC20, IERC20Metadata, IMultisigToken {
    /**
     * Maximum number of mintable tokens.
     */
    uint public maxTokens;

    /**
     * Price required to mint a token in ETH
     */
    uint public tokenPrice;

    /**
     * Total amount of existing tokens.
     */
    uint256 public totalAmount;


    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    struct multisig_addresses {
        uint nonce;
        address [] pks_list;
    }
    mapping(address => multisig_addresses) multiAdd;


    constructor(uint _tokenPrice, uint _maxTokens) {
        tokenPrice = _tokenPrice;
        maxTokens = _maxTokens;
        totalAmount = 0;
    }

function getNonce(address multisigAddr) public view returns (uint) {
    return multiAdd[multisigAddr].nonce;
}


    /**
    * @dev Returns the decimals places of the token.
    */
    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function name() public pure override returns (string memory) {
        return "Reichman U Token";
    }

    function symbol() public pure override returns (string memory) {
        return "RUX";
    }

    /**
     *returns nonce associate with multisig_address parameter.
     */
    function nonce(address multisig_address) external view returns (uint256) {
        return multiAdd[multisig_address].nonce;
    }


    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256) {
        // TODO: Implement
        return totalAmount;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        // TODO: Implement
        require(account != address(0), "check that account isn't the zero address");
        return balances[account];
    }


    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        // TODO: Implement
        require(balances[msg.sender] >= amount);
        require(recipient != address(0), "recipient can't be the zero address");
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;

    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view override returns (uint256) {
        // TODO: Implement
        return allowances[owner][spender];
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external override returns (bool) {
        // TODO: Implement
        address owner = msg.sender;
        allowances[owner][spender] = 0;
        require(allowances[owner][spender] == 0);
        allowances[owner][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        // TODO: Implement
        address owner = sender;
        require(balances[sender] >= amount, "check sender has enough to send amount");
        require(allowances[sender][msg.sender] >= amount);
        require(recipient != address(0), "check not sending to zero address");
        balances[sender] -= amount;
        balances[recipient] += amount;
        allowances[sender][msg.sender] -= amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Mint a new token. 
     * The total number of tokens minted is the msg value divided by tokenPrice.
     */
    function mint() public payable returns (uint) {
        // TODO: Implement
        require(tokenPrice > 0);
        require(msg.sender != address(0), "prevent minting from zero address");
        uint amount = (msg.value)/(tokenPrice);
        require((totalAmount + amount) <= maxTokens, "prevent minting more than maxTokens");
        balances[msg.sender] += amount;
        totalAmount += amount;
        return amount;
    }

    /**
     * Burn `amount` tokens. The corresponding value (`tokenPrice` for each token) is sent to the caller.
     */
    function burn(uint amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance for burn");
        // TODO: Implement
        require((balances[msg.sender] - amount) >= 0);
        require(msg.sender != address(0));
        require(amount <= totalAmount, "burn amount must be less than total supply");
        balances[msg.sender] -= amount;
        uint amountEthTransfer = 0;
        if (amount > 0) {
            amountEthTransfer = (amount)*(tokenPrice);
            require(amountEthTransfer / amount == tokenPrice);
        } else {
            amountEthTransfer = 0;
        }
        balances[address(0)] += amount;
        payable(msg.sender).transfer(amountEthTransfer);
        totalAmount -= amount;
    }

    /**
     * @dev registers a multisig address controlled by the public keys `pk1`, `pk2` and `pk3`.
     * The returned address should always match
     */
    function registerMultisigAddress(address pk1, address pk2, address pk3) external returns (address){
        bytes32 new_address = keccak256(abi.encodePacked(pk1, pk2, pk3));
        address multisig_address = address(uint160(uint256(new_address)));
        require(multiAdd[multisig_address].nonce == 0);
        multiAdd[multisig_address].nonce = 1;
        multiAdd[multisig_address].pks_list = [pk1,pk2,pk3];
        return multisig_address;

    }

    /**
     * @dev returns the address controlled by the public keys `pk1`, `pk2` and `pk3`.
     */
    function getMultisigAddress(address pk1, address pk2, address pk3) external pure returns (address){
        bytes32 new_address = keccak256(abi.encodePacked(pk1, pk2, pk3));
        address multisig_address = address(uint160(uint256(new_address)));
        return multisig_address;

    }

    function transferFrom_multisig(address sender, address recipient, uint256 amount) private returns (bool) {
        address owner = sender;
        require(recipient != address(0));
        require(sender != address(0));
        require(balances[sender] >= amount);
        balances[sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from the multisig address `multisigOwner` to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     * `multisigOwner` must have been previously registered using `registerMultisigAddress`.
     * `msg.sender` must be one of the public keys controlling `multisigOwner`, and `secondSig` must be a valid signature proving that
     * a second controlling public key approved the transaction as well.
     *
     * `nonce` is used to prevent replay attacks (note that EVM does not allow a contract to access the actual transaction nonce).
     *
     * Emits a {Transfer} event.
     */
    function transfer2of3(
    address multisigOwner,
    address recipient,
    uint256 amount,
    uint nonce,
    Signature calldata secondSig
) external returns (bool) {
    // Ensure the multisigOwner and recipient are not the same
    require(multisigOwner != recipient, "Multisig owner and recipient cannot be the same");
    
    // Ensure the multisigOwner and msg.sender are not the same
    require(multisigOwner != msg.sender, "Multisig owner and sender cannot be the same");
    
    // Ensure msg.sender and recipient are not the same
    require(msg.sender != recipient, "Sender and recipient cannot be the same");
    
    // Ensure valid addresses for multisigOwner and recipient
    require(multisigOwner != address(0), "Multisig owner cannot be zero address");
    require(recipient != address(0), "Recipient cannot be zero address");
    
    // Amount must be greater than zero
    require(amount > 0, "Amount must be greater than zero");
    
    // Ensure the correct nonce is used
    require(nonce == multiAdd[multisigOwner].nonce + 1, "Invalid nonce");
    
    // Recover the second signature
    bytes32 messageHash = keccak256(
        abi.encodePacked(address(this), recipient, multisigOwner, amount, nonce)
    );
    address secondSigner = ecrecover(messageHash, secondSig.v, secondSig.r, secondSig.s);
    
    // Ensure the second signature is valid and not the same as msg.sender
    require(secondSigner != address(0), "Invalid second signature");
    require(secondSigner != msg.sender, "Sender and second signer cannot be the same");
    
    // Retrieve multisig keys
    address[] memory multisigKeys = multiAdd[multisigOwner].pks_list;
    
    // Ensure msg.sender is a valid multisig owner
    bool isValidSender = (
        msg.sender == multisigKeys[0] || 
        msg.sender == multisigKeys[1] || 
        msg.sender == multisigKeys[2]
    );
    require(isValidSender, "Sender is not a valid multisig key");
    
    // Ensure secondSigner is a valid multisig owner
    bool isValidSecondSigner = (
        secondSigner == multisigKeys[0] || 
        secondSigner == multisigKeys[1] || 
        secondSigner == multisigKeys[2]
    );
    require(isValidSecondSigner, "Second signer is not a valid multisig key");
    
    // Increment nonce and perform the transfer
    multiAdd[multisigOwner].nonce += 1;
    require(transferFrom_multisig(multisigOwner, recipient, amount), "Transfer failed");

    return true;
}






}
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20DEBITA is ERC20 {
     
    constructor() ERC20("DEBITA", "DEBITA") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }
     
    function mint(uint _amount) public {
        _mint(msg.sender, _amount);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract RomanUser {

    using Counters for Counters.Counter;
    
    // user structure
    struct User {
        address userId;
        uint256 nftId;
        uint8 behavior; // 100% for all users --> decrement by 1% for each time the user is blcoked 
    }

    // mapping all users --> get address by tokenId
    mapping(uint => User) public allUsers; // todo change var name to allTokens

    //mapping users add by nftid
    mapping (address => uint256) public allAdd;

    // mapping behaviror by address
    mapping (address => uint8) public userBeh;

    // init counter
    Counters.Counter public allUsersCounter; // todo increment by 1 so user1 --> nft1

    // create a new user
    function createUser(address userId, uint256 nftId) external {
        User memory user = User({
            userId: userId,
            nftId: nftId,
            behavior: 100
        });

        allAdd[userId] = nftId;
        userBeh[userId] = 100;
        allUsers[allUsersCounter.current()] = user;
        allUsersCounter.increment();
    }

    //  delete user
    function removeUser(uint256 nftId) external {
        require(msg.sender == allUsers[nftId].userId, "you are not the owner of this token");
        delete allUsers[nftId];
    }

    // get all users
    function getAllUsers() public view returns (User[] memory) {
      User[] memory data = new User[](allUsersCounter.current());
      for (uint i = 0; i < allUsersCounter.current(); i++) {
          User memory user = allUsers[i];
          data[i] = user;
      }
      return data;
    }

    // get User by tokenId
    function getUser(uint256 nftID) public view returns(User memory) {
    return allUsers[nftID];
    }


    function blockUser(uint256 _from, uint256 _to) public {
        require(allUsers[_from].userId == msg.sender, "sender is not msg.sender"); // **** TODO modifier
        require(allUsers[_from].nftId != 0 , "Mint a RomanToken first");
        require(allUsers[_to].userId != msg.sender, "why you are blocking yourself.. !!?" );
        
        // @DEV IMPORTANT SECURITY ISSUE ATTENTION underflow
        allUsers[_to].behavior -= 1;     
    }

    function unblockUser(uint256 _from, uint256 _to) public {
        // require from blocked to

        // require from == msg.sender
        require(allUsers[_from].userId == msg.sender, "sender is not msg.sender"); // **** TODO modifier

        // overflow
        allUsers[_to].behavior += 1;
    }

    // get nftid user by address
    function getTokenIdByAddress(address add) external view returns(uint256) {
                return allAdd[add];
        }

    // get user behavior
    // @dev TODO return 0
    function getBehavior(address add) external view returns(uint8) {
        return userBeh[add];

    }
}
contract RomanToken is ERC721, ERC721URIStorage {
    using Counters for Counters.Counter;
    
    // mapping users minted a token 
    mapping (address => bool) private _minted;

    // counter
    Counters.Counter private _tokenIdCounter;

    // constructor
    constructor() ERC721("RomanToken", "RMN") {
    // set counter to 1 ==> first minted token is 1
        _tokenIdCounter.increment();
    }

    // init RomanUser contract
    RomanUser _r = RomanUser(0x2C2EFa09d5f9bCC854A658c6b724d3C6166c91e1);

    // check if the sender minted a token
    modifier onlyOnce(address _sender) {
        require(_minted[_sender] == false, "Only one token is allowed");
        // _minted[_sender] = true;
        _;
    }

    // check if the sender is the owner of the token
    modifier onlyTokenOwner(address _sender, uint256 _tokenId) {
        require(ownerOf(_tokenId) == _sender, "Only the owner can call this function");
        _;
    }

    // lock prohibited function
    modifier impossible() {
        require(0 > 1, "this function in not allowed");
        _;
    }

   // prohibted function  --> override token transfer functions
    function safeTransferFrom(address add, address to, uint256 tokenId, bytes memory data) public override impossible() {}
    function transferFrom(address add, address to, uint256 tokenId) public override impossible() {}

    // check if the address mint a token
    function didMint(address add) external view returns (bool) {
        return _minted[add];
    }

    // mint a token
    function safeMint(address to) public onlyOnce(to) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _minted[to] = true;
        _safeMint(to, tokenId);
        _r.createUser(to, tokenId);
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // get token uri by tokenId
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // set token uri by tokenId
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyTokenOwner(msg.sender, tokenId) {
        _setTokenURI(tokenId,_tokenURI);
    }

    // burn token by tokenId
    // @dev ATTENTION tokenId and address are set to 0
    function burn(uint256 tokenId) public onlyTokenOwner(msg.sender, tokenId) {
        _burn(tokenId);
        _minted[ownerOf(tokenId)] = false;
        _r.removeUser(tokenId);
    }

}
contract RomanVault {

    uint public totalSupply;

    mapping(address => uint) public balances;

    // init RomanUser and RomanToken contracts
    RomanUser _ru = RomanUser(0x2C2EFa09d5f9bCC854A658c6b724d3C6166c91e1);
    RomanToken _rt = RomanToken(0x7050078cB25665EBffB8C9422a60A205Fe982D7E);

    // @dev TODO can use balanceOf function from ERC721 contract
    modifier rDidMint(address add) {
        require(_rt.didMint(add) == true, "Mint a RomaNToken first");
        _;
    }

    // deposit function
    function deposit() public payable rDidMint(msg.sender) {
        require(msg.value >= 1, "deposit must be greater than 1");	
        balances[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    // withdraw function
    function withdraw(uint _amount) public payable {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        totalSupply -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // transfer function
    // @dev TODO charges go to dev
    function transfer(address to, uint amount) public rDidMint(msg.sender) rDidMint(to) {
        require(balances[msg.sender] >= amount);
        uint256 charges = calculateCharge(to, amount);
        
        balances[msg.sender] -= amount;
        balances[to] = balances[to] + amount - charges;
    }


    // get user behavior
    function getBehavior(address user) public view returns (uint8) {
        return _ru.getBehavior(user);
    }

    // calculate charges for user depending on the behavior
    // @dev TODO add the amount list for each interaction example(view profile=10, message=8, comment=5, like=3,....)
    // @dev TODO add dev commission paymentSplitter
    function calculateCharge(address user, uint256 amount) internal view returns(uint256) {
        uint8 behavior = getBehavior(user);
        return amount - (amount * behavior / 100);

    }
}

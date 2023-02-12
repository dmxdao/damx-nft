// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IVester {
    function bonusRewards(address _account) external view returns (uint256);

    function setBonusRewards(address _account, uint256 _amount) external;
}

contract DamxRobot is ERC721Enumerable, Ownable, ReentrancyGuard {

    /// @notice Collection of NFT details to describe each NFT
    struct NFTDetails {
        uint256 power;
    }
    /// @notice Use the NFT tokenId to read NFT details
    mapping(uint256 => NFTDetails) public nftDetailsById;
    address public saleContract;

    string public baseURI;

    constructor(address _saleContract) ERC721("DAMX ROBOT", "DAMX ROBOT") {
        saleContract = _saleContract;
    }

    /* ========== Public view functions ========== */

    function getTokenPower(uint256 tokenId) external view returns (uint256) {
        NFTDetails memory currentNFTDetails = nftDetailsById[tokenId];
        return currentNFTDetails.power;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // @dev sets base URI
    function setBaseURI(string memory baseURI_) external onlyOwner {
        baseURI = baseURI_;
    }

    /**
    * @dev Throws if called by any account other than the saleContract.
     */
    modifier onlySaleContract() {
        require(saleContract == _msgSender(), "DamxNFT: caller is not the saleContract");
        _;
    }
    function mint(uint256 _power, address _to) external onlySaleContract returns (uint256) {
        uint256 id = totalSupply() + 1;
        nftDetailsById[id] = NFTDetails(_power);
        _mint(_to, id);
        return id;
    }
}

contract RobotSale is Ownable, ReentrancyGuard {

    uint256 public constant MAX_MMC_PURCHASE = 5; // max purchase per txn
    uint256 public constant MAX_MMC = 5000; // max of 5000

    // State variables
    address public communityFund;
    address public dmxVester;
    address public esDMX;
    DamxRobot public damxRobot;

    address public usdc;

    uint256 public robotPrice = 100_000_000; // 100 USDC
    uint256 public robotPower = 5000; // 5000 power
    uint256 public esDMXBonus = 3880e18; // 3880 esDMX
    uint256 public totalVolume;
    uint256 public totalPower;
    uint256 public totalBonus;

    uint256 public stepEsDMX = 9900; // 0.99
    uint256 public stepPrice = 10100; // 1.01
    uint256 public stepPower = 9900; // 0.99
    uint256 public step = 100; //

    bool public saleIsActive = false; // determines whether sales is active

    event AssetMinted(address account, uint256 tokenId, uint256 power, uint256 bonus);

    constructor(address _communityFund, address _esDMX, address _dmxVester, address _usdc) {
        damxRobot = new DamxRobot(address(this));
        communityFund = _communityFund;
        esDMX = _esDMX;
        dmxVester = _dmxVester;
        usdc = _usdc;
        damxRobot.transferOwnership(msg.sender);
    }


    // get current price and power
    function getCurrentPP() public view returns (uint256 _mccPrice, uint256 _mccPower, uint256 _esDMXBonus) {
        _mccPrice = robotPrice;
        _mccPower = robotPower;
        _esDMXBonus = esDMXBonus;
        uint256 _totalSupply = damxRobot.totalSupply();
        uint256 modulus = damxRobot.totalSupply() % step;
        if (modulus == 0 && _totalSupply != 0) {
            _mccPrice = (robotPrice * stepPrice) / 10000;
            _mccPower = (robotPower * stepPower) / 10000;
            _esDMXBonus = (esDMXBonus * stepEsDMX) / 10000;
        }
    }

    /* ========== External public sales functions ========== */

    // @dev mints meerkat for the general public
    function mintDamxRobot(uint256 numberOfTokens) external nonReentrant returns (uint256 _totalPrice,uint256 _totalPower,uint256 _totalBonus) {
        require(saleIsActive, 'Sale Is Not Active');
        // Sale must be active
        require(numberOfTokens <= MAX_MMC_PURCHASE, 'Exceed Purchase');
        // Max mint of 1
        require(damxRobot.totalSupply() + numberOfTokens <= MAX_MMC);
        for (uint i = 0; i < numberOfTokens; i++) {
            if (damxRobot.totalSupply() < MAX_MMC) {
                (robotPrice, robotPower, esDMXBonus) = this.getCurrentPP();
                _totalPrice = _totalPrice + robotPrice;
                uint256 id = damxRobot.mint(robotPower,msg.sender);
                emit AssetMinted(msg.sender, id, robotPower, esDMXBonus);
                IERC20(esDMX).transfer(msg.sender, esDMXBonus);
                IVester vester = IVester(dmxVester);
                vester.setBonusRewards(msg.sender, vester.bonusRewards(msg.sender) + esDMXBonus);
                _totalPower += robotPower;
                _totalBonus += esDMXBonus;
            }
        }
        IERC20(usdc).transferFrom(msg.sender, communityFund, _totalPrice);
        totalVolume += _totalPrice;
        totalBonus += _totalBonus;
        totalPower += _totalPower;
    }

    function estimateAmount(uint256 numberOfTokens) external view returns (uint256 _totalPrice, uint256 _totalPower, uint256 _totalBonus) {
        uint256 _price = robotPrice;
        uint256 _power = robotPower;
        uint256 _bonus = esDMXBonus;
        uint256 _totalSupply = damxRobot.totalSupply();
        for (uint i = 0; i < numberOfTokens; i++) {
            if (_totalSupply < MAX_MMC) {
                if (_totalSupply % step == 0 && _totalSupply != 0) {
                    _price = (_price * stepPrice) / 10000;
                    _power = (_power * stepPower) / 10000;
                    _bonus = (_bonus * stepEsDMX) / 10000;
                }
                _totalPrice += _price;
                _totalPower += _power;
                _totalBonus += _bonus;
                _totalSupply = _totalSupply + 1;
            } else {
                break;
            }
        }
    }


    // @dev withdraw funds
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // @dev withdraw funds
    function withdrawERC20(address token) external onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, balance);
    }

    // @dev flips the state for sales
    function flipSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }


    // @dev set insurance fund contract address
    function setCommunityFund(address _communityFund) public onlyOwner {
        communityFund = _communityFund;
    }
    // @dev set esDMX contract address
    function setEsDMX(address _esDMX) public onlyOwner {
        esDMX = _esDMX;
    }
    // @dev set dmxVester contract address
    function setVester(address _dmxVester) public onlyOwner {
        dmxVester = _dmxVester;
    }

    // @dev sets sale info (price + power)
    function setSaleInfo(uint256 _price, uint256 _power, uint256 _esDMXBonus) external onlyOwner {
        robotPrice = _price;
        robotPower = _power;
        esDMXBonus = _esDMXBonus;
    }

    // @dev set increate Price And Power
    function setIncreaseInfo(uint256 _stepPrice, uint256 _stepPower, uint256 _step, uint256 _stepEsDMX) public onlyOwner {
        stepPrice = _stepPrice;
        stepPower = _stepPower;
        step = _step;
        stepEsDMX = _stepEsDMX;
    }
}

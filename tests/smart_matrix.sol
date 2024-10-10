/**
 *Submitted for verification at polygonscan.com on 2024-10-09
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface mainFarming {
    function userId(address user) external view returns (uint);
}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract S_M_New_22_S3 {
    struct User {
        address referrer;
        uint s3Level;
        uint s6Level;
        mapping(uint256 => address) s3Parent;
        mapping(uint256 => address) s6Parent;
        mapping(uint256 => uint256) s3Placing;
        mapping(uint256 => uint256) s6Placing;
        mapping(uint256 => uint256) s3Child;
        mapping(uint256 => uint256) s6Child;        
        mapping(uint256 => address[]) s3Downline;
        mapping(uint256 => address[]) s6Downline;
    }

    address public farmingAddress;
    address public tokenAddress;
    address public owner;

    mapping(address => User) public users;
    mapping(uint256 => uint256) public entryFees;

    uint256 public constant LEVELS = 11;
    uint256[11] public levelPart = [
        2e6, 4e6, 8e6, 10e6, 12e6, 20e6, 
        30e6, 60e6, 200e6, 300e6, 500e6
    ];

    bool allow3;
    bool allow6;
    bool bypass;

    event Registration(address indexed user, address indexed referrer);
    event RecyclePosition(address indexed user, uint256 plan, uint256 level);
    event IncomeDistributed(address indexed referrer, uint256 amount, uint256 plan, uint256 level);
    event payoutEv(address paidTo, address paidBy, uint amount, uint paymentType);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPlan(uint256 plan) {
        require(plan == 3 || plan == 6, "Invalid plan");
        _;
    }

    constructor(address _farmingAddress, address _tokenAddress) {
        owner = msg.sender;
        farmingAddress = _farmingAddress;
        tokenAddress = _tokenAddress;
        entryFees[1] = 5 * 1e6;

        users[msg.sender].referrer = msg.sender;
        for(uint i=1;i<12;i++){
            users[msg.sender].s3Parent[i] = msg.sender;
            users[msg.sender].s6Parent[i] = msg.sender;
        }

        users[msg.sender].s3Level = 11;
        users[msg.sender].s6Level = 11;
        for (uint256 i = 2; i <= LEVELS; i++) {
            entryFees[i] = entryFees[i - 1] * 2;

        }
    }


    function allowMatrix3(bool _allow) public onlyOwner() returns(bool) {
        allow3 = _allow;
        return true;
    }

    function allowMatrix6(bool _allow) public onlyOwner() returns(bool) {
        allow6 = _allow;
        return true;
    }

    function setFarmingAddress(address _farmingAddress) public onlyOwner returns (bool) {
        farmingAddress = _farmingAddress;
        return true;
    }

    function setTokenAddress(address _tokenAddress) public onlyOwner returns (bool) {
        tokenAddress = _tokenAddress;
        return true;
    }

    function ignoreRegInFarm(bool _ignore) public onlyOwner() returns(bool) {
        bypass = _ignore;
        return true;
    }

    function register(address referrer) public {
        if(!bypass) require(mainFarming(farmingAddress).userId(msg.sender) > 0, "Register in main farm first");
        require(users[msg.sender].referrer == address(0), "User already registered");
        require(referrer != address(0) && referrer != msg.sender, "Invalid referrer");

        users[msg.sender].referrer = referrer;
        if(allow3) _entry(referrer, 3, 1);
        if(allow6) _entry(referrer, 6, 1);
        emit Registration(msg.sender, referrer);
    }

    function buyPlan(uint256 plan, uint level) public validPlan(plan) {
        require(level > 1, "register first");
        if(plan == 3 ) require(allow3, "plan not allowed");
        else if(plan == 6) require(allow6, "Plan not allowed");
        address referrer = users[msg.sender].referrer;
        _entry(referrer, plan, level);
    }

    function _entry(address referrer, uint256 plan, uint level) internal validPlan(plan) {
        require(plan == 3 ? users[msg.sender].s3Level == level - 1 : users[msg.sender].s6Level == level - 1, "Level already bought or buy previous level first");

        uint256 fee = entryFees[level];
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), fee + levelPart[level-1]);

        if (plan == 3) {
            users[msg.sender].s3Level = level;
            _placeInMatrixS3(referrer, msg.sender, level);
        } else {
            users[msg.sender].s6Level = level;
            _placeInMatrixS6(referrer, msg.sender, level);
        }

        payLevelIncome(msg.sender, level);
    }

    function payLevelIncome(address _user, uint level) internal returns (bool)
    {        
        uint[5] memory div = [uint(40), uint(25), uint(15), uint(10), uint(10)];
        uint part = levelPart[level-1];
        address usr = users[_user].referrer;
        if(usr == address(0)) usr = payable(owner);
        for(uint i = 0; i < 5; i++)
        {
            sendToken(usr, part * div[i] / 100, 0);
            usr = users[usr].referrer;
            if(usr == address(0)) usr = payable(owner);
        }
        return true;
    }


    function _placeInMatrixS3(address referrer, address user, uint256 level) internal {
        address parent = findFreeReferrer3(referrer,level);
        if (parent == address(0)) parent = owner;
        User storage parentUser = users[parent];


            parentUser.s3Downline[level].push(user);
            parentUser.s3Child[level]++;
            if(parent != owner) users[users[parent].s3Parent[level]].s3Child[level]++;
            users[user].s3Parent[level] = parent;
            users[user].s3Placing[level] = parentUser.s3Downline[level].length ;
            uint payNow = checkPayout(user, 3, level);
            if(payNow == 0) _distributeIncomeS3(user, level, false);
            else if (payNow == 1 ) _distributeIncomeS3(user, level, true);

            address recycleUser = users[user].s3Parent[level];
            recycleUser = users[recycleUser].s3Parent[level];
            if (isRecycle(recycleUser, 3, level)) _recyclePosition(recycleUser, 3, level);
 
    }


    function _placeInMatrixS6(address referrer, address user, uint256 level) internal {
        address parent = findFreeReferrer6(referrer,level);
        if (parent == address(0)) parent = owner;
        User storage parentUser = users[parent];

            parentUser.s6Downline[level].push(user);
            parentUser.s6Child[level]++;
            if(parent != owner) users[users[parent].s6Parent[level]].s6Child[level]++;            
            users[user].s6Parent[level] = parent;
            users[user].s6Placing[level] = parentUser.s6Downline[level].length;
            uint recycle = checkPayout(user, 6, level);
            if(recycle == 0) _distributeIncomeS6(user, level, false);
            else if (recycle == 1 ) _distributeIncomeS6(user, level, true);


            address recycleUser = users[user].s6Parent[level];
            recycleUser = users[recycleUser].s6Parent[level];
            if (isRecycle(recycleUser, 6, level)) _recyclePosition(recycleUser, 6, level);

    }

    function checkPayout(address _user, uint8 _plan, uint level) internal view returns(uint) {
        uint p1;
        uint p2;
        if(_plan == 3) {
            p1 = users[_user].s3Placing[level];            
            p2 = users[users[_user].s3Parent[level]].s3Placing[level];
            if( (p1 == 2 &&  p2 == 2) || (p1 == 1 && p2 == 2 )) return 1;
            else return 0;
        }
        else if ( _plan == 6) {
            p1 = users[_user].s6Placing[level];            
            p2 = users[users[_user].s6Parent[level]].s6Placing[level];
            if( (p1 == 3 &&  p2 == 3) || ( p1 == 2 && p2 == 3 )) return 1;
            else return 0;
        }
        return 0;   
    }

    function checkPayoutView(address _user, uint8 _plan, uint level) public view returns(uint,uint) {
        uint p1;
        uint p2;
        if(_plan == 3) {
            p1 = users[_user].s3Placing[level];            
            p2 = users[users[_user].s3Parent[level]].s3Placing[level];
            return (p1, p2);
        }
        else if ( _plan == 6) {
            p1 = users[_user].s6Placing[level];            
            p2 = users[users[_user].s6Parent[level]].s6Placing[level];
            return (p1, p2);
        }
        return (p1,p2);   
    }

    function isRecycle(address _user, uint8 _plan, uint level) public view returns(bool) {
        if(_plan == 3) {
            if (users[_user].s3Child[level] == 6 ) return true;
        }
        else if ( _plan == 6) {
            if (users[_user].s6Child[level] == 12 ) return true;
        }
        return false;   
    }

    function _distributeIncomeS3(address _user, uint256 level, bool _half) internal {
        uint256 income = entryFees[level] * 9 / 20;
        address usr = getLevelRef(_user, level, 3); //users[_user].s3Parent[level];
        sendToken(usr, income, 1);
        emit IncomeDistributed(usr, income, 3, level);
        if(_half) return;
        usr =  getLevelRef(usr, level, 3); // users[usr].s3Parent[level];
        sendToken(usr, income, 2);
        emit IncomeDistributed(usr, income, 3, level);
    }

    function _distributeIncomeS6(address _user, uint256 level, bool _half) internal {
        uint256 income = entryFees[level] * 9 / 20;
        address usr =  getLevelRef(_user, level, 6); //users[_user].s6Parent[level];
        sendToken(usr, income, 3);
        emit IncomeDistributed(usr, income, 6, level);
        if(_half) return;
        usr =  getLevelRef(usr, level, 6); //users[usr].s6Parent[level];
        sendToken(usr, income, 4);
    }


    function getLevelRef(address usr, uint level, uint plan) internal view returns(address) {
        if(plan == 3) {
            usr = users[usr].s3Parent[level];
            for (uint i=0; i<21;i++)
            {
                if (usr != address(0) && users[usr].s3Level >= level) return usr;
                usr = users[usr].s3Parent[level];
            }
        }
        else if (plan == 6) {
            usr = users[usr].s6Parent[level];
            for (uint i=0; i<21;i++)
            {
                if (usr != address(0)  && users[usr].s6Level >= level) return usr;
                usr = users[usr].s6Parent[level];
            }
        }
        return owner;
    }

    function _recyclePosition(address user, uint256 plan, uint256 level) internal {
        if (plan == 3) {

            address ref = findFreeReferrer3(user,level);
            delete users[user].s3Downline[level];
            users[user].s3Child[level] = 0;
            _placeInMatrixS3(ref, user, level);
        } else {
            address ref = findFreeReferrer6(user,level);
            delete users[user].s6Downline[level];
            users[user].s6Child[level] = 0;
            _placeInMatrixS6(ref, user, level);
        }

        emit RecyclePosition(user, plan, level);
    }

    function findFreeReferrer3(address _user, uint _level) public view returns(address) {
        if(users[_user].s3Downline[_level].length < 2) return _user;

        address[] memory referrals = new address[](126);
        referrals[0] = users[_user].s3Downline[_level][0];
        referrals[1] = users[_user].s3Downline[_level][1];

        address freeReferrer;
        bool noFreeReferrer = true;

        for(uint i = 0; i < 126; i++) {
            if(users[referrals[i]].s3Downline[_level].length == 2) {
                if(i < 62) {
                    referrals[(i+1)*2] = users[referrals[i]].s3Downline[_level][0];
                    referrals[(i+1)*2+1] = users[referrals[i]].s3Downline[_level][1];
                }
            }
            else {
                noFreeReferrer = false;
                freeReferrer = referrals[i];
                break;
            }
        }

        require(!noFreeReferrer, 'No Free Referrer');

        return freeReferrer;
    }

    function findFreeReferrer6(address _user, uint _level) public view returns(address) {
        if(users[_user].s6Downline[_level].length < 3) return _user;

        address[] memory referrals = new address[](363);
        referrals[0] = users[_user].s6Downline[_level][0];
        referrals[1] = users[_user].s6Downline[_level][1];
        referrals[2] = users[_user].s6Downline[_level][2];

        address freeReferrer;
        bool noFreeReferrer = true;

        for(uint i = 0; i < 126; i++) {
            if(users[referrals[i]].s6Downline[_level].length == 3) {
                if(i < 120) {
                    referrals[(i+1)*3] = users[referrals[i]].s6Downline[_level][0];
                    referrals[(i+1)*3+1] = users[referrals[i]].s6Downline[_level][1];
                    referrals[(i+1)*3+2] = users[referrals[i]].s6Downline[_level][2];
                }
            }
            else {
                noFreeReferrer = false;
                freeReferrer = referrals[i];
                break;
            }
        }

        require(!noFreeReferrer, 'No Free Referrer');

        return freeReferrer;
    }

    function withdraw(uint _amount) public onlyOwner {
        sendToken(owner, _amount, 5);
    }

    function updateEntryFee(uint256 level, uint256 newFee) public onlyOwner {
        require(level > 0 && level <= LEVELS, "Invalid level");
        entryFees[level] = newFee;
    }
    
    function sendToken(address _user, uint _amount, uint _type) internal {
        IERC20(tokenAddress).transfer(_user, _amount);
        emit payoutEv(_user, msg.sender, _amount, _type);
    }

    function getS3Downline(address user, uint256 level) public view returns (address[] memory) {
        return users[user].s3Downline[level];
    }

    function getS6Downline(address user, uint256 level) public view returns (address[] memory) {
        return users[user].s6Downline[level];
    }

    function getS3ChildCount(address user, uint256 level) public view returns (uint) {
        return users[user].s3Child[level];
    }

}
pragma solidity ^0.4.0;

contract StringSet {
    string[] internal keys;
    
    function push(string value) internal {
        if (!contains(value)) {
            keys.push(value);
        }
    }
    
    function get(uint8 i) public returns (string out) {
        require(i < keys.length);
        out = keys[i];
    }
    
    function contains(string value) internal returns (bool out) {
        out = false;
        for (uint i = 0; i < keys.length; i++) {
            if (keccak256(value) == keccak256(keys[i])) {
                out = true;
                break;
            }
        }
    }
}

contract AddressSet {
    address[] internal keys;
    
    function push(address value) internal {
        if (!contains(value)) {
            keys.push(value);
        }
    }
    
    function get(uint8 i) public returns (address out) {
        require(i < keys.length);
        out = keys[i];
    }
    
    function contains(address value) internal returns (bool) {
        for (uint i = 0; i < keys.length; i++) {
            if (value == keys[i]) {
                return true;
            }
        }
        return false;
    }
}

contract Dict {
    address public_key;
    StringSet internal keys;
    mapping(string => string) values;
    
    function getData(string key) public view returns (string) { return values[key]; }
    
    function setData(string key, string value) internal {
        keys.push(key);
        values[key] = value;
    }
    
    function setData(Dict other) internal {
        for (uint i = 0; i < other.keys.keys.length; i++) {
            k = other.keys[i];
            keys.push(k);
            values[k] = other.getData(k);
        }
    }
    
    function contains(string key) public view returns (bool) { return keys.contains(key); }
}

contract Request {
    Ballot ballot;
    address request_by;
    string[] qualifications;
    Dict information;
    mapping(address => bool) votes;
    AddressSet voters;
    AddressSet voted;
    uint repoll_date;
    bool isConsensus;
    bool isTrue;
    
    uint constant wait_time = 10;
    int constant poll_count = 10;
    
    function Request(Ballot _ballot,
                     Dict _information,
                     string[] _qualifications) public payable {
        ballot = _ballot;
        request_by = msg.sender;
        information = _information;
        qualifications = _qualifications;
        repoll_date = now - 1;
        poll_voters();
    }
    
    function poll_voters() public {
        require(now > repoll_date);
        require(voted.keys.length < poll_count);
        voters = ballot.select_users(poll_count - voted.keys.length);
        for (uint i = 0; i < voters.length; i++) {
            ballot.AskToVerify(voters[i], this);
        }
        repoll_date = now + wait_time;
    }
    
    function vote(bool isTrue) public payable {
        require(voters.contains(msg.sender));
        require(!voted.contains(msg.sender));
        require(now < repoll_date);
        votes[msg.sender] = isTrue;
        voted.push(msg.sender);
        if (isDone()) {
            post_results();
        }
    }
    
    function isDone() public view returns (bool out) {
        out = voted.keys.length >= poll_count;
    }
    
    function calc_consensus() private returns (bool) {
        first_vote = votes[voted.get(0)];
        for (uint i = 1; i < voted.length; i++) {
            if (votes[voted.get(i)] != first_vote) {
                return false;
            }
        }
        return true;
    }
    
    function calc_value() private returns (bool consensus) {
        consensus = votes[voted.get(0)];
        for (uint i = 1; i < voted.length; i++) {
            consensus = consensus && votes[voted.get(i)];
        }
    }
    
    function getConsensus() public view returns (bool) { return isConsensus; }
    function getTruth() public view returns (bool) { return isTrue; }
    
    function post_results() private {
        require(isDone());
        isConsensus = calc_consensus();
        isTrue = calc_value();
        if (isTrue) {
            ballot.data.setData(information);
        }
        for (uint i = 0; i < voted.keys.length; i++) {
            ballot.updateScore(voted.get(i), isConsensus)
        }
        
    }
    
}

import "eth-random/contracts/Random.sol";

contract Ballot {
    Dict data;
    address[] users;
    mapping(address => int) scores;
    Random rand = Random(0x0230CfC895646d34538aE5b684d76Bf40a8B8B89);
    
    event AskToVerify(address user, Request request);
    
    function Ballot(address[] initial_users, Dict _data) public {
        for (uint i = 0; i < initial_users.length; i++) {
            addUser(initial_users[i])
        }
        data = _data;
    }
    
    function addUser(address user) {
        users.push(user);
        scores[user] = 0;
    }
    
    function select_users(uint8 number, AddressSet excluded) private returns (address[] query) {
        require(number < users.length - excluded.keys.length);
        query = new AddressSet();
        while (query.keys.length < number) {
            address voter = users[rand.random(users.length)-1];
            if (!excluded.contains(voter)) {
                query.push(voter);
            }
        }
    }
    
    function updateScore(address user, bool isConsensus) {
        if (isConsensus) {
            scores[user] += 1
        } else {
            scores[user] -= 1
        }
    }
    
}

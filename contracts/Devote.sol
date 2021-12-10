// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Counters.sol";

contract Devote{
    using Counters for Counters.Counter;
    Counters.Counter private _pollId;

    struct Poll{
        address creator;
        bool customChoice;
        bool active;
        uint8 size;
        uint256 endTime;
        string pollData;
    }
    mapping(uint256=>string) private pollToCode;
    mapping(uint256=> uint32[]) private idToChoices;
    mapping(uint256 => Poll) public idToPoll;
    mapping(uint256 => mapping(address=>bool)) private votesCasted;
    event Vote(uint256 id, address voter);
    event PollEnd(uint256 id, uint256 time);
    
    modifier hasNotVoted (uint256 _id) {
        require(!votesCasted[_id][msg.sender], "Already voted");
        _;
    }
    modifier isActive(uint256 _id){
        require(idToPoll[_id].active, "Voting ended");
        _;
    }
    
    function checkCode(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }
    function createPoll( bool _customChoice, string memory _code, uint16 _time, string memory _pollData, uint8 _size ) external {
        require(_size<=30, "Poll can have a maximum of 30 options");
        _pollId.increment();
        uint256 currentId = _pollId.current();
        idToPoll[currentId] = Poll({ customChoice: _customChoice,
        creator: msg.sender,
        size: _size,
        active: true,
        endTime: block.timestamp + _time*3600, //Time is in hours
        pollData: _pollData });
        pollToCode[currentId] = _code;
        idToChoices[currentId] = _customChoice ? new uint32[](30): new uint32[](_size);
    }
    function vote(uint256 _id, uint8 _index) external hasNotVoted(_id) isActive(_id){
        if(msg.sender != address(this)) require(bytes(pollToCode[_id]).length==0, "Private poll");
        require(_index<=idToPoll[_id].size-1);
        idToChoices[_id][_index]++;
        votesCasted[_id][tx.origin] = true;
        emit Vote(_id, tx.origin);
    }
    function votePrivate(uint256 _id, uint8 _index, string memory _code) external hasNotVoted(_id) isActive(_id){
        require(checkCode(pollToCode[_id], _code), "Code mismatch");
        this.vote(_id, _index);
    }
    function voteCustom(uint256 _id, string memory _newData) external hasNotVoted(_id) isActive(_id){
        require(idToPoll[_id].customChoice, "Custom choices not allowed"); //CODE 
        if(msg.sender != address(this)) require(bytes(pollToCode[_id]).length==0, "Private poll");
        idToPoll[_id].pollData = _newData;
        uint8 idx = idToPoll[_id].size;
        idToChoices[_id][idx]++;
        idToPoll[_id].size++;
        votesCasted[_id][tx.origin] = true;
        emit Vote(_id, tx.origin);
    }
    function voteCustomPrivate(uint256 _id, string memory _newData, string memory _code) external hasNotVoted(_id) isActive(_id){
        require(checkCode(pollToCode[_id], _code), "Code mismatch");
        this.voteCustom(_id, _newData);
    }
    function endPoll(uint256 _id) external {
        require(msg.sender == idToPoll[_id].creator, "Only poll creator can end poll");
        require(block.timestamp > idToPoll[_id].endTime, "Poll still active");
        idToPoll[_id].active = false;
        emit PollEnd(_id, block.timestamp);
    }
    function getResult(uint256 _id) external view returns (uint32[] memory){
        require(!idToPoll[_id].active, "Poll still active");
        return idToChoices[_id];
    }
}
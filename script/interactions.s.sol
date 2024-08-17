// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "src/Raffle.sol";

contract CreateSubscription is Script, CodeConstants {

    function createSubscriptionUsingConfig() public returns(uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator, account);
        return(subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, address account) public returns(uint256, address) {
            console.log("creating subscription on chain ID: ", block.chainid);
            vm.startBroadcast(account);
            uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
            vm.stopBroadcast();
            console.log("subscription created with ID: ", subId);
            return(subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; // equals to 3 LINK Tokens

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account) public {
        console.log("Funding Subscription: ", subscriptionId);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("On Chain ID: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        }else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address VRFCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed, VRFCoordinator, subId, account);
    }

    function addConsumer(address mostRecentlyDeployed, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract: ", mostRecentlyDeployed);
        console.log("On VRFCoordinator: ", vrfCoordinator);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, mostRecentlyDeployed);
        vm.stopBroadcast();
    }

    function run() public {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/interactions.s.sol";

contract DeployRaffle is Script {
    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local -> Deploy mocks and get anvil configs
        // testnet -> get testnet configs

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionId == 0){
            // create Subscription
            CreateSubscription subscriptionContract = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = subscriptionContract.createSubscription(config.vrfCoordinator, config.account);

            // fund subscription
            FundSubscription fundSubscriptionContract = new FundSubscription();
            fundSubscriptionContract.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link, config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer consumerContract = new AddConsumer();
        // Do not want to add broadcast as we have already added it in the addConsumer function
        consumerContract.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);

        return (raffle, helperConfig);
    }
}

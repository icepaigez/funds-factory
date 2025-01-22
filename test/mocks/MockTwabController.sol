// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TwabController} from "pt-v5-twab-controller/src/TwabController.sol";

contract MockTwabController is TwabController {
    constructor(
        uint32 _periodLength,
        uint32 _periodOffset
    ) TwabController(_periodLength, _periodOffset) {}
}

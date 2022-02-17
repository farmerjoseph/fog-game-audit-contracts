// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

// Check Crop.sol constructor if modifying this
enum CropType {
    // Grains
    RICE, 
    WHEAT,
    // Fruits
    APPLE,
    BANANA,
    GRAPE,
    TOMATO,
    WATERMELON,
    KIWI,
    PINEAPPLE,
    STRAWBERRY,
    // Vegetables
    LETTUCE,
    CARROT,
    EGGPLANT,
    PUMPKIN,
    TURNIP,
    // Cosmic
    MOON_FRUIT,
    GALAXY_CORN,
    VOLCANO_COCOA,
    MILKY_WAY_SUGARCANE,
    SOLAR_PEPPER
}

enum Taste {
    SPICY,
    SWEET,
    TART,
    SALTY
}

enum Origin {
    MOUNTAINS,
    OCEAN,
    ARCTIC,
    ASTEROID,
    LAB,
    OLYMPUS,
    FOREST
}

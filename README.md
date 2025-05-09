# MNS Airdrops

A feature-rich airdrop script for FiveM servers running QBCore/QBox frameworks.

## Features

- Customizable airdrops at random locations
- Configurable loot tables and item quantities
- Realistic plane flight path and parachute drop
- Distance-based sound system (only hear sounds when nearby)
- UI framework agnostic - supports both QBCore and Ox frameworks
- Admin commands for testing

## Dependencies

- QBCore or QBox framework
- ox_lib
- Target system (supports both ox_target and qb-target)

## Installation

1. Download the latest release
2. Extract to your resources folder
3. Add `ensure mns-airdrops` to your server.cfg
4. Configure the settings in `config/config.lua`

## Configuration

The script includes extensive configuration options:

- UI framework selection (QBCore or Ox)
- Sound distance thresholds
- Notification templates
- Drop locations
- Aircraft options
- Loot tables

### Framework Compatibility

MNS Airdrops can work with different UI components:

```lua
UI = {
   inventory = 'qb',  -- Options: 'qb', 'ox'
   progressBar = 'ox', -- Options: 'qb', 'ox'
   notification = 'qb', -- Options: 'qb', 'ox', 'custom'
   target = 'ox', -- Options: 'qb', 'ox'
},
```

## Admin Commands

- `/testairdrop` - Spawns a test airdrop at a random location (Admin only)

## Preview

Coming soon...



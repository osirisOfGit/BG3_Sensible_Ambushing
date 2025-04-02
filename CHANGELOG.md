# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# [1.1.0]
## Added
- Feature to replicate stealth rules for characters affected by some form of invisibility

# [1.0.0]
## Added
- Toggleable passive to in/exclude party members from eligibility
- Distance-based eligibility

# [0.5.1]

## Changed

- Add the `DisableCombatlog` flag to the `SNEAKING` status, preventing combat log spam
- `than` to `then` in one of the MCM lines
- Remove Proficiency tracker for Stealth Actions when a character is seen

# [0.5.0]

## Added

- Stealth Action logic - too much functionality to describe here, but TLDR is acting while sneaking no longer automatically removes sneaking, ghost position is randomized during combat, and the attacking char's summon is automatically brought in with them

## Changed

- Only roll stealth checks against enemies that have LOS to you and are capable of spotting sneakers
- Failing a stealth check initiated by this mod will cause the enemy you failed against to look at you, forcing a hide check if you're within their sight cone
- Protected common Event functions to catch exceptions and log the errors
- Enhanced logging

## Fixes

- Corrected description for Surprise in MCM - all actions that trigger combat are now supported

# [0.4.0]

## Changed

- Surprise Mechanics
  - Works for all actions now

- Logging timestamps - this is not really accurate to system time, should be used more for relative timing between logs
- Clearing log on SE load

# [0.3.0]

## Added

- Surprise Mechanics
  - Triggering surprise on any targeted action when done from stealth
  - Saving throw on status
  
# [0.2.2]

## Fixed

- Using Automatic Inventory Manager's ModTable, causing issues with MCM

# [0.2.1]

## Fixed

- Wrap prone logic in enabled flag

# [0.2.0]

## Added

- Characters 'tripping' if they critically fail their ambush stealth check, going prone for a round
- Characters with metal equipped can attract nearby allies/enemies to their position when going prone
  - This can apply to any character in the game - ally/enemy determinations are made based on the party though (i.e. only attracting allies, but triggering the effect on enemies, will attract allies of the player, not the enemy)
- Generating an ash surface when changing any configs that deal with radii

## Changed

- Tweaked MCM configs

# [0.1.0]

## Added

- Preventing enemies from knowing where sneaking chars are during the ambush, unless the char fails their passive Stealth check against the enemy's Perception
- MCM options for enabling the mod and changing the log level

## Changed

- Internal refactor to support pre- and post- ambush functions for more flexibility later
- Internal refactor to create Ambush "modules", introducing an API method to allow other mods to register their own

<br/>

# [0.0.1]

## Added

- Party members join combat stealthed w/ summons
- MCM integration included

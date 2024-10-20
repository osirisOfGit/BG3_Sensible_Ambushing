# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

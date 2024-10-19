# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# [0.2.0] (Unreleased)

## Added

- Characters 'tripping' if they fail their ambush stealth check
  - Characters wearing metal armor can attract nearby allies/enemies

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

# TODO

- [x] Find a way to prevent enemies knowing where stealthed characters were on ambush start
  - [ ] Add an 'Ambushing' status to clearly communicate the missing 'Ghost' isn't a visual glitch
  - [ ] Add a status to indicate that a character is ambushing, but alerted the enemy due to failed check, for flavour
  - [x] Add the ability to de-sneak a character if they critically fail their stealth check, triggering prone ('tripping' them)
    - [x] Add ~~Thunderclap~~ (hacked in an existing "destroying metal door" noise) animation/sound/noise effect to characters that 'trip' while wearing Metal armor
      - [ ] Make pushing/knocking back a character count as prone? Or have the same effect
- [ ] Prevent attacking from sneak before combat from removing sneak status
  - [ ] "Ghost" of ambusher changes position depending on their obscuredState and stealth save?
- [ ] Force surprise on enemies when attacking them
  - [ ] Apply for area-of-effect spells and things like Minor Illusion as well - need to figure out how to find the radius of a spell
  - [ ] Before combat starts (exclusive MCM options):
    - [x] When stealthed
    - [ ] When not stealthed and not in sight of enemy?
    - [ ] When not stealthed and in sight of enemy?
  - [ ] On crit from stealthed char during combat?
- [ ] Add a toggleble passive to exclude party members from ambushes
- [ ] Distance-based eligibility
  - [ ] Implement Surface when messing with MCM value to show how big the radius is? Or find a more sensible way of doing that
- [ ] Sight-based eligibility
- [ ] Teleporting far away party members to the ambush site?
- [ ] I'm 100% sure there's gonna be multiplayer shenanigans i'll have to deal with
  - [ ] MCM notification allowing other players to opt in and have rules run?
- [ ] Flavour notification? "AMBUSH SUCCESSFUL" or something?

## Long-Term goals

- I wanted to add a counter-insight check if the initial stealth check fails, which players would have to pass to know if the Enemy knows they're being ambushed,
but it's not physically possible to hide the ghost just for the player - it needs to be inside the view-cone of the enemy, which means also being visible to the player.
May not be possible unless i come up with a custom stealth system

- 'Holding' actions, triggering like a reaction when the enemy is in range

- Give veteran characters (e.g. slaver in the underdark) a higher chance to resist surprise/detect ambushes

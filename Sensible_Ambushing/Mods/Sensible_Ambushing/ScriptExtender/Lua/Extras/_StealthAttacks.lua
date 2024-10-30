-- https://discord.com/channels/1174823496086470716/1295911710678323353/1299130898741985373

Ext.Vars.RegisterUserVariable("Sensible_Ambushing_Stealth_Action_Tracker", {
	Server = true
})

-- Weapon attacks are spells too - i.e. https://bg3.norbyte.dev/search?q=type%3Aspell+Ranged+%26+Attack#result-eda1854279be71702cf949e192e8b08a2839b809
EventCoordinator:RegisterEventProcessor("CastSpell", function(caster, spell, _, _, _)
	local attacker_entity = Ext.Entity.Get(caster)
	local stealth_tracker = attacker_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}
	local action_counter = stealth_tracker.Counter or 0

	if Osi.HasActiveStatus(caster, "SNEAKING") == 1 and Osi.SpellHasSpellFlag(spell, "Stealth") == 0 then
		stealth_tracker.Counter = action_counter + 1
		stealth_tracker.SpellCast = spell

		if Osi.IsInCombat(caster) == 0 then
			Ext.Timer.WaitFor(3000, function()
				-- cuz caching - https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#caching-behavior
				if attacker_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker and Osi.IsInCombat(caster) == 0 then
					Logger:BasicDebug("%s acted from stealth and was eligible to stealth attack, but they didn't enter combat, so removing tracker", caster)

					attacker_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
				end
			end)
		end
	end
	attacker_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = stealth_tracker
end)

EventCoordinator:RegisterEventProcessor("CombatStarted", function(combatGuid)
	for _, ambushingCombatMember in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
		ambushingCombatMember = ambushingCombatMember[1]
		local entity = Ext.Entity.Get(ambushingCombatMember)
		local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}

		if stealth_tracker.Counter then
			-- Just in case there's some gap in events and it doesn't get reset
			stealth_tracker.Counter = 1
			Logger:BasicDebug("%s acted from stealth and should keep their stealth in combat, so doing that", ambushingCombatMember)

			Osi.ApplyStatus(ambushingCombatMember, "SNEAKING", -1)

			for _, enemyCombatant in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
				enemyCombatant = enemyCombatant[1]

				if Osi.IsEnemy(ambushingCombatMember, enemyCombatant) == 1
					and Osi.CanSpotSneakers(enemyCombatant) == 1
					and Osi.HasLineOfSight(enemyCombatant, ambushingCombatMember) == 1
				then
					Osi.RequestPassiveRollVersusSkill(ambushingCombatMember,
						enemyCombatant,
						"SkillCheckRoll",
						"Stealth",
						"Perception",
						0,
						0,
						"Sensible_Ambush_Stealth_Action_Check_" .. ModuleUUID)
				end
			end

			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = stealth_tracker
			return
		end
	end
end)

EventCoordinator:RegisterEventProcessor("RollResult", function(eventName, stealthActor, enemy, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Stealth_Action_Check_" .. ModuleUUID then
		Logger:BasicTrace("Processing Ambush Stealth Action check for %s against %s with result %s and criticality %s",
			stealthActor,
			enemy,
			resultType,
			criticality)

		local entity = Ext.Entity.Get(stealthActor)
		local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}

		if resultType == 1 then
			local entity = Ext.Entity.Get(stealthActor)

			if entity.Stealth then
				local position = entity.Stealth.Position
				local newPosition = { Osi.FindValidPosition(
					Ext.Math.Random(-10, 10) + position[1],
					-- don't wanna change the y axis, too many considerations and it doesn't make much sense anyway
					position[2],
					Ext.Math.Random(-10, 10) + position[3],
					3,
					stealthActor,
					0
				) }

				Logger:BasicTrace("%s's original ghost changed from \n\t[x/y/z] = %s/%s/%s \nto\n\t[x/y/z] = %s/%s/%s",
					stealthActor,
					position[1],
					position[2],
					position[3],
					newPosition[1],
					newPosition[2],
					newPosition[3]
				)
				entity.Stealth.Position = newPosition
				entity:Replicate("Stealth")
			end
		end
	end
end)


Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function(char, _)
	local entity = Ext.Entity.Get(char)
	if entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
		Logger:BasicTrace("%s left combat and had the stealth attack counter - resetting", char)
		entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
	end
end)

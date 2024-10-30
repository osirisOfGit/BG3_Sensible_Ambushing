-- https://discord.com/channels/1174823496086470716/1295911710678323353/1299130898741985373

Ext.Vars.RegisterUserVariable("Sensible_Ambushing_Stealth_Action_Tracker", {
	Server = true
})

local function RollStealthAgainstEnemies(stealthActor)
	for _, enemyCombatant in pairs(Osi.DB_Is_InCombat:Get(nil, Osi.CombatGetGuidFor(stealthActor))) do
		enemyCombatant = enemyCombatant[1]

		if Osi.IsEnemy(stealthActor, enemyCombatant) == 1
			and Osi.CanSpotSneakers(enemyCombatant) == 1
			and Osi.HasLineOfSight(enemyCombatant, stealthActor) == 1
		then
			Osi.RequestPassiveRollVersusSkill(stealthActor,
				enemyCombatant,
				"SkillCheckRoll",
				"Stealth",
				"Perception",
				0,
				0,
				"Sensible_Ambush_Stealth_Action_Check_" .. ModuleUUID)
		end
	end
end

-- Weapon attacks are spells too - i.e. https://bg3.norbyte.dev/search?q=type%3Aspell+Ranged+%26+Attack#result-eda1854279be71702cf949e192e8b08a2839b809
EventCoordinator:RegisterEventProcessor("CastSpell", function(caster, spell, _, _, _)
	local caster_entity = Ext.Entity.Get(caster)
	local stealth_tracker = caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}

	if Osi.HasActiveStatus(caster, "SNEAKING") == 1 and Osi.SpellHasSpellFlag(spell, "Stealth") == 0 then
		stealth_tracker.Counter = (stealth_tracker.Counter or 0) + 1
		stealth_tracker.SpellCast = spell

		if Osi.IsInCombat(caster) == 0 then
			Ext.Timer.WaitFor(3000, function()
				-- cuz caching - https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#caching-behavior
				if caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker and Osi.IsInCombat(caster) == 0 then
					Logger:BasicDebug("%s acted from stealth and was eligible to stealth attack, but they didn't enter combat, so removing tracker", caster)
					caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
				end
			end)
		else
			RollStealthAgainstEnemies(caster)
		end
		caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = stealth_tracker
	else
		caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
	end
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

			RollStealthAgainstEnemies(ambushingCombatMember)

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

		if resultType == 1 and entity.Stealth then
			local position = entity.Stealth.Position
			local newPosition = { Osi.FindValidPosition(
				(Ext.Math.Random(-10, 10) / stealth_tracker.Counter) + position[1],
				-- don't wanna change the y axis, too many considerations and it doesn't make much sense anyway
				position[2],
				(Ext.Math.Random(-10, 10) / stealth_tracker.Counter) + position[3],
				3,
				stealthActor,
				0
			) }

			Logger:BasicTrace("%s's original ghost changed from \n\t[x/y/z] = %s/%s/%s\n\tto\n\t[x/y/z] = %s/%s/%s",
				stealthActor,
				position[1],
				position[2],
				position[3],
				newPosition[1],
				newPosition[2],
				newPosition[3]
			)

			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker.LastGhostPosition = newPosition

			entity.Stealth.Position = newPosition
			entity:Replicate("Stealth")
		end
	end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(char, status, causee, _)
	if status == "SNEAKING" then
		local entity = Ext.Entity.Get(char)
		if entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
			Logger:BasicTrace("%s lost sneaking due to %s, but still had their tracker, so reapplying sneak", char, causee)
			Osi.ApplyStatus(char, status, -1, 0)
		end
	end
end)

EventCoordinator:RegisterEventProcessor("StatusApplied", function(char, status, _, _)
	if status == "SNEAKING" then
		local entity = Ext.Entity.Get(char)
		local tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker
		if tracker and tracker.LastGhostPosition then
			Logger:BasicTrace("%s had sneaking applied, so fixing their ghost according to tracker", char)

			entity.Stealth.Position = tracker.LastGhostPosition
			entity:Replicate("Stealth")

			-- Need to modify the object directly, not the local memory reference
			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker.LastGhostPosition = nil
		end
	end
end)

Ext.Osiris.RegisterListener("Saw", 3, "after", function(character, targetCharacter, targetWasSneaking)
	if targetWasSneaking == 1 and Osi.IsPartyMember(character, 1) == 0 then
		local entity = Ext.Entity.Get(targetCharacter)
		if entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
			Logger:BasicTrace("%s lost sneaking due to %s seeing them, so clearing their tracker", targetCharacter, character)
			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
		end
	end
end)

Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function(char, _)
	local entity = Ext.Entity.Get(char)
	if entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
		Logger:BasicTrace("%s left combat and had the stealth action tracker - resetting", char)
		entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
	end
end)

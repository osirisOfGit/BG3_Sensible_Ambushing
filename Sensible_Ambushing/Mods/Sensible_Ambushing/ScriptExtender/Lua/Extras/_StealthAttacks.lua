-- https://discord.com/channels/1174823496086470716/1295911710678323353/1299130898741985373

Ext.Vars.RegisterUserVariable("Sensible_Ambushing_Stealth_Action_Tracker", {
	Server = true
})

Ext.Vars.RegisterUserVariable("Sensible_Ambushing_Stealth_Proficiency", {
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

local not_enemy_pattern = "not%s+([a-zA-Z_]*Enemy%()"
local ally_pattern = "([a-zA-Z_]*Ally%()"
--- Determine if the spell has the `Ally(` or `not Enemy(` TargetConditions, making it non-hostile
--- Some mods, like https://www.nexusmods.com/baldursgate3/mods/3940, replace these functions with their
--- own varieties. We can't predict what a mod author is going to do, so we're hoping they at least follow the
--- not *Enemy( and *Ally( pattern
local function IsHostileSpell(spell)
	local str = Ext.Stats.Get(spell).TargetConditions

	local enemy_match = str:match(not_enemy_pattern)
	if enemy_match then
		return false
	end

	local ally_match = str:match(ally_pattern)
	if ally_match and not str:match("not%s+" .. ally_match) then
		return false
	end

	return true
end

-- Weapon attacks are spells too - i.e. https://bg3.norbyte.dev/search?q=type%3Aspell+Ranged+%26+Attack#result-eda1854279be71702cf949e192e8b08a2839b809
EventCoordinator:RegisterEventProcessor("CastSpell", function(caster, spell, _, _, _)
	local caster_entity = Ext.Entity.Get(caster)
	local stealth_tracker = caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}

	local spellProperties = Ext.Stats.Get(spell).SpellProperties
	if spellProperties and next(stealth_tracker) then
		for _, functorGroup in pairs(spellProperties) do
			for _, functor in pairs(functorGroup.Functors) do
				-- ApplyStatus check needs to come first, otherwise we'll get a runtime exception for StatusId missing
				if functor.TypeId == "ApplyStatus" and functor.StatusId == "SNEAKING" then
					Logger:BasicTrace("%s cast %s, which applies sneaking, so removing the stealth tracker", caster, spell)
					caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
					return
				end
			end
		end
	end

	if Osi.HasActiveStatus(caster, "SNEAKING") == 1 and Osi.SpellHasSpellFlag(spell, "Stealth") == 0 then
		local hasStealthProficiency = caster_entity.Vars.Sensible_Ambushing_Stealth_Proficiency
		if hasStealthProficiency == nil then
			if not MCM.Get("SA_stealth_actions_requires_stealth_proficiency") then
				hasStealthProficiency = true
			else
				hasStealthProficiency = false
				for _, boostEntry in pairs(Ext.Entity.Get(caster).BoostsContainer.Boosts) do
					if boostEntry.Type == "ProficiencyBonus" then
						for _, boost in pairs(boostEntry.Boosts) do
							if boost.ProficiencyBonusBoost.Skill == "Stealth" then
								Logger:BasicTrace("%s has Stealth proficiency", caster)
								hasStealthProficiency = true
								goto exit
							end
						end
					end
				end
			end
			caster_entity.Vars.Sensible_Ambushing_Stealth_Proficiency = hasStealthProficiency
			::exit::
		end

		if hasStealthProficiency then
			stealth_tracker.SpellCast = spell
			stealth_tracker.Counter = (stealth_tracker.Counter or 0) + 1

			if Osi.IsInCombat(caster) == 0 then
				if MCM.Get("SA_enable_out_of_combat_action_behavior") then
					Ext.Timer.WaitFor(Ext.Math.Round(MCM.Get("SA_delay_on_applying_sneak_out_of_combat") * 1000), function()
						-- cuz caching - https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#caching-behavior
						if caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker and Osi.IsInCombat(caster) == 0 then
							Logger:BasicDebug(
								"%s acted from stealth and was eligible to stealth attack, but they didn't enter combat, so removing tracker and reapplying SNEAKING if they're still missing it",
								caster)
							caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
							if Osi.HasActiveStatus(caster, "SNEAKING") == 0 then
								Osi.ApplyStatus(caster, "SNEAKING", -1, 0)
							end
						end
					end)
				else
					stealth_tracker = nil
				end
			else
				if MCM.Get("SA_enable_in_combat_behavior") then
					RollStealthAgainstEnemies(caster)
				else
					stealth_tracker = nil
				end
			end
			caster_entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = stealth_tracker
		end
	end
end)

EventCoordinator:RegisterEventProcessor("CombatStarted", function(combatGuid)
	if MCM.Get("SA_enable_in_combat_behavior") then
		for _, ambushingCombatMember in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
			ambushingCombatMember = ambushingCombatMember[1]
			local entity = Ext.Entity.Get(ambushingCombatMember)
			local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker

			if stealth_tracker then
				-- Just in case there's some gap in events and it doesn't get reset
				stealth_tracker.Counter = 1
				Logger:BasicDebug("%s acted from stealth and should keep their stealth in combat, so doing that", ambushingCombatMember)

				Osi.ApplyStatus(ambushingCombatMember, "SNEAKING", -1, 0)

				RollStealthAgainstEnemies(ambushingCombatMember)

				entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = stealth_tracker
				return
			end
		end
	end
end)

local function ConvertObscurityLevel(char, enemy)
	local state = string.upper(Osi.GetObscuredState(char))

	-- Blindsight - https://bg3.norbyte.dev/search?q=Blindsight#result-309760ef9587ef0c4edd1125b697524c6b143f96
	if state == "CLEAR" or Osi.IsTagged(enemy, "a49c94ac-6903-408e-8b05-86371fd865c0") == 1 then
		return 0
	end

	local darkvisionRange = 0
	for _, boostEntry in pairs(Ext.Entity.Get(enemy).BoostsContainer.Boosts) do
		if boostEntry.Type == "DarkvisionRangeMin" then
			for _, boost in pairs(boostEntry.Boosts) do
				local range = tonumber(boost.DarkvisionRangeMinBoost.Range)
				darkvisionRange = darkvisionRange < range and range or darkvisionRange
			end
			break
		end
	end

	local darkVisionSubtractor = 0
	if darkvisionRange and Osi.GetDistanceTo(char, enemy) <= darkvisionRange then
		darkVisionSubtractor = 1
		Logger:BasicTrace("%s has darkvision range of %d and is within range of %s, so reducing obscurity level by one",
			enemy,
			darkvisionRange,
			char)
	end

	if state == "LIGHTLYOBSCURED" then
		return 1 - darkVisionSubtractor
	elseif state == "HEAVILYOBSCURED" then
		return 2 - darkVisionSubtractor
	end
end

local function CalculateRandomGhostPosition(char, enemy, action_counter)
	local max_radius = MCM.Get("SA_max_radius_for_ghost_on_action")

	local randomized_pos = Ext.Math.Random(max_radius * -1, max_radius)
	local pos_sign = Ext.Math.Sign(randomized_pos)
	-- Don't wanna zero out the obscurity if randomization doesn't move the ghost
	pos_sign = pos_sign == 0.0 and 1.0 or pos_sign

	local with_obscurity = (ConvertObscurityLevel(char, enemy) * MCM.Get("SA_ghost_radius_obscurity_multiplier")) * pos_sign

	local action_counter_divisor = action_counter / MCM.Get("SA_action_counter_divisor")
	action_counter_divisor = action_counter_divisor < 1 and 1 or action_counter_divisor

	Logger:BasicTrace(
		"Calculated the following components of the Random Ghost Position algorithm for %s against %s:\n\tmax_radius = %s\n\trandomized_pos = %s\n\twith_obscurity = %s\n\taction_counter_divisor = %s",
		char,
		enemy,
		max_radius,
		randomized_pos,
		with_obscurity,
		action_counter_divisor
	)

	return ((randomized_pos + with_obscurity) / action_counter_divisor)
end

local function CalculateRandomGhostCoordinates(stealthActor, enemy, stealth_tracker, retries)
	retries = retries or 0

	local x, y, z = Osi.GetPosition(stealthActor)
	local newPosition = { Osi.FindValidPosition(
		CalculateRandomGhostPosition(stealthActor, enemy, stealth_tracker.Counter) + x,
		-- don't wanna change the y axis, too many considerations and it doesn't make much sense anyway
		y,
		CalculateRandomGhostPosition(stealthActor, enemy, stealth_tracker.Counter) + z,
		3 + retries,
		stealthActor,
		0
	) }

	if not next(newPosition) and retries <= 3 then
		retries = retries + 1
		Logger:BasicDebug("Failed to find a valid random ghost coordinate - retry attempt %s", retries)
		newPosition = CalculateRandomGhostCoordinates(stealthActor, enemy, stealth_tracker, retries)
	end

	Logger:BasicTrace("%s, with a Stealth Action Counter of %s, had their ghost moved from \n\t[x/y/z] = %s/%s/%s\n\tto\n\t[x/y/z] = %s/%s/%s",
		stealthActor,
		stealth_tracker.Counter,
		x,
		y,
		z,
		newPosition[1],
		newPosition[2],
		newPosition[3]
	)

	return newPosition
end

EventCoordinator:RegisterEventProcessor("RollResult", function(eventName, stealthActor, enemy, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Stealth_Action_Check_" .. ModuleUUID then
		local entity = Ext.Entity.Get(stealthActor)
		local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker

		if not stealth_tracker then
			return
		end
		
		Logger:BasicDebug("Processing Ambush Stealth Action check for %s against %s with result %s and criticality %s",
			stealthActor,
			enemy,
			resultType,
			criticality)

		if resultType == 1 and entity.Stealth and stealth_tracker then
			if Osi.GetDistanceTo(stealthActor, enemy) <= 9 then
				Logger:BasicDebug("Steering %s to %s as they're within 9m of each other", enemy, stealthActor)
				Osi.SteerTo(enemy, stealthActor, 0)
			end

			local newPosition = CalculateRandomGhostCoordinates(stealthActor, enemy, stealth_tracker)

			if not next(newPosition) then
				Logger:BasicInfo("Couldn't find a valid random ghost coordinate for %s - leaving it alone", stealthActor)
				return
			end

			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker.LastGhostPosition = newPosition

			entity.Stealth.Position = newPosition
			entity:Replicate("Stealth")
		else
			Osi.SteerTo(enemy, stealthActor, 0)
			if criticality == 2 then
				Logger:BasicInfo("%s critically failed their Stealth Action roll - removing sneak and tracker, and steering %s towards them", stealthActor, enemy)
				Osi.RemoveStatus(stealthActor, "SNEAKING")
				entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
				return
			end
			Logger:BasicInfo("%s failed their Stealth Action roll - steering %s towards them", stealthActor, enemy)
		end
	end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(char, status, causee, _)
	if status == "SNEAKING" then
		local entity = Ext.Entity.Get(char)
		local tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker
		if tracker then
			if Osi.IsInCombat(char) == 0 and MCM.Get("SA_enable_out_of_combat_action_behavior") then
				if IsHostileSpell(tracker.SpellCast) then
					Logger:BasicTrace(
						"%s lost sneaking due to %s and still had their tracker, but they're out of combat and cast the hostile spell [%s], so letting CombatStarted handle applying SNEAKING",
						char,
						causee,
						tracker.SpellCast)
				else
					Logger:BasicTrace(
						"%s lost sneaking due to %s and still had their tracker, but they're out of combat and cast the non-hostile spell [%s], so re-applying SNEAKING",
						char,
						causee,
						tracker.SpellCast)

					Osi.ApplyStatus(char, status, -1, 0)
				end
			elseif Osi.IsInCombat(char) == 1 and MCM.Get("SA_enable_in_combat_behavior") then
				Logger:BasicTrace("%s lost sneaking due to %s, but still had their tracker and is in combat, so reapplying sneak",
					char,
					causee,
					tracker.SpellCast)

				Osi.ApplyStatus(char, status, -1, 0)
			end
		end
	end
end)

EventCoordinator:RegisterEventProcessor("StatusApplied", function(char, status, _, _)
	if status == "SNEAKING" then
		local entity = Ext.Entity.Get(char)
		local tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker
		if tracker and tracker.LastGhostPosition and entity.Stealth then
			Logger:BasicDebug("%s had sneaking applied, so setting their ghost to coords %s/%s/%s according to tracker", char,
				tracker.LastGhostPosition[1],
				tracker.LastGhostPosition[2],
				tracker.LastGhostPosition[3])

			entity.Stealth.Position = tracker.LastGhostPosition
			entity:Replicate("Stealth")

			-- Need to modify the object directly, not the local memory reference
			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker.LastGhostPosition = nil
		end
	end
end)

Ext.Osiris.RegisterListener("Saw", 3, "after", function(character, targetCharacter, targetWasSneaking)
	if targetWasSneaking == 1 and Osi.HasActiveStatus(targetCharacter, "SNEAKING") == 0 and Osi.IsPartyMember(character, 1) == 0 then
		local entity = Ext.Entity.Get(targetCharacter)
		if entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
			Logger:BasicTrace("%s lost sneaking due to %s seeing them, so clearing their tracker", targetCharacter, character)
			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
		end
	end
end)

Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function(char, _)
	local entity = Ext.Entity.Get(char)
	if entity and entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker then
		Logger:BasicTrace("%s left combat and had the stealth action tracker - resetting", char)
		entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker = nil
		-- There could be temporary buffs/items/statuses that grant proficiency in stealth, so need to recalculate each combat
		entity.Vars.Sensible_Ambushing_Stealth_Proficiency = nil
	end
end)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
	if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId or not MCM.Get("SA_show_surface_for_radius_settings") then
		return
	end

	local value = nil
	if payload.settingId == "SA_max_radius_for_ghost_on_action" then
		-- https://bg3.norbyte.dev/search?q=Surface#result-bbcd130617bfa4089f42431fb3373dca79334542
		value = payload.value
	elseif payload.settingId == "SA_ghost_radius_obscurity_multiplier" then
		value = MCM.Get("SA_max_radius_for_ghost_on_action") + (ConvertObscurityLevel(Osi.GetHostCharacter()) * payload.value)
	elseif payload.settingId == "SA_action_counter_divisor" then
		local div_val = 2 / payload.value
		div_val = div_val < 1 and 1 or div_val

		value = (MCM.Get("SA_max_radius_for_ghost_on_action") + (ConvertObscurityLevel(Osi.GetHostCharacter()) * MCM.Get("SA_ghost_radius_obscurity_multiplier"))) / div_val
	end

	if value then
		Osi.CreateSurface(Osi.GetHostCharacter(), "SurfaceAsh", value, 1)
	end
end)

Ext.Osiris.RegisterListener("CombatRoundStarted", 2, "before", function(combatGuid, round)
	if MCM.Get("SA_enable_in_combat_behavior") and Osi.CombatGetGuidFor(Osi.GetHostCharacter()) == combatGuid then
		Logger:BasicInfo("\n====================================\nStarting Combat Round %s for Combat %s\n====================================", round, combatGuid)
	end
end)

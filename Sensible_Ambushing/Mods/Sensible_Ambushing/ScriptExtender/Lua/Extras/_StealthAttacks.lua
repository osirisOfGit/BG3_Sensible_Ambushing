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

--- Determine if the spell has the `Ally(` or `not Enemy(` TargetConditions, making it non-hostile
--- Some mods, like https://www.nexusmods.com/baldursgate3/mods/3940, replace these functions with their
--- own varieties. We can't predict what a mod author is going to do, so we're hoping they at least follow the
--- not *Enemy( and *Ally( pattern
local function IsHostileSpell(spell)
	local str = Ext.Stats.Get(spell).TargetConditions
	local enemy_pattern = "not%s+([a-zA-Z_]*Enemy%()"
	local ally_pattern = "([a-zA-Z_]*Ally%()"

	local enemy_match = str:match(enemy_pattern)
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
end)

EventCoordinator:RegisterEventProcessor("CombatStarted", function(combatGuid)
	if MCM.Get("SA_enable_in_combat_behavior") then
		for _, ambushingCombatMember in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
			ambushingCombatMember = ambushingCombatMember[1]
			local entity = Ext.Entity.Get(ambushingCombatMember)
			local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker or {}

			if stealth_tracker.Counter then
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

local function ConvertObscurityLevel(char)
	if Osi.HasActiveStatus(char, "SNEAKING_LIGHTLY_OBSCURED") then
		return 1
	elseif Osi.HasActiveStatus(char, "SNEAKING_HEAVILY_OBSCURED") then
		return 2
	end

	return 0
end
local function CalculateGhostPosition(char, action_counter)
	local max_radius = MCM.Get("SA_max_radius_for_ghost_on_action")
	local randomized_pos = Ext.Math.Random(max_radius * -1, max_radius)
	local with_obscurity = ConvertObscurityLevel(char) * MCM.Get("SA_ghost_radius_obscurity_multiplier")
	local action_counter_divisor = action_counter / MCM.Get("SA_action_counter_divisor")
	action_counter_divisor = action_counter_divisor < 1 and 1 or action_counter_divisor

	return ((randomized_pos + with_obscurity) / action_counter_divisor)
end

EventCoordinator:RegisterEventProcessor("RollResult", function(eventName, stealthActor, enemy, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Stealth_Action_Check_" .. ModuleUUID then
		Logger:BasicTrace("Processing Ambush Stealth Action check for %s against %s with result %s and criticality %s",
			stealthActor,
			enemy,
			resultType,
			criticality)

		local entity = Ext.Entity.Get(stealthActor)
		local stealth_tracker = entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker

		if not stealth_tracker then
			Logger:BasicWarning("%s rolled a stealth action check, but didn't have their tracker? This is a bug - skipping result functionality, please report on Nexus page with your MCM configs and your scenario - https://www.nexusmods.com/baldursgate3/mods/13114?tab=bugs", stealthActor)
			return
		end

		if resultType == 1 and entity.Stealth then
			local x, y, z = Osi.GetPosition(stealthActor)
			local newPosition = { Osi.FindValidPosition(
				CalculateGhostPosition(stealthActor, stealth_tracker.Counter) + x,
				-- don't wanna change the y axis, too many considerations and it doesn't make much sense anyway
				y,
				CalculateGhostPosition(stealthActor, stealth_tracker.Counter) + z,
				3,
				stealthActor,
				0
			) }

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

			entity.Vars.Sensible_Ambushing_Stealth_Action_Tracker.LastGhostPosition = newPosition

			entity.Stealth.Position = newPosition
			entity:Replicate("Stealth")
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
				end
			elseif MCM.Get("SA_enable_in_combat_behavior") then
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
		value = MCM.Get("SA_max_radius_for_ghost_on_action") / (2 / payload.value)
	end

	if value then
		Osi.CreateSurface(Osi.GetHostCharacter(), "SurfaceAsh", value, 1)
	end
end)

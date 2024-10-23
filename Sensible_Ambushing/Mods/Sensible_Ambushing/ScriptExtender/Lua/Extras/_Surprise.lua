-- Characters have a chance to resist surprise based on will save
-- "Ghost" of ambusher changes position depending on their obscuredState and stealth save?
-- If within range of minor illusion, crit threshold goes down?

local should_be_surprised = {}

-- Ext.Osiris.RegisterListener("StartAttack", 4, "before", function(defender, attackOwner, attacker, storyActionID)
-- 	if MCM.Get("SA_enabled")
-- 		and Osi.IsInCombat(defender) == 0
-- 		and Osi.IsInCombat(attacker) == 0
-- 	then
-- 		Logger:BasicTrace("Processing StartAttack event: \n\t|defender| = %s\n\t|attackerOwner| = %s\n\t|attacker| = %s\n\t|storyActionID| = %s",
-- 			defender,
-- 			attackOwner,
-- 			attacker,
-- 			storyActionID)

-- 		if Osi.IsPartyMember(defender, 1) == 0 or Osi.IsPartyMember(attacker, 1) == 0 then
-- 			if Osi.HasActiveStatus(attacker, "SNEAKING") == 1 then
-- 				Osi.ApplyStatus(defender, "SURPRISED", 1)
-- 			end
-- 		end
-- 	end
-- end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "before", function(attacker, defender, spell, spellType, _, storyActionID)
	if MCM.Get("SA_enabled")
		and attacker ~= defender
		and Osi.IsInCombat(defender) == 0
		and Osi.IsInCombat(attacker) == 0
	then
		Logger:BasicTrace("Processing UsingSpellOnTarget event: \n\t|defender| = %s\n\t|attacker| = %s\n\t|spell| = %s\n\t|spellType| = %s\n\t|storyActionID| = %s",
			defender,
			attacker,
			spell,
			spellType,
			storyActionID)

		if Osi.IsPartyMember(defender, 1) == 0 or Osi.IsPartyMember(attacker, 1) == 0 then
			if Osi.HasActiveStatus(attacker, "SNEAKING") == 1 then
				Osi.ApplyStatus(defender, "SURPRISED", 1)
			end
		end
	end
end)

EventCoordinator:RegisterEventProcessor("StatusApplied", function(surprisedCharacter, status, causee, storyActionID)
	if status == "SURPRISED" then
		-- https://bg3.norbyte.dev/search?q=type%3ADifficultyClass -- WTF Larian
		Osi.RequestPassiveRoll(surprisedCharacter,
			causee,
			"SavingThrowRoll",
			"Wisdom",
			"33cb7d74-7b51-4e5c-91ed-ff18cb8553bc", -- HiddenPerception_Hard
			0,
			"Sensible_Ambush_Resist_Surprise_Roll_" .. ModuleUUID
		)
	end
end)

EventCoordinator:RegisterEventProcessor("RollResult", function(eventName, roller, rollSubject, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Resist_Surprise_Roll_" .. ModuleUUID and Osi.HasActiveStatus(roller, "SURPRISED") == 1 then
		Logger:BasicTrace("Processing Ambush Resist Surprise check for %s against %s with result %s and criticality %s",
			roller,
			rollSubject,
			resultType,
			criticality)

		if resultType == 1 then
			Osi.RemoveStatus(roller, "SURPRISED")
		end
	end
end)

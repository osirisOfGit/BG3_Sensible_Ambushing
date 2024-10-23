-- Characters have a chance to resist surprise based on will save
-- "Ghost" of ambusher changes position depending on their obscuredState and stealth save?
-- If within range of minor illusion, crit threshold goes down?

-- Maps to Sensible_Ambushing\Public\Sensible_Ambushing\DifficultyClasses\DifficultyClasses.lsx
Extra_Surprise = {}
Extra_Surprise.difficultyClassUUIDs = {
	[1] = "7f084717-d919-4d2c-9947-d6b3925c7f92",
	[2] = "a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6",
	[3] = "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
	[4] = "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
	[5] = "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
	[6] = "e5f6a7b8-c9d0-1e2f-3a4b-5c6d7e8f9a0b",
	[7] = "f6a7b8c9-d0e1-2f3a-4b5c-6d7e8f9a0b1c",
	[8] = "a7b8c9d0-e1f2-3a4b-5c6d-7e8f9a0b1c2d",
	[9] = "b8c9d0e1-f2a3-4b5c-6d7e-8f9a0b1c2d3e",
	[10] = "c9d0e1f2-a3b4-5c6d-7e8f-9a0b1c2d3e4f",
	[11] = "d0e1f2a3-b4c5-6d7e-8f9a-0b1c2d3e4f5a",
	[12] = "e1f2a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b",
	[13] = "f2a3b4c5-d6e7-8f9a-0b1c-2d3e4f5a6b7c",
	[14] = "a3b4c5d6-e7f8-9a0b-1c2d-3e4f5a6b7c8d",
	[15] = "b4c5d6e7-f8a9-0b1c-2d3e-4f5a6b7c8d9e",
	[16] = "c5d6e7f8-a9b0-1c2d-3e4f-5a6b7c8d9e0f",
	[17] = "d6e7f8a9-b0c1-2d3e-4f5a-6b7c8d9e0f1a",
	[18] = "e7f8a9b0-c1d2-3e4f-5a6b-7c8d9e0f1a2b",
	[19] = "f8a9b0c1-d2e3-4f5a-6b7c-8d9e0f1a2b3c",
	[20] = "a9b0c1d2-e3f4-5a6b-7c8d-9e0f1a2b3c4d",
	[21] = "b0c1d2e3-f4a5-6b7c-8d9e-0f1a2b3c4d5e",
	[22] = "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
	[23] = "d2e3f4a5-b6c7-8d9e-0f1a-2b3c4d5e6f7g",
	[24] = "e3f4a5b6-c7d8-9e0f-1a2b-3c4d5e6f7g8h",
	[25] = "f4a5b6c7-d8e9-0f1a-2b3c-4d5e6f7g8h9i",
	[26] = "a5b6c7d8-e9f0-1a2b-3c4d-5e6f7g8h9i0j",
	[27] = "b6c7d8e9-f0a1-2b3c-4d5e-6f7g8h9i0j1k",
	[28] = "c7d8e9f0-a1b2-3c4d-5e6f-7g8h9i0j1k2l",
	[29] = "d8e9f0a1-b2c3-4d5e-6f7g-8h9i0j1k2l3m",
	[30] = "e9f0a1b2-c3d4-5e6f-7g8h-9i0j1k2l3m4n"
}

-- Weapon attacks are spells too - i.e. https://bg3.norbyte.dev/search?q=type%3Aspell+Ranged+%26+Attack#result-eda1854279be71702cf949e192e8b08a2839b809
-- AttackedBy event triggers after Sneaking is removed, so we can't use that
Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "before", function(attacker, defender, spell, spellType, _, storyActionID)
	if MCM.Get("SA_enabled")
		and MCM.Get("SA_surprise_enabled")
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

EventCoordinator:RegisterEventProcessor("StatusApplied", function(surprisedCharacter, status, causee, _)
	if status == "SURPRISED" then
		local applies_to = MCM.Get("SA_surprise_applies_to_condition")
		-- Nobody
		if applies_to == Ext.Loca.GetTranslatedString("h7eb270a054fe440080ce8a1f664135da3ade")
			-- Party Member
			or (applies_to == Ext.Loca.GetTranslatedString("h9cf4dd3bba8b4a17878c023942a3f34c3a6f") and Osi.IsPartyMember(surprisedCharacter, 1) == 0)
			-- Party Member and Allies
			or (applies_to == Ext.Loca.GetTranslatedString("hdfb30c4ea3a547c8a9061c82509dd836974f") and Osi.IsAlly(Osi.GetHostCharacter(), surprisedCharacter) == 0)
			-- Enemies
			or (applies_to == Ext.Loca.GetTranslatedString("hec43f582413d41388788d91c87f3aef57d1e") and Osi.IsEnemy(Osi.GetHostCharacter(), surprisedCharacter) == 0)
		then
			Logger:BasicDebug("Character %s did not meet selected MCM criteria %s, so removing the Surprise status", surprisedCharacter, applies_to)
			Osi.RemoveStatus(surprisedCharacter, "SURPRISED")
		elseif MCM.Get("SA_resist_surprise_ability_skill") ~= Ext.Loca.GetTranslatedString("h4a5bd083bf284046bbf40c1c0a4844878c79") -- None
		then
			local ability_skill = MCM.Get("SA_resist_surprise_ability_skill")
			local dc = MCM.Get("SA_resist_surprise_dc")

			Logger:BasicDebug("Character %s did meet selected MCM criteria %s, so rolling to resist surprise with Ability/Skill [%s] and DC [%d]",
				surprisedCharacter,
				applies_to,
				ability_skill,
				dc
			)

			Osi.RequestPassiveRoll(surprisedCharacter,
				causee,
				"SavingThrowRoll",
				ability_skill,
				Extra_Surprise.difficultyClassUUIDs[dc],
				0,
				"Sensible_Ambush_Resist_Surprise_Roll_" .. ModuleUUID
			)
		end
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

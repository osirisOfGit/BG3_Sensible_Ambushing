-- Maps to Sensible_Ambushing\Public\Sensible_Ambushing\DifficultyClasses\DifficultyClasses.lsx
Extra_Surprise = {}

Extra_Surprise.difficultyClassUUIDs = {
	[1] = "a1b2c3d4-e5f6-7a8b-9c0d-e1f2a3b4c5d6",
	[2] = "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
	[3] = "c3d4e5f6-a7b8-9c0d-1e2f-3a4b5c6d7e8f",
	[4] = "d4e5f6a7-b8c9-0d1e-2f3a-4b5c6d7e8f9a",
	[5] = "e5f6a7b8-c9d0-1e2f-3a4b-5c6d7e8f9a0b",
	[6] = "f6a7b8c9-d0e1-2f3a-4b5c-6d7e8f9a0b1c",
	[7] = "a7b8c9d0-e1f2-3a4b-5c6d-7e8f9a0b1c2d",
	[8] = "b8c9d0e1-f2a3-4b5c-6d7e-8f9a0b1c2d3e",
	[9] = "c9d0e1f2-a3b4-5c6d-7e8f-9a0b1c2d3e4f",
	[10] = "d0e1f2a3-b4c5-6d7e-8f9a-0b1c2d3e4f5a",
	[11] = "e1f2a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b",
	[12] = "f2a3b4c5-d6e7-8f9a-0b1c-2d3e4f5a6b7c",
	[13] = "a3b4c5d6-e7f8-9a0b-1c2d-3e4f5a6b7c8d",
	[14] = "b4c5d6e7-f8a9-0b1c-2d3e-4f5a6b7c8d9e",
	[15] = "c5d6e7f8-a9b0-1c2d-3e4f-5a6b7c8d9e0f",
	[16] = "d6e7f8a9-b0c1-2d3e-4f5a-6b7c8d9e0f1a",
	[17] = "e7f8a9b0-c1d2-3e4f-5a6b-7c8d9e0f1a2b",
	[18] = "f8a9b0c1-d2e3-4f5a-6b7c-8d9e0f1a2b3c",
	[19] = "a9b0c1d2-e3f4-5a6b-7c8d-9e0f1a2b3c4d",
	[20] = "b0c1d2e3-f4a5-6b7c-8d9e-0f1a2b3c4d5e",
	[21] = "c1d2e3f4-a5b6-7c8d-9e0f-1a2b3c4d5e6f",
	[22] = "00c337b5-b90e-44d4-aac6-1c0ea95e2b08",
	[23] = "b73d47fb-f929-403d-822c-d0329ef37153",
	[24] = "02f742de-b91b-431c-b77f-d1b6b0b07e20",
	[25] = "b620873e-d452-4104-8f44-f7f787f7d574",
	[26] = "e4bf19c6-6a5b-4c1f-a495-910d5cbf15df",
	[27] = "0533bdb9-5468-4ac7-8298-02cb74a8f3e5",
	[28] = "0d90c43a-e98c-4e29-9fad-53d1dd6609b8",
	[29] = "03eab834-e570-4b3f-ad70-00d055fb97dc",
	[30] = "32dfc49c-5331-48f3-ae05-f731b523b723"
}

--[[
So, Vanilla Surprise is janky and applies at the beginning of combat, before any of our listeners execute. There's no way to know
if the game has decided the group should be Surprised, so the theory behind this approach is:
1. Track whenever a character acts from stealth
2. If they enter combat within 3 seconds (due to differing spell animation lengths) then they acted against an enemy, and that enemy should be surprised
3. If the above is true, we set the enemy to surprised if they aren't already
4. If false, then we clear the tracker - we also clear it if they do any other action before the tracker expires
]]

Ext.Vars.RegisterUserVariable("Sensible_Ambushing_Acted_From_Stealth_Should_Surprise", {
	Server = true
})

-- Weapon attacks are spells too - i.e. https://bg3.norbyte.dev/search?q=type%3Aspell+Ranged+%26+Attack#result-eda1854279be71702cf949e192e8b08a2839b809
-- AttackedBy event triggers after Sneaking is removed, so we can't use that
EventCoordinator:RegisterEventProcessor("CastSpell", function(caster, _, _, _, _)
	if MCM.Get("SA_surprise_enabled") then
		local attacker_entity = Ext.Entity.Get(caster)
		-- Blanket reset in case they're somehow chaining actions
		attacker_entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise = nil

		if Osi.HasActiveStatus(caster, "SNEAKING") == 1 and Osi.IsInCombat(caster) == 0 then
			attacker_entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise = true

			Ext.Timer.WaitFor(3000, function()
				if attacker_entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise then
					Logger:BasicDebug("%s acted from stealth and was eligible to surprise their enemies, but the tracker wasn't processed, so removing tracker", caster)
					attacker_entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise = nil
				end
			end)
		end
	end
end)

EventCoordinator:RegisterEventProcessor("CombatStarted", function(combatGuid)
	if MCM.Get("SA_surprise_enabled") then
		for _, ambushingCombatMember in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
			ambushingCombatMember = ambushingCombatMember[1]
			local entity = Ext.Entity.Get(ambushingCombatMember)

			if entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise then
				entity.Vars.Sensible_Ambushing_Acted_From_Stealth_Should_Surprise = nil
				Logger:BasicDebug("%s acted from stealth and should surprise their enemies, so doing that", ambushingCombatMember)

				for _, potentialEnemy in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
					potentialEnemy = potentialEnemy[1]

					if Osi.IsEnemy(ambushingCombatMember, potentialEnemy) == 1
						and Osi.HasActiveStatus(potentialEnemy, "SURPRISED") == 0
					then
						Logger:BasicTrace("%s is an enemy of %s and isn't already surprised, so setting them as surprised",
							potentialEnemy,
							ambushingCombatMember)

						Osi.ApplyStatus(potentialEnemy, "SURPRISED", 1, 0)
					end
				end
				return
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

			-- None
		elseif MCM.Get("SA_resist_surprise_ability") ~= Ext.Loca.GetTranslatedString("h4a5bd083bf284046bbf40c1c0a4844878c79") then
			local ability_skill = MCM.Get("SA_resist_surprise_ability")
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
	if eventName == "Sensible_Ambush_Resist_Surprise_Roll_" .. ModuleUUID then
		Logger:BasicTrace("Processing Ambush Resist Surprise check for %s against %s with result %s and criticality %s",
			roller,
			rollSubject,
			resultType,
			criticality)

		if resultType == 1 and Osi.HasActiveStatus(roller, "SURPRISED") == 1 then
			Logger:BasicDebug("Character %s passed their resist roll and has SURPRISED - removing the status", roller)
			Osi.RemoveStatus(roller, "SURPRISED")
		end
	end
end)

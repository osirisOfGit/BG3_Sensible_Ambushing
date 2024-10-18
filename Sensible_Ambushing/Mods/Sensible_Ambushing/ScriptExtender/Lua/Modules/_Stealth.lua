local stealth_tracker = {}

AmbushDirector:RegisterModule(ModuleUUID, "Stealth", function(combatGuid, character)
	local pre_ambush_functions = {}
	local post_ambush_functions = {}

	if Osi.HasActiveStatus(character, "SNEAKING") == 1 and MCM.Get("SA_sneaking_chars_are_eligible") then
		table.insert(pre_ambush_functions, function(character_to_apply)
			-- Duplicating check to avoid any kind of weirdness with summons if they're copying their summoner
			if Osi.HasActiveStatus(character_to_apply, "SNEAKING") == 1 then
				Logger:BasicDebug("Character %s is currently sneaking - removing so they can join combat", character_to_apply)
				Osi.RemoveStatus(character_to_apply, "SNEAKING")
			end
		end)

		if MCM.Get("SA_sneaking_chars_get_stealth_back") then
			table.insert(post_ambush_functions, function(character_to_apply)
				Logger:BasicDebug("Having %s sneak per da rules", character_to_apply)

				Osi.ApplyStatus(character_to_apply, "SNEAKING", -1)

				--[[
                So, here's a fun thing - the Stealth component only gets created when a character sneaks/goes invis in a situation in which someone
                will want to look for them, like during combat or while committing a crime that was seen. This creates the "Ghost", which represents
                the position that character was at when they went stealth, which can't be removed since it's a component, but we can move that ghost
                to well outside the sight range of the enemy, so they won't bother looking for it.
                ]]
				-- OnCreateDeferredOnce so we only execute this once, for this ambush, and only once the Stealth component is actually created
				Ext.Entity.Get(character_to_apply):OnCreateDeferredOnce("Stealth", function(c)
					stealth_tracker[character_to_apply] = c.Stealth.Position

					-- Need to replace the whole table, not just one index because... memory shenanigans
					local pos = c.Stealth.Position
					
					-- y pos - Position has to be out of the sight cones of enemies, so placing it underground works without risking weird extreme math
					pos[2] = pos[2] * -1
					c.Stealth.Position = pos

					-- Syncs the server changes to the clients
					c:Replicate("Stealth")

					Logger:BasicDebug("Hid %s's ghost from the enemy", character_to_apply)
				end)

				for _, combatParticipant in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
					combatParticipant = combatParticipant[1]

					if Osi.IsEnemy(character_to_apply, combatParticipant) == 1 then
						Osi.RequestPassiveRollVersusSkill(character_to_apply, combatParticipant, "SkillCheckRoll", "Stealth", "Perception", 1, 0, "Sensible_Ambush_Stealth_Check")
					end
				end
			end)
		end
	end

	return pre_ambush_functions, post_ambush_functions
end)

Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
	if eventName == "Sensible_Ambush_Stealth_Check" then
		Logger:BasicTrace("Processing Ambush Stealth check for %s against %s with result %s",
			roller,
			rollSubject,
			resultType)

		for char, originalGhost in pairs(stealth_tracker) do
			if char == roller then
				if resultType == 0 then
					Logger:BasicDebug("%s failed their stealth check, so the enemy knows they're being ambushed", roller)
					local ent = Ext.Entity.Get(roller)
					ent.Stealth.Position = originalGhost
					ent:Replicate("Stealth")

					stealth_tracker[char] = nil
				end
				return
			end
		end
	end
end)

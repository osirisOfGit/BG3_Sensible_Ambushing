local stealth_tracker = {}
local status_tracker = {}

AmbushDirector:RegisterModule(ModuleUUID, "Stealth", function(combatGuid, character)
	local pre_ambush_functions = {}
	local post_ambush_functions = {}

	if (Osi.HasActiveStatus(character, "SNEAKING") == 1 and MCM.Get("SA_sneaking_chars_are_eligible"))
		or (Osi.HasActiveStatusWithGroup(character, "SG_Invisible") == 1 and MCM.Get("SA_invisible_chars_are_eligible"))
	then
		table.insert(pre_ambush_functions, function(character_to_apply)
			if Osi.HasActiveStatusWithGroup(character_to_apply, "SG_Invisible") == 1 then
				--- @type EntityHandle
				local charEntity = Ext.Entity.Get(character_to_apply) 
				for _, status in pairs(charEntity.StatusContainer.Statuses) do
					--- @type StatusData
					local statusData = Ext.Stats.Get(status)

					if statusData and statusData.StatusType == "INVISIBLE" then
						status_tracker[character_to_apply] = {
							statusName = status,
							roundsLeft = Osi.GetStatusCurrentLifetime(character_to_apply, status)
						}
						Logger:BasicDebug("%s has status %s left for %s rounds - removing so they can join combat", character_to_apply, status,
							status_tracker[character_to_apply].roundsLeft)
						Osi.RemoveStatusesWithType(character_to_apply, "INVISIBLE", character_to_apply)
						break
					end
				end
			end
			-- Duplicating check to avoid any kind of weirdness with summons if they're copying their summoner
			if Osi.HasActiveStatus(character_to_apply, "SNEAKING") == 1 then
				Logger:BasicDebug("%s is currently sneaking - removing so they can join combat", character_to_apply)
				Osi.RemoveStatus(character_to_apply, "SNEAKING")
			end
		end)

		if MCM.Get("SA_sneaking_chars_get_stealth_back") then
			table.insert(post_ambush_functions, function(character_to_apply)
				Logger:BasicDebug("Having %s sneak per da rules", character_to_apply)

				if status_tracker[character_to_apply] then
					Ext.Timer.WaitFor(500, function()
						local statusInfo = status_tracker[character_to_apply]
						Osi.ApplyStatus(character_to_apply, statusInfo.statusName, statusInfo.roundsLeft or -1, 1)
						Logger:BasicDebug("Reapplied %s on %s for %s rounds", statusInfo.statusName, character_to_apply, statusInfo.roundsLeft)
						status_tracker[character_to_apply] = nil
					end)
				else
					Osi.ApplyStatus(character_to_apply, "SNEAKING", -1)
				end

				if MCM.Get("SA_hide_sneaking_char_ghost") then
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

					if MCM.Get("SA_sneaking_char_roll_stealth") then
						for _, combatParticipant in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
							combatParticipant = combatParticipant[1]

							if Osi.IsEnemy(character_to_apply, combatParticipant) == 1
								and Osi.CanSpotSneakers(combatParticipant) == 1
								and Osi.HasLineOfSight(combatParticipant, character_to_apply) == 1
							then
								Osi.RequestPassiveRollVersusSkill(character_to_apply,
									combatParticipant,
									"SkillCheckRoll",
									"Stealth",
									"Perception",
									MCM.Get("SA_sneaking_char_roll_stealth_with_advantage") and 1 or 0,
									0,
									"Sensible_Ambush_Stealth_Check_" .. ModuleUUID)
							end
						end
					end
				end
			end)
		end
	end

	return pre_ambush_functions, post_ambush_functions
end)

EventCoordinator:RegisterEventProcessor("RollResult", function(eventName, sneakingChar, enemy, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Stealth_Check_" .. ModuleUUID then
		Logger:BasicTrace("Processing Ambush Stealth check for %s against %s with result %s and criticality %s",
			sneakingChar,
			enemy,
			resultType,
			criticality)

		if MCM.Get("SA_sneaking_chars_can_trip") and criticality == 2 then -- Critical Fail
			Logger:BasicInfo("%s critically failed their stealth check!", sneakingChar)

			Osi.ApplyStatus(sneakingChar, "PRONE", 1)

			stealth_tracker[sneakingChar] = nil
			return
		end

		for char, originalGhost in pairs(stealth_tracker) do
			if char == sneakingChar then
				if resultType == 0 then
					Logger:BasicInfo("%s failed their stealth check, so the enemy knows they're being ambushed", sneakingChar)

					local ent = Ext.Entity.Get(sneakingChar)
					ent.Stealth.Position = originalGhost
					ent:Replicate("Stealth")

					stealth_tracker[char] = nil

					Osi.SteerTo(enemy, sneakingChar, 0)
				end
				return
			end
		end
	end
end)

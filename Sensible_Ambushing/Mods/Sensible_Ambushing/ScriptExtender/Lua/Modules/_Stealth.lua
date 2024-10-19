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

							if Osi.IsEnemy(character_to_apply, combatParticipant) == 1 then
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

Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, _, criticality)
	if eventName == "Sensible_Ambush_Stealth_Check_" .. ModuleUUID then
		Logger:BasicTrace("Processing Ambush Stealth check for %s against %s with result %s and criticality %s",
			roller,
			rollSubject,
			resultType,
			criticality)

		--  and criticality == 2
		if MCM.Get("SA_sneaking_chars_can_trip") then -- Critical Fail
			Logger:BasicDebug("%s critically failed their stealth check!", roller)

			Osi.ApplyStatus(roller, "PRONE", 1)

			local metalEquipmentCount = 0
			for _, itemSlot in ipairs(Ext.Enums.ItemSlot) do
				itemSlot = tostring(itemSlot)
				-- Getting this aligned with Osi.EQUIPMENTSLOTNAME, because, what the heck Larian (╯°□°）╯︵ ┻━┻
				if itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.MeleeMainHand] then
					itemSlot = "Melee Main Weapon"
				elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.MeleeOffHand] then
					itemSlot = "Melee Offhand Weapon"
				elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.RangedMainHand] then
					itemSlot = "Ranged Main Weapon"
				elseif itemSlot == Ext.Enums.StatsItemSlot[Ext.Enums.StatsItemSlot.RangedOffHand] then
					itemSlot = "Ranged Offhand Weapon"
				end

				local equippedItem = Osi.GetEquippedItem(roller, itemSlot)
				-- https://bg3.norbyte.dev/search?q=METAL#result-8fad86503dd1ed79f5256d4c28cdc47fac697540
				if equippedItem and Osi.IsTagged(equippedItem, "abadcad5-9229-4999-8c7a-cd557ff2c95c") then
					metalEquipmentCount = metalEquipmentCount + 1
				end
			end

			Logger:BasicTrace("%s has %d metal items equipped", roller, metalEquipmentCount)
			if metalEquipmentCount > 1 then
				-- other candidates
				-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_TargetAoE_Impact_PostFX_Textkey_02_b52ab2d3-b887-459f-d375-6059b7fadbc0", "", 1)
				-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_TargetAoE_Impact_Textkey_02_8805c3ee-2b46-1450-d053-fb612089da7d", "", 15)
				-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_GlyphOfWarding_Detonation_Impact_01_1b766a1b-3fa3-7e19-8fbf-8f5d112f4df4", "", 1)
				-- Osi.PlaySound("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "Spell_Cast_Damage_Thunder_ChromaticOrbThunder_L1to3")

				-- https://bg3.norbyte.dev/search?q=VFX_Projectiles_SphereOfElementalBalance_Thunder_Impact_01#result-b5eb31dc214be0ee7b6c8f0d6612851bfafdf9b3
				Osi.PlayEffect(roller, "VFX_Projectiles_SphereOfElementalBalance_Thunder_Impact_01_c95979c7-551d-231b-c196-ed9c16f3121f", "", 1 * metalEquipmentCount)
				Osi.PlaySound(roller, "Items_Doors_Destroy_Metal_Big")
			end

			-- https://bg3.norbyte.dev/search?q=Surface#result-bbcd130617bfa4089f42431fb3373dca79334542
			Osi.CreateSurface(roller, "SurfaceAsh", 2 * metalEquipmentCount, 1)

			Osi.IterateCharactersAround(roller, 2 * metalEquipmentCount, "Sensible_Ambush_Fail_With_Metal_Armor_" .. roller, "Sensible_Ambush_Completed_Fail_With_Metal_Armor_" .. roller )

			stealth_tracker[roller] = nil
			return
		end

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

Ext.Osiris.RegisterListener("EntityEvent", 2, "before", function(char_in_radius_of_tripped_char, event)
	if string.find(event, "Sensible_Ambush_Fail_With_Metal_Armor_") then
		local char_that_tripped = string.sub(event, string.len("Sensible_Ambush_Fail_With_Metal_Armor_"))

		if Osi.IsInCombat(char_in_radius_of_tripped_char) == 0
			and Osi.CanMove(char_in_radius_of_tripped_char) == 1
			and Osi.IsMovementBlocked(char_in_radius_of_tripped_char) == 0
			and Osi.CanFight(char_in_radius_of_tripped_char) == 1
			and Osi.CanJoinCombat(char_in_radius_of_tripped_char) == 1
		then
			Osi.CharacterMoveTo(char_in_radius_of_tripped_char, char_that_tripped, "Sprint", "Sensible_Ambush")
		end
	end
end)

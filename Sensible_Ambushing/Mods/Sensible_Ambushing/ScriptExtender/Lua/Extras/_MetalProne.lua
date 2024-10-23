local function calculateNumberOfMetalEquipment(character)
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

		local equippedItem = Osi.GetEquippedItem(character, itemSlot)
		-- https://bg3.norbyte.dev/search?q=METAL#result-8fad86503dd1ed79f5256d4c28cdc47fac697540
		if equippedItem and Osi.IsTagged(equippedItem, "abadcad5-9229-4999-8c7a-cd557ff2c95c") == 1 then
			metalEquipmentCount = metalEquipmentCount + 1
		end
	end

	Logger:BasicTrace("%s has %d metal items equipped", character, metalEquipmentCount)

	return metalEquipmentCount
end

local function calculateRadius(metalEquipmentCount)
	return MCM.Get("SA_metal_equipment_base_radius") * (MCM.Get("SA_metal_equipment_count_weight") * metalEquipmentCount)
end

EventCoordinator:RegisterEventProcessor("StatusApplied", function(character, status, _, _)
	if status == "PRONE" and MCM.Get("SA_metal_chars_attract_enemies_when_knocked_prone") then
		if MCM.Get("SA_metal_chars_attract_context_condition") == Ext.Loca.GetTranslatedString("h54614a1bb4f84c79911793b6d0f6466254d8")
			or Osi.IsInCombat(character) == 1
		then
			local who_this_applies_to = MCM.Get("SA_metal_chars_applies_on_condition")
			if who_this_applies_to == Ext.Loca.GetTranslatedString("h979141588ed349f699ed3f234b2f4a8efef5")
				or (who_this_applies_to == Ext.Loca.GetTranslatedString("h9cf4dd3bba8b4a17878c023942a3f34c3a6f") and Osi.IsPartyMember(character, 1) == 1)
				or (who_this_applies_to == Ext.Loca.GetTranslatedString("hdfb30c4ea3a547c8a9061c82509dd836974f") and (Osi.IsPartyMember(character, 1) == 1 or Osi.IsAlly(Osi.GetHostCharacter(), character) == 1))
				or (who_this_applies_to == Ext.Loca.GetTranslatedString("hec43f582413d41388788d91c87f3aef57d1e") and Osi.IsEnemy(Osi.GetHostCharacter(), character) == 1)
			then
				local metalEquipmentCount = calculateNumberOfMetalEquipment(character)

				if metalEquipmentCount > 1 then
					Logger:BasicDebug("%s has %d metal pieces equipped and passes the MCM checks - attracting %s", character, metalEquipmentCount, who_this_applies_to)
					-- other candidates
					-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_TargetAoE_Impact_PostFX_Textkey_02_b52ab2d3-b887-459f-d375-6059b7fadbc0", "", 1)
					-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_TargetAoE_Impact_Textkey_02_8805c3ee-2b46-1450-d053-fb612089da7d", "", 15)
					-- Osi.PlayEffect("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "VFX_Spells_Cast_Damage_Thunder_GlyphOfWarding_Detonation_Impact_01_1b766a1b-3fa3-7e19-8fbf-8f5d112f4df4", "", 1)
					-- Osi.PlayEffect(roller, "VFX_Projectiles_SphereOfElementalBalance_Thunder_Impact_01_c95979c7-551d-231b-c196-ed9c16f3121f", "", 1 * metalEquipmentCount)
					-- Osi.PlaySound("S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604", "Spell_Cast_Damage_Thunder_ChromaticOrbThunder_L1to3")

					-- https://bg3.norbyte.dev/search?q=Items_Doors_Destroy_Metal_Big#result-c7ac24bfb8d4d97db68f80d564367ee7d5dff338
					Osi.PlaySound(character, "Items_Doors_Destroy_Metal_Big")

					Osi.IterateCharactersAround(character,
						calculateRadius(metalEquipmentCount),
						"Sensible_Ambush_Fail_With_Metal_Armor_" .. character,
						"Sensible_Ambush_Completed_Fail_With_Metal_Armor_" .. character)
				end
			end
		end
	end
end)

Ext.Osiris.RegisterListener("EntityEvent", 2, "before", function(char_in_radius_of_tripped_char, event)
	if string.find(event, "Sensible_Ambush_Fail_With_Metal_Armor_") then
		local char_that_tripped = string.sub(event, string.len("Sensible_Ambush_Fail_With_Metal_Armor_"))

		Logger:BasicTrace("Processing event %s against %s", event, char_in_radius_of_tripped_char)

		if Osi.IsInCombat(char_in_radius_of_tripped_char) == 0
			and Osi.CanMove(char_in_radius_of_tripped_char) == 1
			and Osi.IsMovementBlocked(char_in_radius_of_tripped_char) == 0
			and Osi.CanFight(char_in_radius_of_tripped_char) == 1
			and Osi.CanJoinCombat(char_in_radius_of_tripped_char) == 1
		then
			Logger:BasicTrace("%s is able to join the fight - they are:\n\t [Enemy] = %d\n\t[Ally] = %d", char_in_radius_of_tripped_char,
				Osi.IsEnemy(Osi.GetHostCharacter(), char_in_radius_of_tripped_char),
				Osi.IsAlly(Osi.GetHostCharacter(), char_in_radius_of_tripped_char))

			local who_can_be_attracted = MCM.Get("SA_metal_chars_attract_type_condition")

			if who_can_be_attracted == Ext.Loca.GetTranslatedString("h979141588ed349f699ed3f234b2f4a8efef5")
				or (who_can_be_attracted == Ext.Loca.GetTranslatedString("hec43f582413d41388788d91c87f3aef57d1e") and Osi.IsEnemy(Osi.GetHostCharacter(), char_in_radius_of_tripped_char) == 1)
				or (who_can_be_attracted == Ext.Loca.GetTranslatedString("h552a3874acdf4bdaa3f100134a032e996ea2") and Osi.IsAlly(Osi.GetHostCharacter(), char_in_radius_of_tripped_char) == 1)
			then
				local x, y, z = Osi.GetPosition(char_that_tripped)

				Logger:BasicTrace("%s passed the MCM checks and is going to sprint to %d/%d/%d", char_in_radius_of_tripped_char, x, y, z)

				Osi.CharacterMoveToPosition(char_in_radius_of_tripped_char, x, y, z, "Sprint", "Sensible_Ambush", 1)

				-- CharacterMoveToPosition persists through things like entering combat, so if we just let it be the enemy will move to be right on top of the tripped player
				-- I'd prefer to try to figure out how to trigger Osi.Event CharacterMoveToCancelled, but there doesn't seem to be an exposed mechanism for it
				-- Below works by purging the current command queue, which doesn't seem to affect their combat actions at all /shrug
				-- Should probably also figure out how to unsub from this, but /shrug. Wait for any bug reports i guess
				Ext.Entity.OnChange("CombatParticipant", function(c)
					if c.CombatParticipant.CombatHandle then
						Osi.PurgeOsirisQueue(c.Uuid.EntityUuid)
					end
				end, Ext.Entity.Get(char_in_radius_of_tripped_char))
			end
		end
	end
end)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
	if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId or not MCM.Get("SA_show_surface_for_radius_settings") then
		return
	end

	if payload.settingId == "SA_metal_equipment_base_radius" or payload.settingId == "SA_metal_equipment_count_weight" then
		-- https://bg3.norbyte.dev/search?q=Surface#result-bbcd130617bfa4089f42431fb3373dca79334542
		Osi.CreateSurface(Osi.GetHostCharacter(), "SurfaceAsh", calculateRadius(calculateNumberOfMetalEquipment(Osi.GetHostCharacter())), 1)
	end
end)

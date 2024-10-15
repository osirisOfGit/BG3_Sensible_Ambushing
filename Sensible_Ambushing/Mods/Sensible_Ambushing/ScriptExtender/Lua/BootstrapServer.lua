PersistentVars = {}

Ext.Require("Stuff/Utils/_FileUtils.lua")
Ext.Require("Stuff/Utils/_ModUtils.lua")
Ext.Require("Stuff/Utils/_Logger.lua")
-- https://github.com/FallenStar08/BG3-DUMP/tree/main
-- https://bg3.norbyte.dev/search?q=Surprised

-- Osi.ApplyStatus("S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679", "SNEAKING", -1)
Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function(combatGuid)
    for _, character in pairs(Osi.DB_Players:Get(nil)) do
        local character = character[1]
        if Osi.IsInCombat(character) ~= 1 then
            if Osi.CanJoinCombat(character) ~= 1 then
                Logger:BasicWarning("Player %s can't join combat?", character)
            else
                local restoreSneaking = false
                if Osi.HasActiveStatus(character, "SNEAKING") == 1 and MCM.Get("sneaking_chars_are_eligible") then
                    Logger:BasicDebug("Party member %s is currently sneaking - temporarily removing so they can join combat", character)
                    Osi.RemoveStatus(character, "SNEAKING")
                    restoreSneaking = true
                end
                for _, combatRow in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
                    local combatChar = combatRow[1]
                    if Osi.IsPlayer(combatChar) ~= 1 then
                        Osi.EnterCombat(character, combatChar)

                        if restoreSneaking then
                            Logger:BasicDebug("Restoring sneaking to %s", character)
                            Osi.ApplyStatus(character, "SNEAKING", -1)
                        end
                    end
                end
            end
        end
    end
end)

--[[
local function OnCombatStarted(combatGUID)
    local combatParticipants = Osi["DB_Is_InCombat"]:Get(nil, nil)

    for _, row in pairs(combatParticipants) do
        local initiativeOrder = math.random(1, 4)
        local participantTpl = row[1]
        local participantGUID = string.sub(participantTpl, -36)
        local participantEntity = Ext.Entity.Get(participantGUID)

        if (participantEntity) then
            participantEntity.CombatParticipant.InitiativeRoll = initiativeOrder

			-- CombatHandle is an entity and you cannot access its properties directly like this
            -- This part seems to work as is, but if you want to change this part too then you need
            -- to call Ext.Entity.Get on participantEntity.CombatParticipant.CombatHandle first, then
            -- adjust the properties on that.
            --participantEntity.CombatParticipant.CombatHandle.CombatState.Initiatives[participantTpl] = initiativeOrder
c
            _P("Character: " .. participantTpl)
            _P("Initiative: " .. initiativeOrder .. "\n")

            participantEntity:Replicate("CombatParticipant")

            _P('Updated initiative of ' .. participantTpl)
        else
            _P(participantTpl .. ' has no entity??')
        end
    end
end

]]

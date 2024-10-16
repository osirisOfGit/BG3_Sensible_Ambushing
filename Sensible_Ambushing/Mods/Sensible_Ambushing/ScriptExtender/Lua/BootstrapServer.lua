PersistentVars = {}

Ext.Require("Stuff/Utils/_FileUtils.lua")
Ext.Require("Stuff/Utils/_ModUtils.lua")
Ext.Require("Stuff/Utils/_Logger.lua")
-- https://github.com/FallenStar08/BG3-DUMP/tree/main
-- https://bg3.norbyte.dev/search?q=Surprised

local function IsCharacterEligibleToJoinAmbush(character)
    local post_ambush_functions = {}

    if Osi.IsInCombat(character) == 1 then
        Logger:BasicDebug("Character %s is already in combat", character)
        return
    elseif Osi.CanJoinCombat(character) ~= 1 then
        Logger:BasicWarning("Character %s can't join combat?", character)
        return
    end

    if Osi.HasActiveStatus(character, "SNEAKING") == 1 and MCM.Get("SA_sneaking_chars_are_eligible") then
        Logger:BasicDebug("Character %s is currently sneaking - removing so they can join combat", character)
        Osi.RemoveStatus(character, "SNEAKING")
        if MCM.Get("SA_sneaking_chars_get_stealth_back") then
            table.insert(post_ambush_functions, function(character_to_apply)
                Logger:BasicDebug("Restoring sneaking to %s", character_to_apply)
                Osi.ApplyStatus(character_to_apply, "SNEAKING", -1)
            end)
        end
    end

    return post_ambush_functions
end

local function AreSummonsEligibleToJoinAmbush(character, character_post_ambush_functions)
    local summon_post_ambush_functions = {}

    local summons = Osi.DB_PlayerSummons:Get(nil)
    if #summons > 0 then
        for _, summon in pairs(summons) do
            summon = summon[1]

            if (Ext.Entity.Get(summon).IsSummon.Summoner.Uuid.EntityUuid == Osi.GetUUID(character)) then
                summon_post_ambush_functions[summon] = {}

                if MCM.Get("SA_summons_copy_summoner") then
                    for _, post_ambush_func in pairs(character_post_ambush_functions) do
                        table.insert(summon_post_ambush_functions[summon], post_ambush_func)
                    end
                else
                    summon_post_ambush_functions[summon] = IsCharacterEligibleToJoinAmbush(summon)
                end
            end
        end
    end

    return summon_post_ambush_functions
end

-- Osi.ApplyStatus("S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679", "SNEAKING", -1)
Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function(combatGuid)
    local targetEnemy = nil
    for _, character in pairs(Osi.DB_Players:Get(nil)) do
        local character = character[1]
        local character_post_ambush_functions = IsCharacterEligibleToJoinAmbush(character)

        if character_post_ambush_functions then
            local summons_and_post_ambush_functions = AreSummonsEligibleToJoinAmbush(character, character_post_ambush_functions)

            if not targetEnemy then
                for _, combatRow in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
                    local combatChar = combatRow[1]
                    if Osi.IsPlayer(combatChar) ~= 1 then
                        targetEnemy = combatChar
                    end
                end
            end

            Osi.EnterCombat(character, targetEnemy)

            for _, post_ambush_func in pairs(character_post_ambush_functions) do
                post_ambush_func(character)
            end

            for summon, post_ambush_functions in pairs(summons_and_post_ambush_functions) do
                for _, post_ambush_func in pairs(post_ambush_functions) do
                    post_ambush_func(summon)
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

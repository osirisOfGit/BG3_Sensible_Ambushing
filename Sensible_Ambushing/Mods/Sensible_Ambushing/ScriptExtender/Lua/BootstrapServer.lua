PersistentVars = {}

Ext.Require("Stuff/Utils/_FileUtils.lua")
Ext.Require("Stuff/Utils/_ModUtils.lua")
Ext.Require("Stuff/Utils/_Logger.lua")
-- https://github.com/FallenStar08/BG3-DUMP/tree/main
-- https://bg3.norbyte.dev/search?q=Surprised

local stealth_tracker = {}


local function IsCharacterEligibleToJoinAmbush(character)
    local pre_ambush_functions = {}
    local post_ambush_functions = {}

    if Osi.IsInCombat(character) == 1 then
        Logger:BasicTrace("Character %s is already in combat", character)
        return
    elseif Osi.CanJoinCombat(character) ~= 1 then
        Logger:BasicWarning("Character %s can't join combat?", character)
        return
    end

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
                Ext.Entity.Get(character_to_apply):OnCreateDeferredOnce("Stealth", function(c)
                    stealth_tracker[character_to_apply] = c.Stealth.Position

                    -- Need to replace the whole table, not just one index because... memory shenanigans
                    local pos = c.Stealth.Position
                    pos[2] = pos[2] * -10
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

    -- Returning nil if we're empty makes later checks simpler and more consistent, as long as we know about it, since we're returning nils above (don't do this if you're building an API)
    return #pre_ambush_functions > 0 and pre_ambush_functions or nil, #post_ambush_functions > 0 and post_ambush_functions or nil
end

Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
    if eventName == "Sensible_Ambush_Stealth_Check" then
        Logger:BasicDebug("Processing Ambush Stealth check for %s against %s with result %s",
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

local function AreSummonsEligibleToJoinAmbush(character, char_pre_ambush_funcs, char_post_ambush_funcs)
    local summon_pre_ambush_functions = {}
    local summon_post_ambush_functions = {}

    local summons = Osi.DB_PlayerSummons:Get(nil)
    if #summons > 0 then
        for _, summon in pairs(summons) do
            summon = summon[1]

            if (Ext.Entity.Get(summon).IsSummon.Summoner.Uuid.EntityUuid == Osi.GetUUID(character)) then
                summon_pre_ambush_functions[summon] = {}
                summon_post_ambush_functions[summon] = {}

                if MCM.Get("SA_summons_copy_summoner") then
                    if char_pre_ambush_funcs then
                        for _, pre_ambush_func in pairs(char_pre_ambush_funcs) do
                            table.insert(summon_pre_ambush_functions[summon], pre_ambush_func)
                        end
                    else
                        summon_pre_ambush_functions[summon] = nil
                    end

                    if char_post_ambush_funcs then
                        for _, post_ambush_func in pairs(char_post_ambush_funcs) do
                            table.insert(summon_post_ambush_functions[summon], post_ambush_func)
                        end
                    else
                        summon_post_ambush_functions[summon] = nil
                    end
                else
                    summon_pre_ambush_functions[summon], summon_post_ambush_functions[summon] = IsCharacterEligibleToJoinAmbush(summon)
                end
            end
        end
    end

    -- Returning nil if we're empty makes later checks simpler and more consistent, as long as we know about it (don't do this if you're building an API)
    -- Since we're using the summon as the index for the table, we can't check the size since lua just iterates the numeric index to get the count
    return next(summon_pre_ambush_functions) and summon_pre_ambush_functions or nil, next(summon_post_ambush_functions) and summon_post_ambush_functions or nil
end

local function executeCharacterAndSummonFuncs(player_char, char_funcs, summon_funcs)
    if char_funcs then
        Logger:BasicTrace("Executing functions for %s", player_char)
        for _, char_func in pairs(char_funcs) do
            local success, errorResponse = pcall(function()
                char_func(player_char)
            end)

            if not success then
                Logger:BasicError("Exception was thrown while processing Character functions for %s: \n%s", player_char, errorResponse)
            end
        end
    end

    if summon_funcs then
        for summon, funcs in pairs(summon_funcs) do
            Logger:BasicTrace("Executing functions for %s", summon)
            for _, func in pairs(funcs) do
                local success, errorResponse = pcall(function()
                    func(summon)
                end)

                if not success then
                    Logger:BasicError("Exception was thrown while processing Summon functions for %s: \n%s", summon, errorResponse)
                end
            end
        end
    end
end

Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function(combatGuid)
    local startTime = Ext.Utils.MonotonicTime()
    local targetEnemy = nil
    for _, player_char in pairs(Osi.DB_Players:Get(nil)) do
        player_char = player_char[1]

        local char_pre_ambush_functions, char_post_ambush_functions = IsCharacterEligibleToJoinAmbush(player_char)
        local summons_and_pre_ambush_functions, summons_and_post_ambush_functions = AreSummonsEligibleToJoinAmbush(player_char, char_pre_ambush_functions, char_post_ambush_functions)

        if (char_pre_ambush_functions or char_post_ambush_functions) or (summons_and_pre_ambush_functions or summons_and_post_ambush_functions) then
            -- Need to find an enemy character to use in Osi.EnterCombat
            if not targetEnemy then
                for _, combatParticipant in pairs(Osi.DB_Is_InCombat:Get(nil, combatGuid)) do
                    combatParticipant = combatParticipant[1]

                    if Osi.IsEnemy(player_char, combatParticipant) == 1 then
                        targetEnemy = combatParticipant
                        break
                    end
                end
            end

            executeCharacterAndSummonFuncs(player_char, char_pre_ambush_functions, summons_and_pre_ambush_functions)

            Osi.EnterCombat(player_char, targetEnemy)

            executeCharacterAndSummonFuncs(player_char, char_post_ambush_functions, summons_and_post_ambush_functions)
        end
    end

    Logger:BasicTrace("Finished processing in %dms", Ext.Utils.MonotonicTime() - startTime)
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


-- https://discord.com/channels/98922182746329088/771869529528991744/1269036327165231134
Ext.RegisterConsoleCommand("ROL", function(_, osiFunction)
    if Osi[osiFunction] then
        Ext.Osiris.RegisterListener(osiFunction, Osi[osiFunction].Arities[1], "before", function(...)
            FCDebug(osiFunction..": %s", Ext.DumpExport({...}))
        end)
    end
end)

Ext.RegisterConsoleCommand("REL", function(_, extenderEvent)
    Ext.Events[extenderEvent]:Subscribe(function(e)
        FCDump({extenderEvent, {e}})
    end)
end)


-- https://discord.com/channels/98922182746329088/771869529528991744/1260072668070412430
local function OnLevelGameplayStarted(levelName, isEditorMode)
    _P('Level gameplay started')

    local hostEntity = Ext.Entity.Get(Osi.GetHostCharacter())
    Ext.Entity.Subscribe("Health", function(c)
        _P("HP changed!")
        _D(c.Health)
    end, hostEntity)
end
Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", OnLevelGameplayStarted)

]]

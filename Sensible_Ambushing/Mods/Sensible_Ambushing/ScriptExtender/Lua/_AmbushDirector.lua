-- https://github.com/FallenStar08/BG3-DUMP/tree/main
-- https://bg3.norbyte.dev/search?q=Surprised

AmbushDirector = {}

local modules = {}

--- API method to register modules that should be executed during an ambush
---@param modUUID string that ScriptExtender has registered for your mod, for tracking purposes - <a href="https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#ismodloadedmodguid">https://github.com/Norbyte/bg3se/blob/main/Docs/API.md#ismodloadedmodguid</a>
--- will throw an error if the mod identified by that UUID is not loaded
---@param moduleName string the name of the module - must be unique
---@param moduleFunc function that accepts the combatUUID and the GUIDSTRING of the party member/summon and returns a tuple of lists containing pre- and post- EnterCombat functions to execute, which take in the same GUIDSTRING (to allow summons to copy their summoners if enabled)
function AmbushDirector:RegisterModule(modUUID, moduleName, moduleFunc)
	local modName = ModUtils:GetModInfoFromUUID(modUUID).Name

	modules[moduleName] = moduleFunc
	Logger:BasicInfo("Mod %s successfully added ambush module %s", modName, moduleName)
end

Ext.Require("Modules/_Stealth.lua")


local function IsCharacterEligibleToJoinAmbush(combatGuid, character)
	local pre_ambush_functions = {}
	local post_ambush_functions = {}

	if Osi.IsInCombat(character) == 1 then
		Logger:BasicTrace("Character %s is already in combat", character)
		return
	elseif Osi.CanJoinCombat(character) ~= 1 then
		Logger:BasicWarning("Character %s can't join combat?", character)
		return
	end

	for module, moduleFunc in pairs(modules) do
		Logger:BasicDebug("Executing Ambush Module %s for %s", module, character)

		local mod_pre, mod_post = moduleFunc(combatGuid, character)

		if mod_pre then
			pre_ambush_functions = table.move(mod_pre, 1, #mod_pre, #pre_ambush_functions, pre_ambush_functions)

			Logger:BasicTrace("New pre-ambush function count is %d", #pre_ambush_functions)
		end

		if mod_post then
			post_ambush_functions =table.move(mod_post, 1, #mod_post, #post_ambush_functions, post_ambush_functions)

			Logger:BasicTrace("New post-ambush function count is %d", #post_ambush_functions)
		end
	end

	-- Returning nil if we're empty makes later checks simpler and more consistent, as long as we know about it, since we're returning nils above (don't do this if you're building an API)
	return #pre_ambush_functions > 0 and pre_ambush_functions or nil, #post_ambush_functions > 0 and post_ambush_functions or nil
end

local function AreSummonsEligibleToJoinAmbush(combatGuid, character, char_pre_ambush_funcs, char_post_ambush_funcs)
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
					summon_pre_ambush_functions[summon], summon_post_ambush_functions[summon] = IsCharacterEligibleToJoinAmbush(combatGuid, summon)
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

		local char_pre_ambush_functions, char_post_ambush_functions = IsCharacterEligibleToJoinAmbush(combatGuid, player_char)
		local summons_and_pre_ambush_functions, summons_and_post_ambush_functions = AreSummonsEligibleToJoinAmbush(combatGuid, player_char, char_pre_ambush_functions, char_post_ambush_functions)

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

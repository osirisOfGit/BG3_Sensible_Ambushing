EventCoordinator = {}

local events = {
	["RollResult"] = {},
	["StatusApplied"] = {},
	["CombatStarted"] = {},
	["CastSpell"] = {},
}

--- API method to register functions that operate under the same event, for performance reasons
---@param moduleName string the name of the module - must be unique
---@param moduleFunc function that accepts the combatUUID and the GUIDSTRING of the party member/summon and returns a tuple of lists containing pre- and post- EnterCombat functions to execute, which take in the same GUIDSTRING (to allow summons to copy their summoners if enabled)
function EventCoordinator:RegisterEventProcessor(eventName, eventFunc)
	table.insert(events[eventName], eventFunc)
end

Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
	if MCM.Get("SA_enabled") then
		for _, func in pairs(events["RollResult"]) do
			func(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
		end
	end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(object, status, causee, storyActionID)
	if MCM.Get("SA_enabled") then
		for _, func in pairs(events["StatusApplied"]) do
			func(object, status, causee, storyActionID)
		end
	end
end)

Ext.Osiris.RegisterListener("CombatStarted", 1, "before", function(combatGuid)
	if MCM.Get("SA_enabled") then
		for _, func in pairs(events["CombatStarted"]) do
			func(combatGuid)
		end
	end
end)

Ext.Osiris.RegisterListener("CastSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionID)
	if MCM.Get("SA_enabled") then
		Logger:BasicTrace("Processing CastSpell event: \n\t|caster| = %s\n\t|spell| = %s\n\t|spellType| = %s\n\t|storyActionID| = %s",
			caster,
			spell,
			spellType,
			storyActionID)

		for _, func in pairs(events["CastSpell"]) do
			func(caster, spell, spellType, spellElement, storyActionID)
		end
	end
end)

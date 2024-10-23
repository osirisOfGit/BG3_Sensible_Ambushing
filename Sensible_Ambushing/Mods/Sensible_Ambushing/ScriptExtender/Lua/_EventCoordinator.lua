EventCoordinator = {}

local events = {
	["RollResult"] = {},
	["StatusApplied"] = {}
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

Ext.Osiris.RegisterListener("StatusApplied", 4, "before", function(object, status, causee, storyActionID)
	if MCM.Get("SA_enabled") then
		for _, func in pairs(events["StatusApplied"]) do
			func(object, status, causee, storyActionID)
		end
	end
end)

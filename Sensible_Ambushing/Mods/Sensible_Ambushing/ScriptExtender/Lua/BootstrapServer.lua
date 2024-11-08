Ext.Require("Stuff/Utils/_FileUtils.lua")
Ext.Require("Stuff/Utils/_ModUtils.lua")
Ext.Require("Stuff/Utils/_Logger.lua")

Logger:ClearLogFile()

Ext.Require("_EventCoordinator.lua")

Ext.Require("Extras/_MetalProne.lua")
Ext.Require("Extras/_Surprise.lua")
Ext.Require("Extras/_StealthAttacks.lua")

Ext.Require("_AmbushDirector.lua")

Ext.Events.SessionLoaded:Subscribe(function()
	local stealth = Ext.Stats.Get("SNEAKING")

	local flags = stealth.StatusPropertyFlags
	for _, flag in pairs(flags) do
		if flag == "DisableCombatlog" then
			return
		end
	end
	table.insert(flags, "DisableCombatlog")
	stealth.StatusPropertyFlags = flags
	stealth:Sync()
end)

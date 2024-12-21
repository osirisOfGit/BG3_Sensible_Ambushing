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

Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level, _)
	if level == "SYS_CC_I" then return end

	for _, player_char in pairs(Osi.DB_Players:Get(nil)) do
		player_char = player_char[1]
		if Osi.HasPassive(player_char, "Sensible_Ambushing_Eligible_Passive") == 0 then
			Osi.AddPassive(player_char, "Sensible_Ambushing_Eligible_Passive")
		end
	end
end)

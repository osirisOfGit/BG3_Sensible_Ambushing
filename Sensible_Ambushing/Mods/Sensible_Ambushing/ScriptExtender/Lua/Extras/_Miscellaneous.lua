local function disableSneakCombatLog(shouldDisable)
	local stealth = Ext.Stats.Get("SNEAKING")

	local flagCopy = {}
	local flags = stealth.StatusPropertyFlags
	for _, flag in pairs(flags) do
		if flag == "DisableCombatlog" then
			if shouldDisable then
				return
			end
		else
			table.insert(flagCopy, flag)
		end
	end

	if shouldDisable then
		table.insert(flagCopy, "DisableCombatlog")
	end

	stealth.StatusPropertyFlags = flagCopy
	stealth:Sync()
end

local function enableObscurityOverhead(shouldEnable)
	for _, obscurity_status in pairs({ "SNEAKING_LIGHTLY_OBSCURED", "SNEAKING_HEAVILY_OBSCURED", "SNEAKING_CLEAR" }) do
		local stat = Ext.Stats.Get(obscurity_status)

		local statFlags = stat.StatusPropertyFlags
		local copyFlags = {}
		for _, flag in pairs(statFlags) do
			if flag == "DisableOverhead" then
				if not shouldEnable then
					goto continue
				end
			else
				table.insert(copyFlags, flag)
			end
		end
		
		if not shouldEnable then
			table.insert(copyFlags, "DisableOverhead")
		end

		stat.StatusPropertyFlags = copyFlags
		stat:Sync()
		::continue::
	end
end

Ext.Events.SessionLoaded:Subscribe(function()
	disableSneakCombatLog(MCM.Get("SA_disable_sneak_combat_log"))
	enableObscurityOverhead(MCM.Get("SA_obscurity_icons"))
end)


Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
	if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
		return
	end

	if payload.settingId == "SA_disable_sneak_combat_log" then
		disableSneakCombatLog(payload.value)
	elseif payload.settingId == "SA_obscurity_icons" then
		enableObscurityOverhead(payload.value)
	end
end)

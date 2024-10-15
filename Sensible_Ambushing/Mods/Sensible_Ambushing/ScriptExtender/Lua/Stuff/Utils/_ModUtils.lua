ModUtils = {}

function ModUtils:GetAIMModInfo()
	return Ext.Mod.GetMod(ModuleUUID).Info
end

function ModUtils:GetModInfoFromUUID(modUUID)
	if not Ext.Mod.IsModLoaded(modUUID) then
		local errorMessage = string.format(
			"Provided modUUID %s is not loaded - make sure you're passing in the right key!"
			.. " The attempted function will not be completed.",
			modUUID)

		Logger:BasicError(errorMessage)
		error(errorMessage)
	end
	return Ext.Mod.GetMod(modUUID).Info
end

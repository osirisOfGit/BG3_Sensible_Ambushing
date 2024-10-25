-- Save to table when UsingSpell
-- Timer for 1 second, if they're not in combat then remove
-- listen to EnteredCombat, if character enters then run logic

Ext.Osiris.RegisterListener("StatusRemoved", 4, "before", function(object, status, causee, applyStoryActionID)
	Logger:BasicError("Processing StatusRemoved event: \n\t|character| = %s\n\t|status| = %s\n\t|causee| = %s",
		object,
		status,
		causee)
end)

Ext.Osiris.RegisterListener("StartedPreviewingSpell", 4, "before", function(caster, spell, isMostPowerful, hasMultipleLevels)
	Logger:BasicError("Processing StartedPreviewingSpell event: \n\t|caster| = %s\n\t|spell| = %s",
		caster,
		spell)
end)

Ext.Osiris.RegisterListener("UsingSpellOnTarget", 6, "before", function(attacker, defender, spell, spellType, _, storyActionID)
	Logger:BasicError("Processing UsingSpellOnTarget event: \n\t|defender| = %s\n\t|attacker| = %s\n\t|spell| = %s\n\t|spellType| = %s\n\t|storyActionID| = %s",
		defender,
		attacker,
		spell,
		spellType,
		storyActionID)
end)

Ext.Osiris.RegisterListener("AttackedBy", 7, "before", function(defender, attackerOwner, attacker2, damageType, damageAmount, damageCause, storyActionID)
	Logger:BasicError("Processing AttackedBy event: \n\t|defender| = %s\n\t|attackerOwner| = %s\n\t|attacker2| = %s",
		defender,
		attackerOwner,
		attacker2)
end)

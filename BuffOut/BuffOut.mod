return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`BuffOut` encountered an error loading the Darktide Mod Framework.")

		new_mod("BuffOut", {
			mod_script       = "BuffOut/scripts/mods/BuffOut/BuffOut",
			mod_data         = "BuffOut/scripts/mods/BuffOut/BuffOut_data",
			mod_localization = "BuffOut/scripts/mods/BuffOut/BuffOut_localization",
		})
	end,
	packages = {},
}

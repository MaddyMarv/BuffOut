local mod = get_mod("BuffOut")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "general_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "out_of_combat_timeout",
                        type = "numeric",
                        default_value = 5.0,
                        range = { 1, 30 },
                        decimals_number = 1,
                        step_size_value = 0.5,
                    },
                },
            },
            {
                setting_id = "fade_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "fade_in_duration",
                        type = "numeric",
                        default_value = 0.25,
                        range = { 0.0, 3.0 },
                        decimals_number = 2,
                        step_size_value = 0.05,
                    },
                    {
                        setting_id = "fade_out_duration",
                        type = "numeric",
                        default_value = 1.0,
                        range = { 0.1, 5.0 },
                        decimals_number = 2,
                        step_size_value = 0.1,
                    },
                    {
                        setting_id = "out_of_combat_alpha",
                        type = "numeric",
                        default_value = 0.0,
                        range = { 0.0, 1.0 },
                        decimals_number = 2,
                        step_size_value = 0.05,
                    },
                },
            },
        },
    },
}

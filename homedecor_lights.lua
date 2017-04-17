
wcons.register_light_device("homedecor:ground_lantern", { "homedecor:ground_lantern" })
wcons.register_light_device("homedecor:ceiling_lantern", { "homedecor:ceiling_lantern" })
wcons.register_light_device("homedecor:hanging_lantern", { "homedecor:hanging_lantern" })
wcons.register_light_device("homedecor:wall_lamp", { "homedecor:wall_lamp" })
wcons.register_light_device("homedecor:lattice_lantern_large", { "homedecor:lattice_lantern_large" })
wcons.register_light_device("homedecor:lattice_lantern_small", { "homedecor:lattice_lantern_small" })
wcons.register_light_device("homedecor:ceiling_lamp", { "homedecor:ceiling_lamp_off", "homedecor:ceiling_lamp" })
wcons.register_light_device("homedecor:plasma_lamp", { "homedecor:plasma_lamp" })
wcons.register_light_device("homedecor:plasma_ball", { "homedecor:plasma_ball" })

wcons.register_light_device("homedecor:glowlight_half", { "homedecor:glowlight_half" })
wcons.register_light_device("homedecor:glowlight_quarter", { "homedecor:glowlight_quarter" })
wcons.register_light_device("homedecor:glowlight_small_cube", { "homedecor:glowlight_small_cube" })

wcons.register_light_device("lavalamp:lavalamp", { "lavalamp:lavalamp_off", "lavalamp:lavalamp" })

wcons.register_light_device("homedecor:standing_lamp_off", {
    "homedecor:standing_lamp_off",
    "homedecor:standing_lamp_low",
    "homedecor:standing_lamp_med",
    "homedecor:standing_lamp_hi",
    "homedecor:standing_lamp_max",
})

wcons.register_light_device("homedecor:table_lamp_off", {
    "homedecor:table_lamp_off",
    "homedecor:table_lamp_low",
    "homedecor:table_lamp_med",
    "homedecor:table_lamp_hi",
    "homedecor:table_lamp_max",
})

wcons.register_light_device("homedecor:ceiling_fan", { "homedecor:ceiling_fan" })
minetest.override_item("wcons:ceiling_fan_0", {
    tiles = {
        "[combine:64x64:0,0=homedecor_ceiling_fan_top.png",
        "[combine:64x64:0,0=homedecor_ceiling_fan_bottom.png",
		"homedecor_ceiling_fan_sides.png",
    },
})
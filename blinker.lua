
local MODE_AUTO = 0
local MODE_ON   = 1
local MODE_OFF  = 2
local MODE_COUNT = 3

local MODE_NAMES = {
    [MODE_AUTO] = "auto",
    [MODE_ON]   = "on",
    [MODE_OFF]  = "off",
}

local MODE_ITEMS = {}

local CON_MODE         = "wcons:blinker_controller:mode"
local CON_SPEC         = "wcons:blinker_controller:spec"


----------------------------------------------------------------------
--                             LOGGING                              --
----------------------------------------------------------------------

local LOG_DOMAIN = minetest.get_current_modname()
local DEBUG, INFO, ACTION, WARNING, ERROR
if minetest.get_modpath("logging") then
    DEBUG = function (...)   logging.emit(LOG_DOMAIN, logging.LEVEL_DEBUG,   string.format(...), 1) end
    INFO = function (...)    logging.emit(LOG_DOMAIN, logging.LEVEL_INFO,    string.format(...), 1) end
    ACTION = function (...)  logging.emit(LOG_DOMAIN, logging.LEVEL_ACTION,  string.format(...), 1) end
    WARNING = function (...) logging.emit(LOG_DOMAIN, logging.LEVEL_WARNING, string.format(...), 1) end
    ERROR = function (...)   logging.emit(LOG_DOMAIN, logging.LEVEL_ERROR,   string.format(...), 1) end
else
    DEBUG = function (...)   minetest.log("verbose", "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    INFO = function (...)    minetest.log("info",    "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    ACTION = function (...)  minetest.log("action",  "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    WARNING = function (...) minetest.log("warning", "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    ERROR = function (...)   minetest.log("error",   "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
end


----------------------------------------------------------------------


local function _update_spec ( pos )
    local meta = minetest.get_meta(pos)
    local spec = meta:get_string(CON_SPEC)
    local steps = string.split(spec, ",")
    local n_steps = #steps
    DEBUG("blinker spec: %s", spec)
    DEBUG("%d steps", n_steps)
    meta:set_int("n_steps", n_steps)
    for i = 1, n_steps do
        local s = string.split(steps[i], "=")
        local time = tonumber(s[1] or 1)
        local voltage = tonumber(s[2] or 100)
        DEBUG("step %d: time=%.2f, voltage=%d", i, time, voltage)
        meta:set_float("time_" .. i, time)
        meta:set_int("voltage_" .. i, voltage)
    end
end


local function on_timer ( pos, elapsed )
    local timer = minetest.get_node_timer(pos)
    local meta = minetest.get_meta(pos)
    local mode = meta:get_int(CON_MODE)
    local n_steps = meta:get_int("n_steps")
    local step = meta:get_int("step") + 1
    if step < 1 or step > n_steps then
        step = 1
    end
    local voltage = meta:get_int("voltage_" .. step)
    local time = meta:get_float("time_" .. step )
    DEBUG("blinker %s step %d: %d (time=%.2f)", minetest.pos_to_string(pos), step, voltage, time)
    -- DEBUG("meta: %s", dump(meta:to_table()))
    wcons.emit_signal(pos, { type="wcons:voltage", value=voltage })
    meta:set_int("step", step)
    timer:start(time, elapsed)
    return false
end


local function on_emit_signal ( dev, node, signal )
    if signal.type == "wcons:blinker" then
        local mode = signal[CON_MODE]
        DEBUG("mode type: %s", type(mode))
        local new_node = MODE_ITEMS[mode]
        if new_node then
            -- DEBUG("new_node: %s", tostring(new_node))
            minetest.swap_node(dev.pos, { name=new_node })
        else
            ERROR("invalid mode: %s", tostring(mode))
            DEBUG("modes: %s", dump(MODE_ITEMS))
        end
        local timer = minetest.get_node_timer(dev.pos)
        if mode == MODE_AUTO then
            _update_spec(dev.pos)
            timer:start(0)
        elseif mode == MODE_ON then
            wcons.emit_signal(dev.pos, { type="wcons:voltage", value=100 })
            timer:stop()
        elseif mode == MODE_OFF then
            wcons.emit_signal(dev.pos, { type="wcons:voltage", value=0 })
            timer:stop()
        end
    end
end


local function on_receive_signal ( dev, node, emitter_dev, emitter_node, signal )
    on_emit_signal(dev, node, signal)
end


-- local function timer ( pos )
--     DEBUG("TIMER: %s", minetest.pos_to_string(pos))
--     local meta = minetest:get_meta(pos)
--     local n_steps = meta:get_int(CON_N_STEPS)
--     local step = meta:get_int(CON_STEP) + 1
--     if step > n_steps then
--         step = 1
--     end
--     local voltage = meta:get_int(CON_STEP_VOLTAGE .. step)
--     local time = meta:get_float(CON_STEP_TIME .. step )
--     wcons.emit_signal(pos, { type="wcons:voltage", value=voltage })
--     meta:set_int(CON_STEP, step)
--     return time
-- end


local function after_place_node ( pos, placer, stack, pointed )
    wcons.set_device_controller(pos, "wcons:blinker_controller", placer, nil)
    _update_spec(pos)
    -- -- local timer_id = wcons.add_timer(0, timer, pos)
    local timer = minetest.get_node_timer(pos)
    timer:start(0)
    return stack
end


local function on_punch ( pos, node, puncher, pointed )
    -- DEBUG("punch: %s", dump(pos))
    wcons.activate_device(pos, puncher, nil)
end


----------------------------------------------------------------------


local function on_init_con ( dev, node, meta, player, params )
    local mt = meta:to_table()
    if not mt then
        mt = {}
    end
    local fields = mt.fields
    if not fields then
        fields = {}
        mt.fields = fields
    end
    fields[CON_MODE] = MODE_AUTO
    fields[CON_SPEC] = "1=100,1=0"
    meta:from_table(mt)
    DEBUG("init_blinker at %s : %s", minetest.pos_to_string(dev.pos), dump(minetest.get_meta(dev.pos):to_table()))
end


local function on_activate_con ( dev, node, meta, player, params )
    local mode = meta:get_int(CON_MODE)
    mode = mode + 1
    if mode < 0 or mode >= MODE_COUNT then
        mode = 0
    end
    meta:set_int(CON_MODE, mode)
    wcons.emit_signal(dev.pos, { type="wcons:blinker", [CON_MODE]=mode })
    if player then
        minetest.chat_send_player(player:get_player_name(), "Blinker mode: " .. MODE_NAMES[mode])
    end
end


local function _update_signal ( dev, meta )
    local t = meta:to_table()
    local f = t.fields
    -- DEBUG("fields: %s", dump(f))
    local signal = {
        type = "wcons:blinker",
        [CON_MODE] = tonumber(f[CON_MODE]) or 0,
        [CON_SPEC] = f[CON_SPEC] or "",
    }
    return signal
end


local function on_update_con ( dev, node, meta )
    wcons.emit_signal(dev.pos, _update_signal(dev, meta))
end


local function on_receive_signal_con ( dev, node, meta, emitter_dev, emitter_node, signal )
    -- DEBUG("signal received: %s", signal.type)
    local type = signal.type
    if type == "wcons:blinker" then
        for name, val in pairs(signal) do
            if name ~= "type" then
                meta:set_string(name, tostring(val))
            end
        end
        -- meta:from_table(mtable)
    elseif type == "wcons:request_state" then
        wcons.emit_signal_device(dev.pos, emitter_dev.pos, _update_signal(dev, meta), nil)
    end
end



local function on_get_formspec_con ( pos )
    local meta = minetest.get_meta(pos)
    local spec = meta:get_string(CON_SPEC)
    local fs =
        "field[0,0;6,1;con_spec;Spec.;" .. spec .. "]" ..
        "field_close_on_enter[con_spec;false]"
    return fs
end


local function on_receive_fields_con ( pos, fields )
    -- DEBUG("fields: %s", dump(fields))
    local meta = minetest.get_meta(pos)
    if fields.con_spec then
        meta:set_string(CON_SPEC, fields.con_spec)
    end
    wcons.update_device(pos)
end


wcons.register_controller({
    name = "wcons:blinker_controller",
    description = "Blinker",
    on_init = on_init_con,
    on_activate = on_activate_con,
    on_update = on_update_con,
    on_receive_signal = on_receive_signal_con,
    on_get_formspec = on_get_formspec_con,
    on_receive_fields = on_receive_fields_con,    
})


----------------------------------------------------------------------


local nodes_list = {}

for mode, mode_name in pairs(MODE_NAMES) do
    local name = "wcons:blinker_" .. mode_name
    local texture = "[combine:16x16:0,0=wcons_light_sensor.png:4,4=wcons_button_" .. mode_name .. ".png"
    local def = {
        description = "Blinker (" .. mode_name .. ")",
        groups = { snappy = 3 },
        inventory_image = minetest.inventorycube (
            texture,
            "wcons_light_sensor.png",
            "wcons_light_sensor.png"
        ),
        drawtype = "nodebox",
        tiles = {
            texture,
            "wcons_light_sensor.png",
            "wcons_light_sensor.png",
            "wcons_light_sensor.png",
            "wcons_light_sensor.png",
            "wcons_light_sensor.png",
        },
        node_box = {
            type = "fixed",
            fixed = { -0.3, -0.5, -0.3, 0.3, -0.3, 0.3 },
        },
        walkable = false,
        after_place_node = after_place_node,
        on_punch = on_punch,
        on_timer = on_timer,
    }
    if mode ~= MODE_AUTO then
        def.drop = "wcons:blinker_auto"
        def.groups.not_in_creative_inventory = 1
    end
    minetest.register_node(name, def)
    table.insert(nodes_list, name)
    MODE_ITEMS[mode] = name
end


-- [FIXME] add an alternate recipe if homedecor is not here ?
if minetest.get_modpath("homedecor") then
    minetest.register_craft({
        type = "shaped",
        output = "wcons:blinker_auto",
        recipe = {
            { "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" },
            { "homedecor:copper_wire",      "homedecor:ic",               "homedecor:copper_wire" },
            { "homedecor:plastic_sheeting", "homedecor:plastic_sheeting", "homedecor:plastic_sheeting" },
        },
    })
end

wcons.register_device({
    name = "wcons:blinker",
    nodes = nodes_list,
    on_emit_signal = on_emit_signal,
    on_receive_signal = on_receive_signal,
})


-- wcons.register_timer({
--     name = "wcons:blinker_timer",
--     func = timer
-- })
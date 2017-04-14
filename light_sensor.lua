
local LIGHT_MAX = minetest.LIGHT_MAX

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

local CON_MODE      = "wcons:light_sensor_controller:mode"
local CON_MINV      = "wcons:light_sensor_controller:minv"
local CON_MAXV      = "wcons:light_sensor_controller:maxv"
local CON_THRESHOLD = "wcons:light_sensor_controller:threshold"
local CON_FACTOR    = "wcons:light_sensor_controller:factor"
local CON_ADD       = "wcons:light_sensor_controller:add"
local CON_REVERSE   = "wcons:light_sensor_controller:reverse"
local CON_VARIABLE  = "wcons:light_sensor_controller:variable"


local CON_DEFAULTS = {
    [CON_MODE] = MODE_AUTO,
    [CON_MINV] = 0,
    [CON_MAXV] = 100,
    [CON_THRESHOLD] = 10,
    [CON_FACTOR] = 12.5,
    [CON_ADD] = -4,
    [CON_REVERSE] = true,
    [CON_VARIABLE] = false,
}


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


local function meta_table ( meta )
    local mtable = meta:to_table()
    if not mtable then
        mtable = {}
    end
    if not mtable.fields then
        mtable.fields = {}
    end
    return mtable
end


local function after_place_node ( pos, placer, stack, pointed )
    wcons.set_device_controller(pos, "wcons:light_sensor_controller", placer, nil)
    -- local timer = minetest.get_node_timer(pos)
    -- timer:start(2)
    local meta = minetest.get_meta(pos)
    meta:set_string("foo", "bar")
    return stack
end


local function on_punch ( pos, node, puncher, pointed )
    -- DEBUG("punch: %s", dump(pos))
    wcons.activate_device(pos, puncher, nil)
end


local function _get_voltage ( meta, light )
    local var = meta:get_int(CON_VARIABLE)
    local rev = meta:get_int(CON_REVERSE)
    if var == 0 then
        local threshold = meta:get_int(CON_THRESHOLD)
        DEBUG("fix, threshold=%d, rev=%d", threshold, rev)
        if rev == 0 then
            if light >= threshold then
                return meta:get_int(CON_MAXV)
            else
                return meta:get_int(CON_MINV)
            end            
        else
            if light >= threshold then
                return meta:get_int(CON_MINV)
            else
                return meta:get_int(CON_MAXV)
            end
        end
    else
        local minv = meta:get_int(CON_MINV)
        local maxv = meta:get_int(CON_MAXV)
        local add = meta:get_float(CON_ADD)
        local factor = meta:get_float(CON_FACTOR)
        local value = light
        if rev ~= 0 then
            value = LIGHT_MAX - value
        end
        value = (add + value) * factor
        if value < minv then value = minv
        elseif value > maxv then value = maxv end
        return value
    end
end


-- [FIXME] cancel the timer when not in auto mode
-- local function on_timer ( pos, elapsed )
local function on_timer ( pos, node, active_count, active_count_wider )
    local meta = minetest.get_meta(pos)
    local mode = meta:get_int(CON_MODE)
    if mode == MODE_AUTO then
        local above = { x=pos.x, y=pos.y+1, z=pos.z }
        local light = minetest.get_node_light(above)
        local value = _get_voltage(meta, light) -- (LIGHT_MAX - light) * 100 / LIGHT_MAX
        DEBUG("sensor timer: light=%d, voltage=%d", light, value)
        wcons.emit_signal(pos, { type="wcons:voltage", value=value })
    elseif mode == MODE_ON then
        -- wcons.emit_signal(pos, { type="wcons:voltage", value=100 })
    else
        -- wcons.emit_signal(pos, { type="wcons:voltage", value=0 })
    end
    return true
end


local function on_emit_signal ( dev, node, signal )
    if signal.type == "wcons:light_sensor" then
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
        if mode == MODE_AUTO then
            on_timer(dev.pos, minetest.get_node(dev.pos))
        elseif mode == MODE_ON then
            wcons.emit_signal(dev.pos, { type="wcons:voltage", value=100 })
        elseif mode == MODE_OFF then
            wcons.emit_signal(dev.pos, { type="wcons:voltage", value=0 })
        end
    end
end


local function on_receive_signal ( dev, node, emitter_dev, emitter_node, signal )
    on_emit_signal(dev, node, signal)
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
    for name, val in pairs(CON_DEFAULTS) do
        if fields[name] == nil then
            fields[name] = val
        end
    end
    meta:from_table(mt)
end


local function on_activate_con ( dev, node, meta, player, params )
    local mode = meta:get_int(CON_MODE)
    mode = mode + 1
    if mode < 0 or mode >= MODE_COUNT then
        mode = 0
    end
    meta:set_int(CON_MODE, mode)
    wcons.emit_signal(dev.pos, { type="wcons:light_sensor", [CON_MODE]=mode })
    if player then
        minetest.chat_send_player(player:get_player_name(), "Light sensor mode: " .. MODE_NAMES[mode])
    end
end


local function _update_signal ( dev, meta )
    local t = meta:to_table()
    local f = t.fields
    -- DEBUG("fields: %s", dump(f))
    local signal = {
        type = "wcons:light_sensor",
        [CON_MODE] = tonumber(f[CON_MODE]) or 0,
        [CON_MINV] = tonumber(f[CON_MINV]) or 0,
        [CON_MAXV] = tonumber(f[CON_MAXV]) or 0,
        [CON_THRESHOLD] = tonumber(f[CON_THRESHOLD]) or 0,
        [CON_FACTOR] = tonumber(f[CON_FACTOR]) or 0,
        [CON_ADD] = tonumber(f[CON_ADD]) or 0,
        [CON_REVERSE] = tonumber(f[CON_REVERSE]) or 0,
        [CON_VARIABLE] = tonumber(f[CON_VARIABLE]) or 0,
    }
    return signal
end


local function on_update_con ( dev, node, meta )
    wcons.emit_signal(dev.pos, _update_signal(dev, meta))
end


local function on_receive_signal_con ( dev, node, meta, emitter_dev, emitter_node, signal )
    -- DEBUG("signal received: %s", signal.type)
    local type = signal.type
    local mtable = meta_table(meta)
    local mfields = mtable.fields
    if type == "wcons:light_sensor" then
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
    local minv = meta:get_int(CON_MINV)
    local maxv = meta:get_int(CON_MAXV)
    local threshold = meta:get_int(CON_THRESHOLD)
    local add = meta:get_float(CON_ADD)
    local factor = meta:get_float(CON_FACTOR)
    local reverse = meta:get_int(CON_REVERSE)
    local variable = meta:get_int(CON_VARIABLE)
    local fs =
        "field[0,0;2,1;con_minv;Min volt.;" .. minv .. "]" ..
        "field_close_on_enter[con_minv;false]" ..
        "field[2,0;2,1;con_maxv;Max volt.;" .. maxv .. "]" ..
        "field_close_on_enter[con_maxv;false]" ..
        "field[4,0;2,1;con_threshold;Threshold;" .. threshold .. "]" ..
        "field[0,1.5;2,1;con_add;Add;" .. add .. "]" ..
        "field_close_on_enter[con_add;false]" ..
        "field_close_on_enter[con_threshold;false]" ..
        "field[2,1.5;2,1;con_factor;Factor;" .. factor .. "]"
    fs = fs .. "checkbox[0,2.5;con_rev;Reverse;" .. (reverse == 0 and "false" or "true") .. "]"
    fs = fs .. "checkbox[3,2.5;con_var;Variable;" .. (variable == 0 and "false" or "true") .. "]"
    return fs
end


local function on_receive_fields_con ( pos, fields )
    -- DEBUG("fields: %s", dump(fields))
    local meta = minetest.get_meta(pos)
    if fields.con_minv then
        meta:set_int(CON_MINV, tonumber(fields.con_minv) or 0)
    end
    if fields.con_maxv then
        meta:set_int(CON_MAXV, tonumber(fields.con_maxv) or 0)
    end
    if fields.con_threshold then
        meta:set_int(CON_THRESHOLD, tonumber(fields.con_threshold) or 0)
    end
    if fields.con_add then
        meta:set_float(CON_ADD, tonumber(fields.con_add) or 0)
    end
    if fields.con_factor then
        meta:set_float(CON_FACTOR, tonumber(fields.con_factor) or 0)
    end
    if fields.con_rev then
        meta:set_int(CON_REVERSE, fields.con_rev == "true" and 1 or 0)
    end
    if fields.con_var then
        meta:set_int(CON_VARIABLE, fields.con_var == "true" and 1 or 0)
    end
    wcons.update_device(pos)
end


wcons.register_controller({
    name = "wcons:light_sensor_controller",
    description = "Light sensor",
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
    local name = "wcons:light_sensor_" .. mode_name
    local texture = "[combine:16x16:0,0=wcons_light_sensor.png:4,4=wcons_button_" .. mode_name .. ".png"
    local def = {
        description = "Light sensor (" .. mode_name .. ")",
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
        -- on_timer = on_timer,
    }
    if mode ~= MODE_AUTO then
        def.drop = "wcons:light_sensor_auto"
    end
    minetest.register_node(name, def)
    table.insert(nodes_list, name)
    MODE_ITEMS[mode] = name
end


minetest.register_abm({
    label = "Light sensor",
    nodenames = { "wcons:light_sensor_auto" },
    interval = 2,
    chance = 1,
    action = on_timer,
})


wcons.register_device({
    name = "wcons:light_sensor",
    nodes = nodes_list,
    on_emit_signal = on_emit_signal,
    on_receive_signal = on_receive_signal,
})

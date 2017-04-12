
----------------------------------------------------------------------
--                             LOGGING                              --
----------------------------------------------------------------------

local LOG_DOMAIN = minetest.get_current_modname()
local DEBUG, INFO, ACTION, WARNING, ERROR
if minetest.get_modpath("logging") then
    DEBUG = function (...)   logging.emit(LOG_DOMAIN, logging.LEVEL_DEBUG,   string.format(...)) end
    INFO = function (...)    logging.emit(LOG_DOMAIN, logging.LEVEL_INFO,    string.format(...)) end
    ACTION = function (...)  logging.emit(LOG_DOMAIN, logging.LEVEL_ACTION,  string.format(...)) end
    WARNING = function (...) logging.emit(LOG_DOMAIN, logging.LEVEL_WARNING, string.format(...)) end
    ERROR = function (...)   logging.emit(LOG_DOMAIN, logging.LEVEL_ERROR,   string.format(...)) end
else
    DEBUG = function (...)   minetest.log("verbose", "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    INFO = function (...)    minetest.log("info",    "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    ACTION = function (...)  minetest.log("action",  "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    WARNING = function (...) minetest.log("warning", "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
    ERROR = function (...)   minetest.log("error",   "[" .. LOG_DOMAIN .. "] " .. string.format(...)) end
end


----------------------------------------------------------------------
--                              SWICTH                              --
----------------------------------------------------------------------

local SWITCH_STATE       = "wcons:controller_switch:state"
local SWITCH_MAX_VOLTAGE = "wcons:controller_switch:max_voltage"


local function on_init_switch ( dev, node, meta, player, params )
    local max = meta:get_int(SWITCH_MAX_VOLTAGE)
    if max == 0 then
        meta:set_int(SWITCH_MAX_VOLTAGE, 100) 
    end
end


local function on_activate_switch ( dev, node, meta, player, params)
    local state = meta:get_int(SWITCH_STATE)
    local signal = { type="wcons:voltage" }
    if state == 0 then
        signal.value = meta:get_int(SWITCH_MAX_VOLTAGE)
        meta:set_int(SWITCH_STATE, 1)
    else
        signal.value = 0
        meta:set_int(SWITCH_STATE, 0)
    end
    wcons.emit_signal(dev.pos, signal, player)
end


local function on_receive_signal_switch ( dev, node, meta, emitter_dev, emitter_node, signal )
    DEBUG("controller switch received signal")
    local type = signal.type
    if type == "wcons:request_state" then
        local state = meta:get_int(SWITCH_STATE)
        local state_signal = { type="wcons:voltage" }
        if state == 0 then
            state_signal.value = 0
        else
            state_signal.value = meta:get_int(SWITCH_MAX_VOLTAGE)
        end
        wcons.emit_signal_device(dev.pos, emitter_dev.pos, state_signal, nil) -- player ?
    elseif type == "wcons:voltage" then
        if signal.value == 0 then
            meta:set_int(SWITCH_STATE, 0)
        else
            meta:set_int(SWITCH_STATE, 1)
        end
    end
end


local function on_get_formspec_switch ( pos )
    local meta = minetest.get_meta(pos)
    local max_voltage = meta:get_int(SWITCH_MAX_VOLTAGE)
    local fs = "field[0,0;2,1;con_max_voltage;Max volt.;" .. max_voltage .. "]" ..
        "field_close_on_enter[con_max_voltage;false]"
    return fs
end


local function on_receive_fields_switch ( pos, fields )
    local meta = minetest.get_meta(pos)
    if fields.con_max_voltage then
        local mv = tonumber(fields.con_max_voltage)
        if mv then
            meta:set_int(SWITCH_MAX_VOLTAGE, mv)
        end
    end
end


wcons.register_controller({
    name = "wcons:voltage_switch_controller",
    description = "Simple switch",
    on_init = on_init_switch,
    on_activate = on_activate_switch,
    on_receive_signal = on_receive_signal_switch,
    on_get_formspec = on_get_formspec_switch,
    on_receive_fields = on_receive_fields_switch,
})


----------------------------------------------------------------------

local DIMMER_STATE       = "wcons:controller_dimmer:state"
local DIMMER_MIN_VOLTAGE = "wcons:controller_dimmer:min_voltage"
local DIMMER_MAX_VOLTAGE = "wcons:controller_dimmer:max_voltage"
local DIMMER_N_STEPS     = "wcons:controller_dimmer:n_steps"


local function on_init_dimmer ( dev, node, meta, player, params )
    local max = meta:get_int(DIMMER_MAX_VOLTAGE)
    if max == 0 then
        meta:set_int(DIMMER_MAX_VOLTAGE, 100)
    end
    local n_steps = meta:get_int(DIMMER_N_STEPS)
    if n_steps == 0 then
        meta:set_int(DIMMER_N_STEPS, 5)
    end
end


local function on_activate_dimmer ( dev, node, meta, player, params )
    local state = meta:get_int(DIMMER_STATE)
    local n_steps = meta:get_int(DIMMER_N_STEPS)
    local minv = meta:get_int(DIMMER_MIN_VOLTAGE)
    local maxv = meta:get_int(DIMMER_MAX_VOLTAGE)
    state = state + 1
    if state < 0 or state >= n_steps then
        state = 0
    end
    local signal = {
        type = "wcons:voltage",
        value = math.floor(minv + (maxv - minv) * state / (n_steps - 1)),
    }
    DEBUG("step %d: %d", state, signal.value)
    wcons.emit_signal(dev.pos, signal, player)
    meta:set_int(DIMMER_STATE, state)
end


local function on_receive_signal_dimmer ( dev, node, meta, emitter_dev, emitter_node, signal )
    DEBUG("[TODO] receive_signal")
end


local function on_get_formspec_dimmer ( pos )
    local meta = minetest.get_meta(pos)
    local minv = meta:get_int(DIMMER_MIN_VOLTAGE)
    local maxv = meta:get_int(DIMMER_MAX_VOLTAGE)
    local n_steps = meta:get_int(DIMMER_N_STEPS)
    local fs =
        "field[0,0;2,1;con_minv;Min volt.;" .. minv .. "]" ..
        "field_close_on_enter[con_minv;false]" ..
        "field[2,0;2,1;con_maxv;Max volt.;" .. maxv .. "]" ..
        "field_close_on_enter[con_maxv;false]" ..
        "field[4,0;2,1;con_steps;Steps;" .. n_steps .. "]" ..
        "field_close_on_enter[con_steps;false]"
    return fs
end


local function on_receive_fields_dimmer ( pos, fields )
    local meta = minetest.get_meta(pos)
    if fields.con_minv then
        local minv = tonumber(fields.con_minv)
        if minv then
            meta:set_int(DIMMER_MIN_VOLTAGE, minv)
        end
    end
    if fields.con_maxv then
        local maxv = tonumber(fields.con_maxv)
        if maxv then
            meta:set_int(DIMMER_MAX_VOLTAGE, maxv)
        end
    end
    if fields.con_steps then
        local steps = tonumber(fields.con_steps)
        if steps then
            meta:set_int(DIMMER_N_STEPS, steps)
        end
    end
end


wcons.register_controller({
    name = "wcons:voltage_dimmer_controller",
    description = "Dimmer switch",
    on_init = on_init_dimmer,
    on_activate = on_activate_dimmer,
    on_receive_signal = on_receive_signal_dimmer,
    on_get_formspec = on_get_formspec_dimmer,
    on_receive_fields = on_receive_fields_dimmer,
})

----------------------------------------------------------------------

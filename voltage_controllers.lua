
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

local STATE       = "wcons:controller_switch:state"
local MAX_VOLTAGE = "wcons:controller_switch:max_voltage"


local function on_init_switch ( dev, node, meta, player, params )
    local max = meta:get_int(MAX_VOLTAGE)
    if max == 0 then
        meta:set_int(MAX_VOLTAGE, 100) 
    end
end


local function on_activate_switch ( dev, node, meta, player, params)
    local state = meta:get_int(STATE)
    local signal = { type="wcons:voltage" }
    if state == 0 then
        signal.value = meta:get_int(MAX_VOLTAGE)
        meta:set_int(STATE, 1)
    else
        signal.value = 0
        meta:set_int(STATE, 0)
    end
    wcons.emit_signal(dev.pos, signal, player)
end


local function on_receive_signal_switch ( dev, node, meta, emitter_dev, emitter_node, signal )
    DEBUG("controller switch received signal")
    local type = signal.type
    if type == "wcons:request_state" then
        local state = meta:get_int(STATE)
        local state_signal = { type="wcons:voltage" }
        if state == 0 then
            state_signal.value = 0
        else
            state_signal.value = meta:get_int(MAX_VOLTAGE)
        end
        wcons.emit_signal_device(dev.pos, emitter_dev.pos, state_signal, nil) -- player ?
    elseif type == "wcons:voltage" then
        if signal.value == 0 then
            meta:set_int(STATE, 0)
        else
            meta:set_int(STATE, 1)
        end
    end
end


wcons.register_controller({
    name = "wcons:voltage_switch_controller",
    on_init = on_init_switch,
    on_activate = on_activate_switch,
    on_receive_signal = on_receive_signal_switch,
})


----------------------------------------------------------------------

-- wcons.register_controller({
--     name = "wcons:voltage_variator_controller",
--     on_init = on_init,
--     on_activate = on_activate,
--     on_receive_signal = on_receive_signal,
--     on_connect = on_connect,
--     on_connected_device = on_connectedc_device,
-- })

-- wcons.register_controller({
--     name = "wcons:voltage_blink_controller",
--     on_init = on_init,
--     on_activate = on_activate,
--     on_receive_signal = on_receive_signal,
--     on_connect = on_connect,
--     on_connected_device = on_connectedc_device,
-- })

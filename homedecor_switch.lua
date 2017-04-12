

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


local function after_place_node ( pos, placer, stack, pointed )
    DEBUG("switch placed")
    wcons.set_device_controller(pos, "wcons:voltage_switch_controller", placer, nil)
end


local function on_punch ( pos, node, puncher, pointed )
    wcons.activate_device(pos, puncher, nil)
    -- local meta = minetest.get_meta(pos)
    -- local state = meta:get_float("switch_state")
    -- if state == 0 then
    --     wcons.emit_signal(pos, { type="voltage", value=100 }, puncher)
    --     meta:set_float("switch_state", 1)
    -- else
    --     wcons.emit_signal(pos, { type="voltage", value=0 }, puncher)
    --     meta:set_float("switch_state", 0)
    -- end
end


-- local function on_device_connected_switch ( pos, node, dev_pos, dev_node )
--     local meta = minetest.get_meta(pos)
--     local state = meta:get_float("switch_state")
--     if state == 0 then
--         wcons.send_signal(pos, { type="switch", value=0 })
--     else
--         wcons.send_signal(pos, { type="switch", value=15 })
--     end
-- end


minetest.override_item("homedecor:light_switch", {
    after_place_node = after_place_node,
    on_punch = on_punch,
})


wcons.register_device({
    name = "wcons:light_switch",
    type = "node",
    nodes = { "homedecor:light_switch" },
    -- on_device_connected = on_device_connected_switch,
})

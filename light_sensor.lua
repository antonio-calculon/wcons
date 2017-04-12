

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


local function on_place ( stack, placer, pointed )
    if pointed.type ~= "node" then
        return
    end
    local pos = pointed.above
    -- local above = minetest.get_node(pos)
    minetest.set_node(pos, { name="wcons:light_sensor" })
    stack:take_item(1)
    local timer = minetest.get_node_timer(pos)
    timer:start(2)
    return stack
end


local function on_timer ( pos, elapsed )
    local above = { x=pos.x, y=pos.y+1, z=pos.z }
    local light = minetest.get_node_light(above)
    DEBUG("sensor timer: light=%d", light)
    local value = 15 - light
    wcons.send_signal(pos, { type="switch", value=value })
    return true
end


----------------------------------------------------------------------


minetest.register_node("wcons:light_sensor", {
    description = "Light sensor",
    groups = { crumbly = 1 },
    inventory_image = minetest.inventorycube (
        "wcons_light_sensor.png",
        "wcons_light_sensor.png",
        "wcons_light_sensor.png"
    ),
    drawtype = "nodebox",
    tiles = { "wcons_light_sensor.png" },
    node_box = {
        type = "fixed",
        fixed = { -0.3, -0.5, -0.3, 0.3, -0.3, 0.3 },
    },
    walkable = false,
    on_place = on_place,
    on_timer = on_timer,
})


wcons.register_device({
    name = "wcons:light_sensor",
})



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

-- API
wcons = {}

local MODPATH = minetest.get_modpath(minetest.get_current_modname())

local WORLDPATH = minetest.get_worldpath()
local SAVEPATH = WORLDPATH .. "/wcons"
local SAVE_TIMEOUT = 5

wcons.SAVEPATH = SAVEPATH
wcons.SAVE_TIMEOUT = SAVE_TIMEOUT

-- register the spool of copper wire if we don't have it
-- (I made the recipe simpler to not have to redefine the whole
-- oil/paraffin/plastic chain)
if not minetest.registered_items["homedecor:copper_wire"] then
    minetest.register_craftitem(":homedecor:copper_wire", {
        description = "Spool of copper wire",
        inventory_image = "wcons_copper_wire.png",
    })
    minetest.register_craft({
        type = "shaped",
        output = "homedecor:copper_wire",
        recipe = {
            { "",                     "default:paper", "" },
            { "default:copper_ingot", "default:paper", "default:copper_ingot" },
            { "",                     "default:paper", "" },            
        }
    })
end

dofile(MODPATH .. "/api.lua")
dofile(MODPATH .. "/lighting.lua")
dofile(MODPATH .. "/light_sensor.lua")
dofile(MODPATH .. "/blinker.lua")
dofile(MODPATH .. "/voltage_controllers.lua")
dofile(MODPATH .. "/connector.lua")
dofile(MODPATH .. "/remote.lua")

if minetest.get_modpath("default") then
    dofile(MODPATH .. "/default_lights.lua")
end

if minetest.get_modpath("homedecor") then
    dofile(MODPATH .. "/homedecor_switch.lua")
    dofile(MODPATH .. "/homedecor_lights.lua")
end

DEBUG("MAX_LIGHT: %d", minetest.LIGHT_MAX)

-- load/save
minetest.mkdir(SAVEPATH)
minetest.register_on_shutdown(wcons.save_datas)
minetest.after(SAVE_TIMEOUT, wcons.save_datas)
wcons.load_datas()

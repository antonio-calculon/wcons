

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


local CONTROLLERS = {
    "wcons:voltage_switch_controller",
    "wcons:voltage_dimmer_controller",
}

local CONTROLLERS_MAP = nil
local CONTROLLER_ITEMS = nil
local CONTROLLER_INDICES = nil

local PLAYER_CONTEXT = {}


local function _init_controllers_map ()
    if CONTROLLERS_MAP then
        return
    end
    CONTROLLERS_MAP = {}
    CONTROLLER_INDICES = {}
    CONTROLLER_ITEMS = ""
    local sep = ""
    for i = 1, #CONTROLLERS do
        local con = CONTROLLERS[i]
        local def = wcons.registered_controllers[con]
        if def then
            CONTROLLER_INDICES[con] = i
            local name = def.description
            CONTROLLERS_MAP[name] = con
            CONTROLLER_ITEMS = CONTROLLER_ITEMS .. sep .. name
            sep=","
        else
            ERROR("unknown controller: '%s'", con)
        end
    end
end


local function _create_formspec ( player_name, pos )
    _init_controllers_map()
    local meta = minetest.get_meta(pos)
    local con = meta:get_string("wcons:controller")
    local conidx = CONTROLLER_INDICES[con] or 0
    PLAYER_CONTEXT[player_name] = {
        controller = con,
        pos = pos,
    }
    local fs = "size[8,8]"
    fs = fs ..
        "label[2,0;Light switch " .. minetest.pos_to_string(pos) .. "]" ..
        "button_exit[7,0;1,1;but_close;X]"
    fs = fs ..
        "label[0,1;Controller:]" ..
        "dropdown[2,1;6;drop_con;" .. CONTROLLER_ITEMS .. ";" .. conidx .. "]"
    fs = fs .. "container[1,3]" .. wcons.get_controller_formspec(con, pos) .. "container_end[]"
    return fs
end


local function show_formspec ( player, pos )
    local name = player:get_player_name()
    minetest.show_formspec(name, "wcons:light_switch_config", _create_formspec(name, pos))
end


local function on_rightclick ( pos, node, player, stack, pointed )
    show_formspec(player, pos)
end


local function on_receive_fields ( player, formname, fields )
    if formname ~= "wcons:light_switch_config" then
        return false
    end
    local name = player:get_player_name()
    local context = PLAYER_CONTEXT[name]
    -- check drop down
    if fields.drop_con then
        local con = CONTROLLERS_MAP[fields.drop_con]
        if con ~= context.controller then
            wcons.set_device_controller(context.pos, con, player, nil)
            show_formspec(player, context.pos)
            return true
        end
    end
    DEBUG("receive fields: %s - %s", formname, dump(fields))
    wcons.send_controller_fields(context.controller, context.pos, fields)
    -- [TODO]
    -- if fields.quit then
    --     wcons.update_device_state(pos)
    -- end
    return true
end


local function after_place_node ( pos, placer, stack, pointed )
    DEBUG("switch placed")
    wcons.set_device_controller(pos, "wcons:voltage_switch_controller", placer, nil)
    -- local meta = minetest.get_meta(pos)
    -- meta:set_string("formspec", _create_formspec(pos, meta))
end


local function on_punch ( pos, node, puncher, pointed )
    wcons.activate_device(pos, puncher, nil)
end


minetest.override_item("homedecor:light_switch", {
    after_place_node = after_place_node,
    on_punch = on_punch,
    on_rightclick = on_rightclick,
})

minetest.register_on_player_receive_fields(on_receive_fields)


wcons.register_device({
    name = "wcons:light_switch",
    type = "node",
    nodes = { "homedecor:light_switch" },
})

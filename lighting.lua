
local LIGHT_MAX = minetest.LIGHT_MAX

local registered_lights = {}
local registered_light_nodes = {}

wcons.registered_lights = registered_lights
wcons.registered_light_nodes = registered_light_nodes


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


local function on_receive_signal ( dev, node, emitter_dev, emitter_node, signal )
    -- DEBUG("signal received: type=%s, value=%s", signal.type, tostring(signal.value))
    if signal.type ~= "wcons:voltage" then
        -- DEBUG("unknown signal")
        return
    end
    local light_def = registered_light_nodes[node.name]
    if not light_def then
        -- [FIXME] anything we can do about this ?
        if node.name ~= "ignore" then
            ERROR("light def not found for %s", node.name)
        end
        return
    end
    local level = signal.value
    local l = math.floor(level * light_def.max_light / 100)
    if l < 0 then l = 0
    elseif l > LIGHT_MAX then l = LIGHT_MAX end
    -- DEBUG("voltage: %d/%d -> %d", level, light_def.max_light, l)
    -- DEBUG("node: %s", dump(node))
    local new_name = light_def.nodes[l]
    if node.name ~= new_name then
        node.name = new_name
        minetest.swap_node(dev.pos, node)
    end
end


wcons.register_light_device = function ( base_node, existing_nodes )
    local base_name = string.gsub(base_node, "^.*:", "")
    local base_def = minetest.registered_nodes[base_node]
    local light_def = {
        name = base_node,
        nodes = {},
        max_light = 0,
    }
    if not base_def then
        ERROR("unknown node: %s", base_node)
    end
    local node_list = {}
    for _, node in ipairs(existing_nodes) do
        local def = minetest.registered_nodes[node]
        if not def then
            ERROR("unknown node: '%s'", node)
            return
        end
        table.insert(node_list, node)
        if def.light_source > light_def.max_light then
            light_def.max_light = def.light_source
        end
        light_def.nodes[def.light_source] = node
        registered_light_nodes[node] = light_def
    end
    -- create missing ones
    for i = 0, LIGHT_MAX do
        if not light_def.nodes[i] then
            local name = "wcons:" .. base_name .. "_" .. i            
            local def = table.copy(base_def)
            def.light_source = i
            if def.drop then
                WARNING("[TODO] overriding %s drop", base_node)
            end
            def.drop = base_node
            minetest.register_node(name, def)
            light_def.nodes[i] = name
            table.insert(node_list, name)
            registered_light_nodes[name] = light_def
        end
    end
    -- register device
    wcons.register_device({
        name = "wcons:" .. base_name,
        type = "node",
        nodes = node_list,
        on_receive_signal = on_receive_signal,
    })
end

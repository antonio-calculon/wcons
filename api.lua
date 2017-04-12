

local registered_devices = {}
local registered_device_nodes = {}     -- map <node_name, device_def>
local registered_node_handlers = {}    -- map <node_name, handlers>
local registered_controllers = {}

local networks = {}   -- map <id, net>
local dev_map = {}    -- map <hpos, dev>

local MAXID = 65536

-- localize some methods
local hash_pos = minetest.hash_node_position
local pos2str = minetest.pos_to_string
local str2pos = minetest.string_to_pos

local function chat ( player, ... )
    if not player then
        return
    elseif type(player) ~= "string" then
        player = player:get_player_name()
    end
    minetest.chat_send_player(player, string.format(...))
end

-- I must be stupid, but I can't find how to do that in lua :)
local function table_len ( t )
    local l = 0
    for a, b in pairs(t) do
        l = l + 1
    end
    return l
end


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


local function wc_invalidate_network ( net_id )
end


local function wc_invalidate_items ()
end


----------------------------------------------------------------------


-- for debug only
local function devstring ( dev )
    local node = minetest.get_node(dev.pos)
    local def = minetest.registered_items[node.name]
    local descr = "<unknown item>"
    if def then
        descr = def.description
    end
    return descr .. " " .. pos2str(dev.pos)
end


local function get_network_id ( )
    while true do
        local id = math.random(1, MAXID)
        if not networks[id] then
            return id
        end
    end
end


local function _cleanup_dev ( pos )
    local hpos = hash_pos(pos)
    local dev = dev_map[hpos]
    if dev then
        local net = dev.net
        if net then
            net.devices[hpos] = nil
            wc_invalidate_network(net.id)
        end
        dev_map[hpos] = nil
    end
end


local function _check_dev ( dev )
    local node = minetest.get_node(dev.pos)
    local def = registered_device_nodes[node.name]
    if def ~= dev.def then
        WARNING("[TODO] invalid device: %s", devstring(dev))
        return nil
    end
    return node
end


local function _get_dev ( pos )
    local hpos = hash_pos(pos)
    local node = minetest.get_node(pos)
    local def = registered_device_nodes[node.name]
    local dev = dev_map[hpos]
    if dev then
        if dev.def ~= def then
            WARNING("[TODO] invalid device!")
            if def then
                -- [FIXME] do something if dev.net is not nil ?
                dev.def = def
            else
                _cleanup_dev(pos)
                return nil, nil
            end
        end
        return dev, node
    else
        if def then
            local dev = {
                    def = def,
                    pos = table.copy(pos),
                    hpos = hpos,
                    net = nil,
                }
            return dev, node
        else
            return nil, nil
        end
    end
end


-- wc_start_spark_particles
--
local function wc_start_spark_particles ( pos, time, player_name )
    return minetest.add_particlespawner({
        amount = 100,
        time = time,
        minpos = { x=pos.x - 0.25, y=pos.y,       z=pos.z - 0.25 },
        maxpos = { x=pos.x + 0.25, y=pos.y + 0.5, z=pos.z + 0.25 },
        minvel = { x=-1, y=-1, z=-1 },
        maxvel = { x=1, y=1, z=1 },
        minacc = { x=0, y=-2, z=0 },
        maxacc = { x=0, y=-2, z=0 },
        minexptime = 0.25,
        maxexptime = 0.5,
        minsize = 1,
        maxsize = 2,
        collisiondetection = false,
        vertical = false,
        texture = "wcons_spark_particle.png",
        playername = player_name,
    })
end


-- wc_show_network
--
local function wc_show_network ( pos, player )
    local player_name = player:get_player_name()
    local dev = _get_dev(pos)
    if not dev then
        chat(player_name, "No device here")
        return
    end
    local net = dev.net
    if not net then
        chat(player_name, "%s is not connected to any network", devstring(dev))
        return
    end
    DEBUG("showing network %d to %s", net.id, player_name)
    chat(player_name, "Network %d (%d devices)", net.id, table_len(net.devices))
    for hpos, dev in pairs(net.devices) do
        wc_start_spark_particles(dev.pos, 5, player_name)
    end
end


local function after_place_node ( pos, placer, stack, pointed )
    DEBUG("[TODO] place node")
    local hpos = hash_pos(pos)
    local dev = dev_map[hpos]
    if dev then
        WARNING("[TODO] invalid dev")
        _cleanup_dev(dev)
    end
    local node = minetest.get_node(pos)
    local handlers = registered_node_handlers[node.name]    
    if handlers.after_place_node then
        handlers.after_place_node(pos, placer, stack, pointed)
    end
end


local function after_dig_node ( pos, node, meta, digger )
    DEBUG("[TODO] dig node")
    local hpos = hash_pos(pos)
    local dev = dev_map[hpos]
    if dev then
        _cleanup_dev(pos)
    end
    local handlers = registered_node_handlers[node.name]
    if handlers.after_dig_node then
        handlers.after_dig_node(pos, node, meta, digger)
    end
end


-- wc_register_device
--
local function wc_register_device ( def )
    def = table.copy(def)
    if registered_devices[def.name] then
        ERROR("device '%s' is already registered", def.name)
        return false
    end
    -- item override
    for _, node_name in ipairs(def.nodes) do
        local node_def = minetest.registered_nodes[node_name]
        if not node_def then
            ERROR("node '%s' is not a registered node", def.name)
            return
        end
        registered_device_nodes[node_name] = def
        local handlers = {}
        registered_node_handlers[node_name] = handlers
        handlers.after_place_node = node_def.after_place_node
        handlers.after_dig_node = node_def.after_dig_node
        minetest.override_item(node_name, {
            after_place_node = after_place_node,
            after_dig_node = after_dig_node,
        })
    end
    registered_devices[def.name] = def
    DEBUG("device registered: '%s'", def.name)
    return true
end


local function _create_network ( dev1, dev2 )
    local net_id = get_network_id()
    DEBUG("creating network %d (devs %s, %s)", net_id, devstring(dev1), devstring(dev2))
    local net = {
        id = net_id,
        devices = {
            [dev1.hpos] = dev1,
            [dev2.hpos] = dev2,
        }
    }
    dev1.net = net
    dev2.net = net
    networks[net_id] = net
    dev_map[dev1.hpos] = dev1
    dev_map[dev2.hpos] = dev2
    wc_invalidate_network(net_id)
    return net_id
end


local function _add_device ( net, dev )
    local hpos = dev.hpos
    DEBUG("adding dev %s to network %d", devstring(dev), net.id)
    net.devices[hpos] = dev
    dev.net = net
    dev_map[hpos] = dev
    wc_invalidate_network(net.id)
end


local function _join_networks ( net1, net2 )
    DEBUG("joining networks %d and %d", net1.id, net2.id)
    local devices = net1.devices
    for hpos, dev in pairs(net2.devices) do
        dev.net = net1
        devices[hpos] = dev
        dev_map[hpos] = dev -- should be useless ??
    end
    networks[net2.id] = nil
    wc_invalidate_network(net1.id)
    wc_invalidate_network(net2.id)
    return net1
end


-- wc_connect_devices
--
local function wc_connect_devices ( pos1, pos2, player )
    local player_name = player and player:get_player_name()
    local dev1 = _get_dev(pos1)
    if not dev1 then
        ERROR("device 1 not found: %s", idstring(devspec1))
        return nil
    end
    local dev2 = _get_dev(pos2)
    if not dev2 then
        ERROR("device 2 not found: %s", idstring(devspec2))
        return nil
    end
    -- check networks
    local net1 = dev1.net
    local net2 = dev2.net
    if not (net1 or net2) then
        local net_id = _create_network(dev1, dev2)
        chat(player, "Network %d created (%s and %s)", net_id, devstring(dev1), devstring(dev2))
    elseif net1 and not net2 then
        _add_device(net1, dev2)
        chat(player, "%s added to network %d (%d devices)", devstring(dev2), net1.id, table_len(net1.devices))
    elseif net2 and not net1 then
        _add_device(net2, dev1)
        chat(player, "%s added to network %d (%d devices)", devstring(dev1), net2.id, table_len(net2.devices))
    elseif net1 == net2 then
        DEBUG("devices already connected")
        chat(player, "%s and %s are already connected to network %d (%d devices)", devstring(dev1), devstring(dev2), net1.id, table_len(net1.devices))
    else
        _join_networks(net1, net2)
        chat(player, "Network %d merged to network %d (%d devices) (%s and %s)", net2.id, net1.id, table_len(net1.devices), devstring(dev1), devstring(dev2))
    end
    wc_start_spark_particles(dev1.pos, 5, player_name)
    wc_start_spark_particles(dev2.pos, 5, player_name)
    return true
end


-- wc_emit_signal
--
local function wc_emit_signal ( pos, signal, player )
    local dev, dev_node = _get_dev(pos)
    if not dev then
        ERROR("device not found at %s", pos2str(pos))
        return false
    end
    local net = dev.net
    if not net then
        INFO("this device is not connected")
        if player then
            minetest.chat_send_player(player:get_player_name(), "This device is not connected")
        end
        return false
    end
    local rmdevs = {}
    local dev_pos = dev.pos
    for target_id, target_dev in pairs(net.devices) do
        local target_node = _check_dev(target_dev)
        if target_node then
            local def = target_dev.def
            if def.on_receive_signal then
                def.on_receive_signal(target_dev.pos, target_node, dev_pos, dev_node, signal)
            end
        else
            WARNING("[TODO] invalid device")
            table.insert(rmdevs, target_dev)
        end
    end
    for _, dev in ipairs(rmdevs) do
        _cleanup_dev(dev)
    end
end


-- wc_activate_device
--
local function wc_activate_device ( pos, player, params )
    DEBUG("activate device: %s", pos2str(pos))
    local dev, node = _get_dev(pos)
    if not dev then
        ERROR("no device found at %s", pos2str(pos))
        return
    end
    local meta = minetest.get_meta(pos)
    local controller = meta:get_string("wcons:controller")
    if controller then
        DEBUG("controller: %s", controller)
        local condef = registered_controllers[controller]
        if not condef then
            ERROR("invalid controller: %s", controller)
            return
        end
        if condef.on_activate then
            condef.on_activate(dev, node, meta, player, params)
        end
    else
        DEBUG("no controller")
    end
    local devdef = dev.def
    if devdef.on_activate then
        devdef.on_activate(dev, node, meta, player, params)
    end
end


----------------------------------------------------------------------
--                           CONTROLLERS                            --
----------------------------------------------------------------------


-- wc_register_controller
--
local function wc_register_controller ( def )
    if registered_controllers[def.name] then
        ERROR("controller already registered: '%s'", def.name)
        return
    end
    def = table.copy(def)
    registered_controllers[def.name] = def
    DEBUG("controller registered: '%s'", def.name)
end


-- wc_set_device_controller
--
local function wc_set_device_controller ( pos, controller, player, params )
    local condef = registered_controllers[controller]
    if not condef then
        ERROR("unknown controller: '%s'", controller)
        return
    end
    local dev, node = _get_dev(pos)
    if not dev then
        ERROR("no device found at %s", pos2str(pos))
        return
    end
    local meta = minetest.get_meta(pos)
    meta:set_string("wcons:controller", controller)
    if condef.on_init then
        condef.on_init(dev, node, meta, player, params)
    end
end


----------------------------------------------------------------------

wcons.registered_devices = registered_devices
wcons.registered_device_nodes = registered_device_nodes
wcons.registered_controllers = registered_controllers
wcons.networks = networks
wcons.dev_map = dev_map

wcons.register_device = wc_register_device
wcons.connect_devices = wc_connect_devices
wcons.activate_device = wc_activate_device
wcons.emit_signal = wc_emit_signal
wcons.add_spark_particles = wc_add_spark_particles
wcons.show_network = wc_show_network

wcons.register_controller = wc_register_controller
wcons.set_device_controller = wc_set_device_controller

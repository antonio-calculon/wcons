
local SAVEPATH = wcons.SAVEPATH
local SAVE_TIMEOUT = wcons.SAVE_TIMEOUT
local NET_LIST = SAVEPATH .. "/networks"

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


-- I must be stupid but I didn't find a way to do that in lua :)
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

local invalid_networks = {}


local function wc_invalidate_network ( net_id )
    invalid_networks[net_id] = true
end


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


local function _cleanup_dev ( pos, no_invalidate )
    local hpos = hash_pos(pos)
    local dev = dev_map[hpos]
    if dev then
        local net = dev.net
        if net then
            net.devices[hpos] = nil
            if not no_invalidate then
                wc_invalidate_network(net.id)
            end
        end
        dev_map[hpos] = nil
    end
end


local function _check_dev ( dev )
    local node = minetest.get_node(dev.pos)
    -- we can't check if the node is not available
    if node.name ~= "ignore" then
        local def = registered_device_nodes[node.name]
        if def ~= dev.def then
            WARNING("[TODO] invalid device: %s", devstring(dev))
            return nil
        end
    end
    return node
end


local function _get_check_dev ( dev )
    local node = _check_dev(dev)
    if node then
        return dev, node
    else
        return nil, nil
    end
end


local function _get_make_dev ( pos, hpos )
    local node = minetest.get_node(pos)
    local def = registered_device_nodes[node.name]
    if not def then
        WARNING("[TODO] invalid node at %s", pos2str(pos))
        return nil, nil
    end
    local dev = {
        def = def,
        pos = table.copy(pos),
        hpos = hpos,
        net = nil,
    }
    return dev, node
end


local function _get_dev ( pos )
    local hpos = hash_pos(pos)
    local dev = dev_map[hpos]
    if dev then
        return _get_check_dev(dev)
    else
        return _get_make_dev(pos, hpos)
    end
end


----------------------------------------------------------------------


local function net_filename ( net_id )
    return "network_" .. net_id
end


local function _load_device ( iter )
    local l_pos = iter()
    if not l_pos then
        return nil
    end
    local l_def = iter()
    local pos = str2pos(l_pos)
    if not pos then
        ERROR("invalid pos: '%s'", l_pos)
        return false
    end
    local def = registered_devices[l_def]
    if not def then
        ERROR("unknown device: '%s'", l_def)
        return false
    end
    return {
        pos = pos,
        hpos = hash_pos(pos),
        def = def,
    }
end


local function _load_network ( net_id )
    local fname = SAVEPATH .. "/" .. net_filename(net_id)
    DEBUG("loading network %d (%s)", net_id, fname)
    local f = io.open(fname, "r")
    if not f then
        ERROR("file not found: '%s'", fname)
        return
    end
    local devices = {}
    local net = {
        id = net_id,
        devices = devices,
    }
    local iter = f:lines()
    local n_devs = 0
    while true do
        local dev = _load_device(iter)
        if dev == nil then
            break
        elseif type(dev) == "table" then
            dev.net = net
            n_devs = n_devs + 1
            devices[dev.hpos] = dev
        else
            ERROR("invalid device")
        end
    end
    f:close()
    if n_devs > 1 then
        for hpos, dev in pairs(devices) do
            dev_map[hpos] = dev
        end
        networks[net_id] = net
    else
        ERROR("empty network: %d", net_id)
        -- so it will get removed
        wc_invalidate_network(net_id)
    end
end


local function wc_load_datas ()
    DEBUG("loading datas")
    local f = io.open(NET_LIST, "r")
    if not f then
        DEBUG("networks list not found")
        return
    end
    -- hmm, looks like f:read() doesn't work !?
    local iter = f:lines()
    while true do
        local line = iter()
        if not line then
            break
        end
        local net_id = tonumber(line)
        if net_id then
            _load_network(net_id)
        else
            ERROR("invalid network id: '%s'", line)
        end
    end
    f:close()
end


local function _save_network ( net )
    local net_id = net.id
    local fname = SAVEPATH .. "/" .. net_filename(net_id)
    local tmpname = fname .. ".tmp"
    DEBUG("saving network %d in '%s'", net.id, fname)
    local f = io.open(tmpname, "w")
    if not f then
        ERROR("could not open '%s'", tmpname)
        return
    end
    local n_devs = 0
    local rmdevs = {}
    for hpos, dev in pairs(net.devices) do
        if _check_dev(dev) then
            f:write(pos2str(dev.pos), "\n", dev.def.name, "\n")
            n_devs = n_devs + 1
        else
            table.insert(rmdevs, dev.pos)
        end
    end
    f:close()
    for _, pos in ipairs(rmdevs) do
        _cleanup_dev(pos, true)
    end
    if n_devs > 1 then
        os.rename(tmpname, fname)
        return true
    else
        DEBUG("deleting network %d", net_id)
        -- grrr
        for hpos, dev in net.devices do
            dev_map[hpos] = nil
        end
        networks[net_id] = nil
        os.remove(tmpname)
        return false
    end
end


-- [FIXME] maybe useless ? we could just take all files in SAVEPATH
local function _save_networks_list ()
    local tmpname = NET_LIST .. ".tmp"
    local f = io.open(tmpname, "w")
    if not f then
        ERROR("could not open '%s'", tmpname)
        return
    end
    for net_id, net in pairs(networks) do
        f:write(net_id, "\n")
    end
    f:close()
    os.rename(tmpname, NET_LIST)
end


local function wc_save_datas ()
    local invalid = false
    local rmnets = {}
    for net_id,_ in pairs(invalid_networks) do
        local net = networks[net_id]
        invalid = true
        if net then
            DEBUG("saving network %d", net_id)
            _save_network(net)
        else
            DEBUG("removing network %d", net_id)
            table.insert(rmnets, net_id)
        end
    end
    for _, net_id in ipairs(rmnets) do
        os.remove(SAVEPATH .. "/" .. net_filename(net_id))
    end
    if invalid then
        _save_networks_list()
        invalid_networks = {}
    end
    minetest.after(SAVE_TIMEOUT, wc_save_datas)
end


----------------------------------------------------------------------


-- wc_add_spark_particles
--
local function wc_add_spark_particles ( pos, time, player_name )
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
        wc_add_spark_particles(dev.pos, 5, player_name)
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


local function _foreach_dev (net, func, ...)
    local invalidate = false
    for hpos, dev in pairs(net.devices) do
        local node = _check_dev(dev)
        if node then
            func(hpos, dev, node, ...)
        else
            WARNING("[TODO] invalid device")
            invalidate = true
        end
    end
    if invalidate then
        wc_invalidate_network(net.id)
    end
end


local function _emit_signal ( net, dev, node, signal, player )
    local dev_pos = dev.pos
    _foreach_dev(net, function(target_hpos, target_dev, target_node)
        if target_dev ~= dev then
            local def = target_dev.def
            if def.on_receive_signal then
                def.on_receive_signal(target_dev, target_node, dev, node, signal)
            end
            local target_meta = minetest.get_meta(target_dev.pos)
            local con_def = registered_controllers[target_meta:get_string("wcons:controller")]
            if con_def and con_def.on_receive_signal then
                con_def.on_receive_signal(target_dev, target_node, target_meta, dev, node, signal)
            end
        end
    end)
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
    local def = dev.def
    if def.on_emit_signal then
        def.on_emit_signal(dev, dev_node, signal)
    end
    _emit_signal(net, dev, dev_node, signal, player)
end


-- wc_emit_signal_device
-- [TODO] call on_emit_signal
--
local function wc_emit_signal_device ( pos, target_pos, signal, player )
    local dev, node = _get_dev(pos)
    if not dev then
        ERROR("invalid device: %s", pos2str(pos))
        return false
    end
    local net = dev.net
    if not net then
        DEBUG("device is not connected")
        return false
    end
    local target_dev, target_node = _get_dev(target_pos)
    if not target_dev then
        ERROR("invalid target device: %s", pos2str(target_pos))
        return false
    end
    if net ~= target_dev.net then
        ERROR("devices are not on same network")
        return false
    end
    local target_def = target_dev.def
    if target_def.on_receive_signal then
        target_def.on_receive_signal(target_dev, target_node, dev, dev_node, signal)
    end
    local target_meta = minetest.get_meta(target_pos)
    local con_def = registered_controllers[target_meta:get_string("wcons:controller")]
    if con_def and con_def.on_receive_signal then
        con_def.on_receive_signal(target_dev, target_node, target_meta, dev, dev_node, signal)
    end
end


local function _request_device_state ( net, dev, node )
    _emit_signal(net, dev, node, { type="wcons:request_state" })
end


-- wc_request_device_state
--
local function wc_request_device_state ( pos )
    local dev, dev_node = _get_dev(pos)
    if not dev then
        ERROR("device not found at %s", pos2str(pos))
        return false
    end
    local net = dev.net
    if not net then
        INFO("this device is not connected")
        return false
    end
    _request_device_state(net, dev, dev_node)
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


local function wc_update_device ( pos )
    DEBUG("activate device: %s", pos2str(pos))
    local dev, node = _get_dev(pos)
    if not dev then
        ERROR("no device found at %s", pos2str(pos))
        return
    end
    local def = dev.def
    if def.on_update then
        def.on_update(dev, node)
    end
    local meta = minetest.get_meta(pos)
    local condef = registered_controllers[meta:get_string("wcons:controller")]
    if condef then
        if condef.on_update then
            condef.on_update(dev, node, meta)
        end
    end
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
    _request_device_state(net, dev1)
    _request_device_state(net, dev2)
    wc_invalidate_network(net_id)
    return net
end


local function _add_device ( net, dev )
    local hpos = dev.hpos
    DEBUG("adding dev %s to network %d", devstring(dev), net.id)
    net.devices[hpos] = dev
    dev.net = net
    dev_map[hpos] = dev
    _request_device_state(net, dev)
    wc_invalidate_network(net.id)
end


local function _join_networks ( net1, net2 )
    DEBUG("joining networks %d and %d", net1.id, net2.id)
    local devices = net1.devices
    for hpos, dev in pairs(net2.devices) do
        dev.net = net1
        devices[hpos] = dev
        dev_map[hpos] = dev -- should be useless ??
        _request_device_state(net1, dev)
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
        net1 = _create_network(dev1, dev2)
        chat(player, "Network %d created (%s and %s)", net1.id, devstring(dev1), devstring(dev2))
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
    wc_add_spark_particles(dev1.pos, 2, player_name)
    wc_add_spark_particles(dev2.pos, 2, player_name)
    return true
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
    if not def.description then
        def.description = def.name
    end
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
    local net = dev.net
    if net then
        _request_device_state(net, dev, node)
    end
end


-- wc_get_controller_formspec
--
local function wc_get_controller_formspec ( controller, pos )
    local def = registered_controllers[controller]
    if not def then
        ERROR("unknown controller: '%s'", controller)
        return ""
    end
    if def.on_get_formspec then
        return def.on_get_formspec(pos)
    else
        return "label[0,0;(no config options)]"
    end
end


local function wc_send_controller_fields ( controller, pos, fields )
    -- DEBUG("controller fields: %s", dump(fields))
    local def = registered_controllers[controller]
    if not def then
        ERROR("unknown controller: '%s'", controller)
        return ""
    end
    if def.on_receive_fields then
        def.on_receive_fields(pos, fields)
    end
end


----------------------------------------------------------------------

wcons.registered_devices = registered_devices
wcons.registered_device_nodes = registered_device_nodes
wcons.registered_controllers = registered_controllers
wcons.networks = networks
wcons.dev_map = dev_map

wcons.load_datas = wc_load_datas
wcons.save_datas = wc_save_datas
wcons.register_device = wc_register_device
wcons.connect_devices = wc_connect_devices
wcons.activate_device = wc_activate_device
wcons.update_device = wc_update_device
wcons.emit_signal = wc_emit_signal
wcons.emit_signal_device = wc_emit_signal_device
wcons.add_spark_particles = wc_add_spark_particles
wcons.show_network = wc_show_network

wcons.register_controller = wc_register_controller
wcons.set_device_controller = wc_set_device_controller
wcons.get_controller_formspec = wc_get_controller_formspec
wcons.send_controller_fields = wc_send_controller_fields

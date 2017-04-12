
local META = minetest.get_mod_storage()

local N_CHANNELS = 8
local CHANNEL_ITEM = {}
local ITEM_CHANNEL = {}

local hash_pos = minetest.hash_node_position
local unhash_pos = minetest.get_position_from_hash
local pos2str = minetest.pos_to_string
local str2pos = minetest.string_to_pos

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


local function _get_current_channel ( meta )
    local chan = meta:get_int("current_channel")
    if chan < 1 then chan = 1
    elseif chan > N_CHANNELS then chan = N_CHANNELS end
    return chan
end


local function on_use ( stack, user, pointed )
    local meta = stack:get_meta()
    local chan = _get_current_channel(meta, false)
    -- [FIXME] would be better to take control_bits, but the &
    -- operator doesn't seem to work here
    local controls = user:get_player_control()
    if controls.sneak then
        chan = chan + 1
        if chan > N_CHANNELS then chan = 1 end
        DEBUG("channel: %d", chan)
        local new_stack = ItemStack(CHANNEL_ITEM[chan])
        local new_meta = new_stack:get_meta()
        local meta_list = meta:to_table()
        meta_list.fields.current_channel = chan
        -- DEBUG("meta_list: %s", dump(meta_list))
        new_meta:from_table(meta_list)
        return new_stack
    else
        local dev_spos = meta:get_string("dev_pos_" .. chan)
        if dev_spos == "" then
            DEBUG("channel not set")
            return stack
        end
        local dev_pos = str2pos(dev_spos)
        local dev_name = meta:get_string("dev_name_" .. chan)
        DEBUG("chan %d: %s (%s)", chan, dev_name, pos2str(dev_pos))
        local node = minetest.get_node(dev_pos)
        if node.name == "ignore" then -- ?? maybe not necessary
            minetest.chat_send_player(user:get_player_name(), "The device is too far")
            return stack
        end
        local def = wcons.registered_device_nodes[node.name]
        if (not def) or def.name ~= dev_name then
            DEBUG("device is not here anymore")
            meta:set_string("dev_pos_" .. chan, "")
            meta:set_string("dev_name_" .. chan, "")
            return stack
        else
            wcons.activate_device(dev_pos, user, nil)
        end
    end
    return stack
end


local function on_secondary_use ( stack, user, pointed )
    local user_name = user:get_player_name()
    if pointed.type ~= "node" then
        return
    end
    local under_pos = pointed.under
    local under = minetest.get_node(under_pos)
    local node_def = wcons.registered_device_nodes[under.name]
    if not node_def then
        minetest.chat_send_player(user_name, "This is not a connectable item")    
        return stack
    end
    local meta = stack:get_meta()
    local chan = _get_current_channel(meta)
    DEBUG("Remote channel used on %s (channel %d)", under.name, chan)
    -- [FIXME] looks like meta can't handle hashed pos
    meta:set_string("dev_pos_" .. chan, pos2str(under_pos))
    meta:set_string("dev_name_" .. chan, node_def.name)
    minetest.chat_send_player(user_name, "Channel " .. chan .. " set to " .. node_def.name .. " at " .. minetest.pos_to_string(pointed.under))
    return stack
end


----------------------------------------------------------------------


for chan = 1, N_CHANNELS do
    local x = 6 + ((chan-1) % 2) * 2
    local y = 5 + math.floor((chan-1)/2) * 2
    local texture = "[combine:16x16:0,0=wcons_remote_inv.png:" .. x .. "," .. y .. "=wcons_remote_button.png"
    local name = "wcons:remote_" .. chan
    minetest.register_tool(name, {
        description = "Remote controller",
        inventory_image = texture,
        on_use = on_use,
        on_secondary_use = on_secondary_use,
        on_place = on_secondary_use,
    })
    CHANNEL_ITEM[chan] = name
    ITEM_CHANNEL[name] = chan
end

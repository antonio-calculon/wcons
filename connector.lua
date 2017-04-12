
local WIRE_ITEM = nil
local WIRE_COST = 0.1

if minetest.get_modpath("homedecor") then
    WIRE_ITEM = "homedecor:copper_wire"
end

local WIRE_ITEM_NAME = minetest.registered_items[WIRE_ITEM].description


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


-- manhattan distance
local function man_dist ( p1, p2 )
    return math.abs(p1.x - p2.x) + math.abs(p1.y - p2.y) + math.abs(p1.z - p2.z)
end


local function get_cost ( pos1, pos2, player, meta )
    local dist = man_dist(pos1, pos2)
    local cost = dist * WIRE_COST
    local residue = meta:get_float("residue")
    local cost_int = math.ceil(cost - residue)
    if cost_int < 0 then cost_int = 0 end -- should not happen ?
    local cost_stack = ItemStack(WIRE_ITEM .. " " .. cost_int)
    new_residue = cost_int - cost + residue
    DEBUG("dist: %d, cost: %.2f (%d), residue: %.2f -> %.2f", dist, cost, cost_int, residue, new_residue)
    return cost_stack, new_residue
end            


local function on_connector_use ( stack, user, pointed )
    local user_name = user:get_player_name()
    if pointed.type ~= "node" then
        return stack
    end
    local pos = pointed.under
    local under = minetest.get_node(pos)
    -- [TODO] check protection
    DEBUG("connector use: %s", under.name)
    local meta = stack:get_meta()
    local first_item = meta:get_string("first_item")
    local def = wcons.registered_device_nodes[under.name]
    if not def then
        if first_item == "" then
            minetest.chat_send_player(user_name, "This is not a connectable device")
            return stack
        else
            minetest.chat_send_player(user_name, "This is not a connectable device (operation cancelled)")
            meta:set_string("first_item", "")
            return stack
        end
    end
    if first_item == "" then
        DEBUG("no first item")
        meta:set_string("first_item", minetest.pos_to_string(pointed.under))
        minetest.chat_send_player(user_name, "Right click on second device to connect")
    else
        local first_pos = minetest.string_to_pos(first_item)
        if first_pos.x == pos.x and first_pos.y == pos.y and first_pos.z == pos.z then
            wcons.show_network(pos, user)
        else
            local first_node = minetest.get_node(first_pos)
            -- [FIXME] add some checks about first_node here ?
            local cost, residue = get_cost(first_pos, pointed.under, user, meta)
            local inv = user:get_inventory()
            if not inv:contains_item("main", cost) then
                minetest.chat_send_player(user_name, "You don't have enough wire (" .. WIRE_ITEM_NAME .. " x " .. cost:get_count() .. " needed)")
                return stack
            end
            if wcons.connect_devices(first_pos, pointed.under, user) then
                inv:remove_item("main", cost)
                meta:set_float("residue", residue)
                minetest.chat_send_player(user_name, "Devices connected! (" .. cost:get_count() .. " wire items used)")
            else
                minetest.chat_send_player(user_name, "The devices could not be connected!")
            end
        end
        meta:set_string("first_item", "")
    end
    return stack
end


----------------------------------------------------------------------

minetest.register_tool("wcons:connector", {
    description = "Connector",
    inventory_image = "wcons_connector_inv.png",
    on_secondary_use = on_connector_use,
    on_place = on_connector_use,
})

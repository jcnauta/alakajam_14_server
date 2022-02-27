
local world_control = {}
local level_mgr = require("level_manager")
local hog_mgr = require("hog_manager")
local util = require("util")

local nk = require("nakama")

local SPAWN_POSITIONS = {{x = 5.5 * 50, y = 17 * 50}, {x = 12.5 * 50, y = 17 * 50}}


-- This is a two-player game, each player is assigned to one of these.
local presence_uid1 = nil
local presence_uid2 = nil
local player_idx = -1  -- set to 1 or 2

local OpCodes = {
    initial_state = 1,
    do_spawn = 2,
    update_state = 3,
    update_position = 4,
    update_rotation = 5,
    eat_shroom = 6,  -- only client -> server
    spawn_shroom = 7,  -- only client -> server
    update_shrooms = 8,  -- only server -> clients
    update_modes = 9,  -- only server -> clients
    declare_winner = 10  -- only server -> clients
}

local commands = {}

commands[OpCodes.update_position] = function(data, state)
    local id = data.id
    local position = data.pos
    if state.positions[id] ~= nil then
        state.positions[id] = position
    end
end

commands[OpCodes.update_rotation] = function(data, state)
    local id = data.id
    local rotation = data.pos
    if state.rotations[id] ~= nil then
        state.rotations[id] = rotation
    end
end

commands[OpCodes.eat_shroom] = function(data, state)
    local eater = data.eater
    local coord = util.coord_0_to_1(data.coord)
    local sh_type = data.sh_type
    local success = level_mgr.eat_shroom(coord, sh_type)
    if success then
        level_mgr.spawn_shroom()
        hog_mgr.hog_eats_shroom(eater, sh_type)
        state.shrooms = level_mgr.get_shrooms()
    end
end

function world_control.match_init(context, params)
    local blocks = level_mgr.generate_grid()
    local state = {
        presences = {},
        positions = {},
        rotations = {},
        names = {},
        -- Dict of Dict of user_id to CellTypes to integers and a key "total" for total eaten.
        shrooms_eaten = {},
        blocks = blocks,  -- 2D array of CellTypes (integers)
        shrooms = level_mgr.get_shrooms()  -- Array of {x: ..., y: ..., sh_type: ...} dictionaries
    }
    local tick_rate = 5
    local label = "Game world"

    return state, tick_rate, label
end

function world_control.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
    if state.presences[presence.user_id] ~= nil then
        return state, false, "User " + presence.user_id + " already logged in."
    end
    return state, true
end

function world_control.match_join(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        if presence_uid1 == nil then
            presence_uid1 = presence.user_id
        elseif presence_uid2 == nil then
            presence_uid2 = presence.user_id
        else
            print("Actually too many players, only two should join...")
        end
        hog_mgr.add_hog(presence.user_id)
        state.presences[presence.user_id] = presence
        if presence_uid1 == presence.user_id then
            player_idx = 1
        elseif presence_uid2 == presence.user_id then
            player_idx = 2
        end
        state.positions[presence.user_id] = {
            ["x"] = SPAWN_POSITIONS[player_idx].x,
            ["y"] = SPAWN_POSITIONS[player_idx].y
        }
        state.names[presence.user_id] = "Lua User"
        -- state.shrooms_eaten[presence.user_id] = {total = 0}
    end
    return state
end

function world_control.match_leave(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = nil
        state.positions[presence.user_id] = nil
    end
    return state
end

function world_control.match_loop(context, dispatcher, tick, state, messages)
    for _, message in ipairs(messages) do
        local op_code = message.op_code
        local decoded = nk.json_decode(message.data)
        local command = commands[op_code]
        if command ~= nil then
            commands[op_code](decoded, state)
        end
        if op_code == OpCodes.do_spawn then
            local object_ids = {
                {
                    collection = "player_data",
                    key = "position_" .. decoded.nm,
                    user_id = message.sender.user_id
                }
            }
            local objects = nk.storage_read(object_ids)
            local position
            for _, object in ipairs(objects) do
                position = object.value
                if position ~= nil then
                    state.positions[message.sender.user_id] = position
                    break
                end
            end
            if position == nil then
                state.positions[message.sender.user_id] = {
                    ["x"] = SPAWN_POSITIONS[player_idx].x,
                    ["y"] = SPAWN_POSITIONS[player_idx].y
                }
            end
            -- TODO?: do the storage_read thing like for position above?
            local rotation
            if rotation == nil then
                state.rotations[message.sender.user_id] = 0
            end
            state.names[message.sender.user_id] = decoded.nm

            local data = {
                ["pos"] = state.positions,
                ["rot"] = state.rotations,
                ["nms"] = state.names,
                ["blocks"] = state.blocks
            }

            local encoded = nk.json_encode(data)
            print("Broadcasting initial state and spawning message!")
            dispatcher.broadcast_message(OpCodes.initial_state, encoded, {message.sender})
            dispatcher.broadcast_message(OpCodes.do_spawn, message.data)
        elseif op_code == OpCodes.eat_shroom then
            -- Shroom eating was processed in command, now broadcast changes
            local data = {
                ["shrooms"] = level_mgr.get_shrooms(),
                ["shrooms_eaten"] = hog_mgr.get_shrooms_eaten(),
            }
            dispatcher.broadcast_message(OpCodes.update_shrooms, nk.json_encode(data))
            -- Hogs may change mode when eating
            local data2 = {
                ["hog_modes"] = hog_mgr.get_modes()
            }
            dispatcher.broadcast_message(OpCodes.update_modes, nk.json_encode(data2))
            -- If 20 shrooms were eaten by either player, that player wins
            local winner = hog_mgr.first_to(2)
            if winner ~= nil then
                local data3 = {
                    ["winner"] = winner
                }
                dispatcher.broadcast_message(OpCodes.declare_winner, nk.json_encode(data3))
            end
        end
    end                                         
    local data = {
        ["pos"] = state.positions,
        ["rot"] = state.rotations
    }
    local encoded = nk.json_encode(data)

    dispatcher.broadcast_message(OpCodes.update_state, encoded)
    return state
end

function world_control.match_terminate(context, dispatcher, tick, state, grace_seconds)
    return state
end

function world_control.match_signal(context, dispatcher, tick, state, data)
    return state, data
end

return world_control
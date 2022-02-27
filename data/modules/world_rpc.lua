
local nakama = require("nakama")

local function get_world_id(_, _)
    local matches = nakama.match_list()
    local current_match = matches[1]
    if current_match == nil then
        print("Current match:", current_match)
        local result = nakama.match_create("world_control", {})
        print("Match created with ID: ", result)
        return result
    else
        print("Got existing match with ID: ", current_match.match_id)
        return current_match.match_id
    end
end

nakama.register_rpc(get_world_id, "get_world_id")
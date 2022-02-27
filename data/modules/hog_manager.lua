local hog_mgr = {}

local hogs = {}

local CellTypes = require("cell_types")
local HogModes = require("hog_modes")

hog_mgr.add_hog = function(id, position)
    local shrooms_eaten = {
        [CellTypes.SH_WALK] = 0,
        [CellTypes.SH_SHIP] = 0,
        [CellTypes.BLOCK] = 0  -- Use this as total, I hate Lua.
    }
    hogs[id] = {
        id = id,
        position = position,
        shrooms_eaten = shrooms_eaten,
        mode = HogModes.SH_WALK
    }
end

hog_mgr.remove_hog = function(id)
    hogs[id] = nil
end

hog_mgr.hog_eats_shroom = function(id, sh_type)
    hogs[id].shrooms_eaten[sh_type] = hogs[id].shrooms_eaten[sh_type] + 1
    hogs[id].shrooms_eaten[CellTypes.BLOCK] = hogs[id].shrooms_eaten[CellTypes.BLOCK] + 1
    if sh_type == CellTypes.SH_SHIP then
        hogs[id].mode = HogModes.SH_SHIP
    elseif sh_type == CellTypes.SH_WALK then
        hogs[id].mode = HogModes.SH_WALK
    end
end

hog_mgr.get_shrooms_eaten = function()
    local shrooms_eaten = {}
    for id, hog in pairs(hogs) do
        shrooms_eaten[id] = hog.shrooms_eaten
    end
    return shrooms_eaten
end

hog_mgr.get_modes = function()
    local modes = {}
    for id, hog in pairs(hogs) do
        modes[id] = hog.mode
    end
    return modes
end

hog_mgr.first_to = function(n)
    for k,v in pairs(hogs) do
        if v.shrooms_eaten[CellTypes.BLOCK] >= n then
            return k
        end
    end
    return nil
end

return hog_mgr
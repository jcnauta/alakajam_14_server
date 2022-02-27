local util = require("util")

local level_mgr = {}

local CellTypes = require("cell_types")

local grid_size = 18
local grid = {}
for row = 1,grid_size do
    grid[row] = {}
    for col = 1,grid_size do
        grid[row][col] = CellTypes.EMPTY
    end
end

local shrooms = {}  -- Dictionary of {x:..., y:..., sh_type:...}

-- Create some guaranteed empty space in the level
local blacklist = {}
local limit_1 = 4
local limit_2 = 7
for c = limit_1,limit_2 do
    for r = grid_size - 4, grid_size do
        table.insert(blacklist, {x = c, y = r})
    end
end
for c = grid_size - limit_2, grid_size - limit_1 do
    for r = grid_size - 4, grid_size do
        table.insert(blacklist, {x = c, y = r})
    end
end
for _, coord in ipairs(blacklist) do
    grid[coord.y][coord.x] = CellTypes.STAY_EMPTY
end

level_mgr.generate_grid = function()
    -- math.randomseed(os.time())
    
    -- Generate blocks
    for row = 2, grid_size - 1, 3 do
        local n_platforms = 1 + math.random(0, 2)  -- possibly more platforms
        for idx = 1, n_platforms do
            local platblocks = {} -- We may have multiple blocks in a platform
            -- Find free block
            local found = false
            local tries = 0
            while (not found) and (tries < 20) do
                tries = tries + 1
                local coord = {x = 2 + math.random(0, 15), y = row}
                if grid[coord.y][coord.x] == CellTypes.EMPTY then
                    found = true
                    table.insert(platblocks, coord)
                    -- Possibly extend to left and right
                    if (grid[row][coord.x - 1] == CellTypes.EMPTY) then
                        table.insert(platblocks, {x = coord.x - 1, y = coord.y})
                    end
                    if (grid[row][coord.x + 1] == CellTypes.EMPTY) then
                        table.insert(platblocks, {x = coord.x + 1, y = coord.y})
                    end
                    for _, platblock_coord in ipairs(platblocks) do
                        grid[platblock_coord.y][platblock_coord.x] = CellTypes.BLOCK
                        -- local block = BlockScene.instance()
                        -- block.position = platblock_coord * block_size
                        -- add_child(block)
                    end
                end
            end
        end
    end
    -- Generate shrooms
    for idx = 1,5 do
        level_mgr.spawn_shroom()
    end
    return grid
end

level_mgr.spawn_shroom = function()
    local spawned = false
    local tries = 0
    -- Generate a random shroom type with equal probability
    local sh_type = math.random(0, 1)
    if sh_type == 0 then
        sh_type = CellTypes.SH_WALK
    elseif sh_type == 1 then
        sh_type = CellTypes.SH_SHIP
    end
    -- Try to spawn the shroom
    while not spawned and tries < 100 do
        tries = tries + 1
        local coord = {x = math.random(2, 17), y = math.random(2, 17)}
        if grid[coord.y][coord.x] == CellTypes.EMPTY then
            grid[coord.y][coord.x] = sh_type
            table.insert(shrooms, {x = coord.x, y = coord.y, sh_type = sh_type})
            spawned = true
        end
    end
end

level_mgr.get_shrooms = function()
    local numb = util.tablelen(shrooms)
    return shrooms
end

local remove_shroom = function(coord)
    local remove_idx = -1
    for idx, sh in ipairs(shrooms) do
        if sh.x == coord.x and sh.y == coord.y then
            grid[coord.y][coord.x] = CellTypes.EMPTY
            remove_idx = idx
            break
        end
    end
    if remove_idx == -1 then
        print("Error: could not find shroom to remove!")
        return
    end
    table.remove(shrooms, remove_idx)
end

level_mgr.eat_shroom = function(coord, sh_type)
    if grid[coord.y][coord.x] == sh_type then
        grid[coord.y][coord.x] = CellTypes.EMPTY
        remove_shroom(coord)
        return true
    end
    return false
end

return level_mgr
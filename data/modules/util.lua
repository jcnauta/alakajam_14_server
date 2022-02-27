local util = {}

util.tablefind = function(tab,el)
    for index, value in ipairs(tab) do
        if value == el then
            return index
        end
    end
    return nil
end

util.tablelen = function(tab)
    local total = 0
    for _, _ in pairs(tab) do
        total = total + 1
    end
    return total
end

util.coord_0_to_1 = function(coord)
    return {x = coord.x + 1, y = coord.y + 1}
end

util.coord_1_to_0 = function(coord)
    return {x = coord.x - 1, y = coord.y - 1}
end

return util
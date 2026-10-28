-- Pure policy, shared by the compositor callbacks and their tests.
local M = {}

function M.logical(id)
    return ((math.max(1, tonumber(id) or 1) - 1) % 10) % 9 + 1
end

function M.workspace(base, number)
    return base + ((number - 1) % 9) + 1
end

function M.connected(monitors)
    local names = {}
    for _, monitor in ipairs(monitors) do
        names[monitor.name] = true
    end
    return names
end

function M.primary(monitors, active)
    local names = M.connected(monitors)
    if names["DP-4"] then return "DP-4" end
    if names["eDP-1"] then return "eDP-1" end
    if names[active] then return active end
    return monitors[1] and monitors[1].name
end

function M.assign_bases(bases, monitors)
    bases["DP-4"], bases["eDP-1"] = 0, 10
    local used = {}
    for _, base in pairs(bases) do used[base] = true end
    for _, monitor in ipairs(monitors) do
        if not bases[monitor.name] then
            local base = 20
            while used[base] do base = base + 10 end
            bases[monitor.name], used[base] = base, true
        end
    end
end

function M.owner(bases, id)
    for name, base in pairs(bases) do
        if id > base and id <= base + 9 then return name end
    end
end

function M.destination(bases, monitors, id, fallback)
    local names = M.connected(monitors)
    local owner = M.owner(bases, id)
    if owner and names[owner] then return id end
    return M.workspace(bases[fallback], M.logical(id))
end

-- Dwindle's leaf chain always consumes left, then top, repeatedly.
function M.split_direction(index)
    return index % 2 == 0 and "right" or "down"
end

-- The rebuild's Dwindle result is a chain: window i+1 splits the region of
-- window i, so each window sits directly across the previous split and every
-- later window still lives inside the region that split created. Removing a
-- window lets its sibling subtree inherit the parent box, which re-lays the
-- subtree out and can break that chain while keeping the reading order.
-- Verify the rectangles still form the chain; split ratios are free.
function M.canonical_chain(windows)
    local delta
    for index = 1, #windows - 1 do
        local head, tail = windows[index], windows[index + 1]
        local horizontal = M.split_direction(index + 1) == "right"
        local d, p = horizontal and "x" or "y", horizontal and "y" or "x"
        -- The next window starts across the split; the gap is uniform.
        local gap = tail.at[d] - head.at[d] - head.size[d]
        if gap < -1 or (delta and math.abs(gap - delta) > 2) then return false end
        delta = delta or gap
        -- The later windows together span the head's extent across the split.
        local near, far = tail.at[p], tail.at[p] + tail.size[p]
        for i = index + 2, #windows do
            near = math.min(near, windows[i].at[p])
            far = math.max(far, windows[i].at[p] + windows[i].size[p])
        end
        if math.abs(near - head.at[p]) > 2 or math.abs(far - head.at[p] - head.size[p]) > 2 then
            return false
        end
    end
    return true
end

function M.visual_order(windows)
    table.sort(windows, function(a, b)
        if a.at.x ~= b.at.x then return a.at.x < b.at.x end
        if a.at.y ~= b.at.y then return a.at.y < b.at.y end
        return a.stable_id < b.stable_id
    end)
    return windows
end

-- Awesome fair is column-major and expands the final, incomplete column.
function M.fair_cell(index, count, area)
    local columns = math.ceil(math.sqrt(count))
    local rows = math.ceil(count / columns)
    columns = math.ceil(count / rows)
    local column = math.floor((index - 1) / rows)
    local row = (index - 1) % rows
    local column_rows = math.min(rows, count - column * rows)
    return {
        x = area.x + column * area.w / columns,
        y = area.y + row * area.h / column_rows,
        w = area.w / columns, h = area.h / column_rows,
    }
end

return M

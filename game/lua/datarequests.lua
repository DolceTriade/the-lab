local cjson = require('cjson')
local mode = require('lua/mode.lua')
local difficulty = require('lua/difficulty.lua')

local M = {}
local MAP_PAGE_SIZE = 12

local function safeMap(value)
    return type(value) == 'string' and value:match('^[%w_%-]+$') ~= nil
end

local function safeCursor(value)
    local n = tonumber(value)
    if not n or n < 0 or n % 1 ~= 0 then return 0 end
    return math.min(n, 1000000)
end

local function mapNames()
    local out = {}
    for _, name in ipairs(sgame.GetAvailableMaps()) do
        if safeMap(name) then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

local function layoutNames(map, team)
    local out = { 'builtin' }
    local seen = { builtin = true }
    if not safeMap(map) or (team ~= 'human' and team ~= 'alien') then return out end
    local prefix = team .. '-'
    for _, file in ipairs(File.list('layouts/' .. map, '.dat')) do
        local name = file:gsub('%.dat$', '')
        if safeMap(name) and name ~= 'builtin' and name:sub(1, #prefix) == prefix and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out, function(a, b)
        if a == 'builtin' then return true end
        if b == 'builtin' then return false end
        return a < b
    end)
    return out
end

local function modeName(path)
    if not path or path == '' then return 'Classic' end
    if path == 'lua/pve.lua' then return 'PVE' end
    if path == 'lua/raid.lua' then return 'Raid' end
    if path == 'towerdefense/game.lua' then return 'Tower Defense' end
    return path
end

sgame.RegisterDataEndpoint('menu_state', function(client, params)
    local map = Cvar.get('mapname') or ''
    local selectedDifficulty = difficulty.DifficultyString(difficulty.GetDifficulty()) or 'medium'
    return {
        map = map,
        mode = modeName(mode.Mode()),
        team = mode.Team() or '',
        difficulty = selectedDifficulty,
    }
end)

sgame.RegisterDataEndpoint('maps', function(client, params)
    local query = string.lower(type(params.query) == 'string' and params.query or '')
    local matches = {}
    for _, name in ipairs(mapNames()) do
        if query == '' or name:lower():find(query, 1, true) then
            matches[#matches + 1] = name
        end
    end
    local offset = safeCursor(params.cursor)
    local items = {}
    for i = offset + 1, math.min(offset + MAP_PAGE_SIZE, #matches) do
        items[#items + 1] = { name = matches[i] }
    end
    local nextOffset = offset + #items
    return { items = items, nextCursor = nextOffset < #matches and tostring(nextOffset) or nil }
end)

sgame.RegisterDataEndpoint('layouts', function(client, params)
    local map = params.map or Cvar.get('mapname')
    if not safeMap(map) then return { layouts = { 'builtin' } } end
    return { layouts = layoutNames(map, params.team) }
end)

sgame.RegisterDataEndpoint('highscores', function(client, params)
    local map = params.map
    if not safeMap(map) then return { items = {}, nextCursor = nil } end
    local ok, contents = pcall(File.read, 'highscores/' .. map .. '.json')
    if not ok then return { items = {}, nextCursor = nil } end
    local decoded, data = pcall(cjson.decode, contents)
    if not decoded or type(data) ~= 'table' then return { items = {}, nextCursor = nil } end

    local rows = {}
    local recordId = 0
    local function keys(t)
        local result = {}
        for key in pairs(t) do result[#result + 1] = key end
        table.sort(result)
        return result
    end
    for _, modeKey in ipairs(keys(data)) do
        local difficulties = data[modeKey]
        if type(difficulties) == 'table' then
            for _, difficultyKey in ipairs(keys(difficulties)) do
                local teams = difficulties[difficultyKey]
                if type(teams) == 'table' then
                    for _, teamKey in ipairs(keys(teams)) do
                        local layouts = teams[teamKey]
                        if type(layouts) == 'table' then
                            for _, layoutKey in ipairs(keys(layouts)) do
                                local results = layouts[layoutKey]
                                if type(results) == 'table' then
                                    for rank, entry in ipairs(results) do
                                        if type(entry) == 'table' and tonumber(entry.highscore) then
                                            recordId = recordId + 1
                                            local record = {
                                                recordId = recordId,
                                                mode = modeName(modeKey):sub(1, 24),
                                                difficulty = tostring(difficultyKey):sub(1, 12),
                                                team = tostring(teamKey):sub(1, 12),
                                                layout = tostring(layoutKey):sub(1, 24),
                                                rank = rank,
                                                score = tostring(entry.prettyHighscore or entry.highscore):gsub('[%z\1-\31"\\]', ''):sub(1, 32),
                                                date = type(entry.achievedAt) == 'number' and os.date('!%Y-%m-%d', entry.achievedAt) or '',
                                            }
                                            local count = 0
                                            for _, player in ipairs(entry.players or {}) do
                                                if type(player) == 'table' and type(player.name) == 'string' then
                                                    local row = {}
                                                    for key, value in pairs(record) do row[key] = value end
                                                    row.player = player.name:gsub('[%z\1-\31"\\]', ''):sub(1, 40)
                                                    rows[#rows + 1] = row
                                                    count = count + 1
                                                end
                                            end
                                            if count == 0 then
                                                record.player = 'No players'
                                                rows[#rows + 1] = record
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return { items = rows }
end)

return M

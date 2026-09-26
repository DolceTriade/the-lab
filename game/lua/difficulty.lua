local lib = require('lua/lib.lua')

local M = {}

local DIFFICULTY_CVAR = 'lua_difficulty'

M.EASY = 1
M.MEDIUM = 2
M.HARD = 3

local difficultyToString = {
    ["easy"] = M.EASY,
    ["medium"] = M.MEDIUM,
    ["hard"] = M.HARD,
}

local difficulty = difficultyToString[Cvar.get(DIFFICULTY_CVAR)]
Cvar.set(DIFFICULTY_CVAR, '')

function M.SetDifficulty(value)
    if type(value) ~= 'number' or value < M.EASY or value > M.HARD then
        return false
    end
    difficulty = value
    Cvar.set(DIFFICULTY_CVAR, M.DifficultyString(value))
    return true
end

function M.GetDifficulty()
    return difficulty
end

function M.ParseDifficulty(difficulty)
    return difficultyToString[difficulty]
end

function M.DifficultyString(difficulty)
    for k, v in pairs(difficultyToString) do
        if v == difficulty then
            return k
        end
    end

    return nil
end


function M.GuessDifficulty()
    local num_players = sgame.level.num_connected_players
    local total_admin_level = 0
    for ent in lib.AllPlayers() do
        if ent ~= nil and ent.client ~= nil then
            total_admin_level = total_admin_level + ent.client.admin_level
        end
    end

    local guessed = M.MEDIUM
    if total_admin_level > 8 then
        guessed = M.HARD
    elseif total_admin_level > 4 then
        guessed = M.MEDIUM
    elseif num_players < 3 then
        guessed = M.EASY
    end
    M.SetDifficulty(guessed)
    return guessed
end

return M

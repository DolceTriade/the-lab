local M = {}

local MODE_CVAR = "lua_gamemode"
local TEAM_CVAR = "lua_team"

local mode = Cvar.get(MODE_CVAR)
local team = Cvar.get(TEAM_CVAR)

-- These values are a one-shot handoff from the mode selector to init.lua.
Cvar.set(MODE_CVAR, '')
Cvar.set(TEAM_CVAR, '')

-- Get current mode.
function M.Mode()
    return mode
end

function M.Team()
    return team
end

-- Set mode for the next map.
function M.SetMode(m, t)
    Cvar.set(MODE_CVAR, m)
    Cvar.set(TEAM_CVAR, t or '')
end

return M

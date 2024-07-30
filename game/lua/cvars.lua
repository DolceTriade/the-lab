local cvars = {}

local boolCvars = {
    ["on"] = true,
    ["yes"] = true,
    ["true"] = true,
    ["enable"] = true,
    ["1"] = true,
    ["off"] = false,
    ["no"] = false,
    ["false"] = false,
    ["disable"] = false,
    ["0"] = false,
}

cvars.CLEANUP = {}

function cleanup__gc()
    local cmd = ''
    for k, v in pairs(cvars.CLEANUP) do
        cmd = cmd .. 'set ' .. k .. ' "' .. v .. '"\n'
    end
    print(cmd)
    Cmd.exec(cmd)
end

setmetatable(cvars.CLEANUP, {__gc = cleanup__gc})

function cvars.set(cvar, val)
    if cvars.CLEANUP[cvar] == nil then
        cvars.CLEANUP[cvar] = Cvar.get(cvar)
    end
    Cvar.set(cvar, val)
end

function cvars.parseBool(b)
    return boolCvars[b]
end

function cvars.addCleanup(cvar)
    if cvars.CLEANUP[cvar] == nil then
        cvars.CLEANUP[cvar] = Cvar.get(cvar)
    end
end

return cvars

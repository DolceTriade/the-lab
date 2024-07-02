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
    print("GC'ing!!")
    local cmd = ''
    for k, _ in pairs(cvars.CLEANUP) do
        cmd = cmd .. 'reset ' .. k .. '\n'
    end

    Cmd.exec(cmd)
end

setmetatable(cvars.CLEANUP, {__gc = cleanup__gc})

function cvars:set(cvar, val)
    self.CLEANUP[cvar] = true
    Cvar.set(cvar, val)
end

function cvars:parseBool(b)
    return boolCvars[b]
end

function cvars:addCleanup(cvar)
    self.CLEANUP[cvar] = true
end

return cvars

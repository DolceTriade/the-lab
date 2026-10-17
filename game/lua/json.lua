local M = {}

local function jsonEscape(value)
    return (tostring(value):gsub('[%z\1-\31\\"]', function(char)
        local escapes = { ['\\'] = '\\\\', ['"'] = '\\"', ['\b'] = '\\b', ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return escapes[char] or ('\\u%04x'):format(char:byte())
    end))
end

local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then return false end
        count = count + 1
    end
    for index = 1, count do
        if value[index] == nil then return false end
    end
    return true, count
end

function M.encode(value)
    local valueType = type(value)
    if valueType == 'nil' then return 'null' end
    if valueType == 'boolean' then return value and 'true' or 'false' end
    if valueType == 'number' then
        assert(value == value and value ~= math.huge and value ~= -math.huge)
        return ('%.14g'):format(value)
    end
    if valueType == 'string' then return '"' .. jsonEscape(value) .. '"' end
    if valueType ~= 'table' then error('cannot encode JSON value of type ' .. valueType) end

    local array, length = isArray(value)
    local parts = {}
    if array then
        for index = 1, length do parts[#parts + 1] = M.encode(value[index]) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}
    for key in pairs(value) do
        assert(type(key) == 'string', 'JSON object keys must be strings')
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = M.encode(key) .. ':' .. M.encode(value[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end

function M.decode(text)
    local position, length = 1, #text
    local function skipWhitespace()
        while position <= length and text:sub(position, position):match('%s') do position = position + 1 end
    end
    local function fail() error('malformed JSON at byte ' .. position) end
    local parseValue
    local function parseString()
        position = position + 1
        local result = {}
        while position <= length do
            local char = text:sub(position, position)
            position = position + 1
            if char == '"' then return table.concat(result) end
            if char == '\\' then
                local escape = text:sub(position, position)
                position = position + 1
                local escapes = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if escapes[escape] then
                    result[#result + 1] = escapes[escape]
                elseif escape == 'u' then
                    local hex = text:sub(position, position + 3)
                    if not hex:match('^%x%x%x%x$') then fail() end
                    local codepoint = tonumber(hex, 16)
                    position = position + 4
                    if codepoint < 0x80 then
                        result[#result + 1] = string.char(codepoint)
                    elseif codepoint < 0x800 then
                        result[#result + 1] = string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
                    else
                        result[#result + 1] = string.char(0xE0 + math.floor(codepoint / 0x1000), 0x80 + math.floor(codepoint / 0x40) % 0x40, 0x80 + codepoint % 0x40)
                    end
                else fail() end
            elseif char:byte() < 0x20 then fail()
            else result[#result + 1] = char end
        end
        fail()
    end
    local function parseNumber()
        local number = text:match('^-?%d+%.?%d*[eE]?[+-]?%d*', position)
        if not number or number == '' then fail() end
        position = position + #number
        local value = tonumber(number)
        if not value then fail() end
        return value
    end
    local function parseArray()
        position = position + 1
        local result = {}
        skipWhitespace()
        if text:sub(position, position) == ']' then position = position + 1; return result end
        while true do
            result[#result + 1] = parseValue()
            skipWhitespace()
            local char = text:sub(position, position); position = position + 1
            if char == ']' then return result end
            if char ~= ',' then fail() end
            skipWhitespace()
        end
    end
    local function parseObject()
        position = position + 1
        local result = {}
        skipWhitespace()
        if text:sub(position, position) == '}' then position = position + 1; return result end
        while true do
            if text:sub(position, position) ~= '"' then fail() end
            local key = parseString(); skipWhitespace()
            if text:sub(position, position) ~= ':' then fail() end
            position = position + 1; result[key] = parseValue(); skipWhitespace()
            local char = text:sub(position, position); position = position + 1
            if char == '}' then return result end
            if char ~= ',' then fail() end
            skipWhitespace()
        end
    end
    function parseValue()
        skipWhitespace()
        local char = text:sub(position, position)
        if char == '"' then return parseString() end
        if char == '{' then return parseObject() end
        if char == '[' then return parseArray() end
        if text:sub(position, position + 3) == 'true' then position = position + 4; return true end
        if text:sub(position, position + 4) == 'false' then position = position + 5; return false end
        if text:sub(position, position + 3) == 'null' then position = position + 4; return nil end
        if char:match('[%-0-9]') then return parseNumber() end
        fail()
    end
    local result = parseValue(); skipWhitespace()
    if position <= length then fail() end
    return result
end

return M

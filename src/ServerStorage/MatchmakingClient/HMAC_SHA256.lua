--!strict
--!optimize 2
--!native

local SHA256 = require(script.Parent.SHA2.SHA256)

local BLOCK_SIZE = 64
local IPAD = string.char(0x36):rep(BLOCK_SIZE)
local OPAD = string.char(0x5c):rep(BLOCK_SIZE)

local function hex_to_bytes(hex)
    local s = hex:gsub("..", function(c)
        return string.char((tonumber(c, 16)) or 0)
    end)
    return s
end

local function xor(s1, s2)
    local res = ""
    for i = 1, BLOCK_SIZE do
        res = res .. string.char(bit32.bxor(string.byte(s1, i), string.byte(s2, i)))
    end
    return res
end

local function hmac_sha256(key, message)
    if #key > BLOCK_SIZE then
        key = hex_to_bytes(SHA256(key))
    end

    while #key < BLOCK_SIZE do
        key = key .. string.char(0)
    end

    local o_key_pad = xor(key, OPAD)
    local i_key_pad = xor(key, IPAD)

    local inner_hash = hex_to_bytes(SHA256(i_key_pad .. message))
    local final_hash = SHA256(o_key_pad .. inner_hash)

    return final_hash
end

return hmac_sha256
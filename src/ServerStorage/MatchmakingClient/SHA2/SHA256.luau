--!strict
--!optimize 2
--!native

local function PreProcess(message)
    local len = #message
    local padded = message .. "\128"
    
    while #padded % 64 ~= 56 do
        padded = padded .. "\0"
    end
    
    local bitLen = len * 8
    
    local lenStr = ""
    for i = 1, 8 do
        lenStr = string.char(bitLen % 256) .. lenStr
        bitLen = math.floor(bitLen / 256)
    end

    return padded .. lenStr
end

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
}

local function toHex(n)
    return string.format("%08x", n)
end

local function sha256(message)
    local H = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    }

    local paddedMessage = PreProcess(message)

    for i = 1, #paddedMessage, 64 do
        local chunk = paddedMessage:sub(i, i + 63)
        local W = {}
        for j = 1, 16 do
            local word = chunk:sub((j - 1) * 4 + 1, j * 4)
            W[j] = bit32.lrotate(string.byte(word, 1), 24) + bit32.lrotate(string.byte(word, 2), 16) + bit32.lrotate(string.byte(word, 3), 8) + string.byte(word, 4)
        end
        
        for j = 17, 64 do
            local s0 = bit32.bxor(bit32.rrotate(W[j - 15], 7), bit32.rrotate(W[j - 15], 18), bit32.rshift(W[j - 15], 3))
            local s1 = bit32.bxor(bit32.rrotate(W[j - 2], 17), bit32.rrotate(W[j - 2], 19), bit32.rshift(W[j - 2], 10))
            W[j] = (W[j - 16] + s0 + W[j - 7] + s1) % 2^32
        end

        local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

        for j = 1, 64 do
            local S1 = bit32.bxor(bit32.rrotate(e, 6), bit32.rrotate(e, 11), bit32.rrotate(e, 25))
            local ch = bit32.bxor(bit32.band(e, f), bit32.band(bit32.bnot(e), g))
            local temp1 = (h + S1 + ch + K[j] + W[j]) % 2^32

            local S0 = bit32.bxor(bit32.rrotate(a, 2), bit32.rrotate(a, 13), bit32.rrotate(a, 22))
            local maj = bit32.bxor(bit32.band(a, b), bit32.band(a, c), bit32.band(b, c))
            local temp2 = (S0 + maj) % 2^32

            h = g
            g = f
            f = e
            e = (d + temp1) % 2^32
            d = c
            c = b
            b = a
            a = (temp1 + temp2) % 2^32
        end

        H[1] = (H[1] + a) % 2^32
        H[2] = (H[2] + b) % 2^32
        H[3] = (H[3] + c) % 2^32
        H[4] = (H[4] + d) % 2^32
        H[5] = (H[5] + e) % 2^32
        H[6] = (H[6] + f) % 2^32
        H[7] = (H[7] + g) % 2^32
        H[8] = (H[8] + h) % 2^32
    end
    
    local digest = ""
    for i = 1, 8 do
        digest = digest .. toHex(H[i])
    end

    return digest
end

return sha256
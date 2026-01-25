--!strict
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HMAC = require(script.HMAC_SHA256)
local RegionService = require(script.RegionService)

local BACKEND_URL = "https://annalee-precognizant-pa.ngrok-free.dev"
local SECRET_HEX = "1c8832532dbf515f674a658fb1b2492d5a879100c0550c984fbe383ec8c7212c0490cf3d3f585b0e43c78398f91bb47fe08b5dc137ce7a753e8589aadbd11e66b321ff108a802489e883ed8c916abe9cd6b26d546eb8be653a079015aacbe88f275229cf5ee54ec06154a059d30b05069365bdbcc32f10fafdf06a59475f58a59b8c9bfd9cae72650ea975683fbf155146f7748b597d98161a64abbd6dbb1edc0ec72aa6ab072c5fc2a15acadef66c1aa527d1dec6ff77c2363d5a0beb52d8f098cacfd4737979563cf5910d7e8bddc2488c3fed8f2c3a6bf7c883abef4e441fcce8cee5b574f2af4570fa7a9d63674f88b997cc301ad8d143271a14e6255108"

local function hexToBytes(hex)
    local s = hex:gsub("..", function(c)
        return string.char(tonumber(c, 16) or 0)
    end)
    return s
end

local SECRET = hexToBytes(SECRET_HEX)

local MatchmakingClient = {}
local activeTickets: { [number]: string } = {}

local function signCanonical(timestamp: string, body: string)
    local msg = timestamp .. body
    return HMAC(SECRET, msg)
end


local function request(method: string, path: string, bodyTable: { [string]: any }?)
    local timestamp = tostring(os.time())
    local body = bodyTable and HttpService:JSONEncode(bodyTable) or ""
    local signature = signCanonical(timestamp, body)

    local requestOptions = {
        Url = BACKEND_URL .. path,
        Method = method,
        Headers = {
            ["Content-Type"] = "application/json",
            ["X-Timestamp"] = timestamp,
            ["X-Signature"] = signature,
        },
    }

    if method ~= "GET" and method ~= "HEAD" then
        requestOptions.Body = body
    end

    local res = HttpService:RequestAsync(requestOptions)

    return res
end

function MatchmakingClient.Queue(player: Player): string?
    if activeTickets[player.UserId] then
        return activeTickets[player.UserId]
    end

    local region: string = RegionService.GetPlayerRegion(player)
    print(region)

    local res = request("POST", "/queue", { pid = player.UserId, elo = 1000, region = region })
    if res.StatusCode ~= 200 then
        warn("Queue failed", res.StatusCode, res.Body)
        return nil
    end

    local data = HttpService:JSONDecode(res.Body)
    activeTickets[player.UserId] = data.ticketId
    print("Queued", player.Name, data.ticketId)
    return data.ticketId
end

function MatchmakingClient.CancelQueue(player: Player): boolean
    local ticket = activeTickets[player.UserId]
    if not ticket then
        return false
    end
    local res = request("DELETE", "/queue/" .. ticket)
    if res.StatusCode ~= 200 then
        return false
    end
    activeTickets[player.UserId] = nil
    return true
end

function MatchmakingClient.Poll(player: Player): { [string]: any }?
    local ticket = activeTickets[player.UserId]
    if not ticket then
        return nil
    end
    local res = request("GET", "/match/" .. ticket)

    if res.StatusCode ~= 200 then
        return nil
    end

    local match = HttpService:JSONDecode(res.Body)
    activeTickets[player.UserId] = nil
    print("MATCH FOUND", match.matchId, match.players)
    MatchmakingClient.TeleportToMatch(match.players, match.matchId)
    return match
end

function MatchmakingClient.TeleportToMatch(playerIds: { [number]: string | number }, matchId: string)
    local server = TeleportService:ReserveServer(game.PlaceId)
    if not server then
        warn("Failed to reserve server")
        return
    end

    local playersToTeleport: { Player } = {}
    for _, userId in ipairs(playerIds) do
        local userIdNum = tonumber(userId)
        if userIdNum then
            local player = Players:GetPlayerByUserId(userIdNum)
            if player then
                table.insert(playersToTeleport, player)
            end
        end
    end

    if #playersToTeleport == 0 then
        warn("No valid players to teleport")
        return
    end

    TeleportService:TeleportToPrivateServer(game.PlaceId, server, playersToTeleport)
end

Players.PlayerRemoving:Connect(function(player)
    activeTickets[player.UserId] = nil
end)

return MatchmakingClient
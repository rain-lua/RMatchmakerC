local PartyService = {}

local HttpsService = game:GetService("HttpService")

local Parties = {}

export type Party = {
    Name: string,
    Players: {[Player]: Player}
}

local function _GeneratePartyName() : string
    local name = "party_"

    name = name..tostring(HttpsService:GenerateGUID(false))

    return name
end

function PartyService.New(players: {[Player]: Player})
    local name = _GeneratePartyName()

    Parties[name] = {
        Name = name,
        Players = players,
    }

    for _, v in Parties[name].Players do
        v:SetAttribute("Party", name)
    end
end

function PartyService.AddMemberToParty(p: Player, pa: Party)
    pa.Players[p] = p
    p:SetAttribute("Party", pa.Name)
end

function PartyService.RemoveMemberFromParty(p: Player, pa: Party)
    pa.Players[p] = nil
    p:SetAttribute("Party", nil)
end


return PartyService
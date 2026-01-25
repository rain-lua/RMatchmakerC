local LocalizationService = game:GetService("LocalizationService")

local RegionService = {}

RegionService.Regions = {
    "EU", "NA", "ME", "OCE"
}

local regionMapping = {
    ["Europe"] = "EU",
    ["NorthAmerica"] = "NA",
    ["SouthAmerica"] = "NA",
    ["Oceania"] = "OCE",
    ["MiddleEast"] = "ME",
    ["Asia"] = "ME", 
}

function RegionService.GetPlayerRegion(p: Player) : string
    local success, playerRegion = pcall(function()
        return LocalizationService:GetCountryRegionForPlayerAsync(p)
    end)

    if success and playerRegion then
        local mappedRegion = regionMapping[playerRegion]
        if mappedRegion then
            return mappedRegion
        else
            return "EU"
        end
    else
        return "EU"
    end
end

return RegionService
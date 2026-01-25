local Players = game:GetService("Players")

local MatchmakingModule = require(game.ServerStorage:WaitForChild("MatchmakingClient"))

Players.PlayerAdded:Connect(function(player)
    print("Queueing player:", player.Name)

    local ticketId = MatchmakingModule.Queue(player)
    if not ticketId then
        warn("Failed to queue player:", player.Name)
        return
    end

    task.spawn(function()
        while true do
            local match = MatchmakingModule.Poll(player)
            if match then
                print("Match found for player:", player.Name)
                break
            end
            task.wait(5)
        end
    end)
end)
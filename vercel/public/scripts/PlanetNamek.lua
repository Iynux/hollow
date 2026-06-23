task.spawn(function()
    while readfile("AutoPlanetNamek_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoPlanetNamek_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoPlanetNamek_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTower("Rukia", Vector3.new(-626, 87, -338))
    PlaceTower("Reaper", Vector3.new(-622, 87, -346))
    task.wait(0.001)
end
SetGame2x()

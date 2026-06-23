task.spawn(function()
    while readfile("%s_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("%s_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("%s_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTower("Rukia", Vector3.new(0, 3, 0))
    PlaceTower("Ulq", Vector3.new(5, 3, 0))
    PlaceTower("Primordial", Vector3.new(-5, 3, 0))
    task.wait(0.001)
end
SetGame2x()

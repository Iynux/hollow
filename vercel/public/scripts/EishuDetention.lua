local RUKIA_POS = Vector3.new(-15.68, 13.0, -820.52)
local ULQ_POS = Vector3.new(-29.70, 51.70, -822.13)

task.spawn(function()
    while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoEishuDetention_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()

local RUKIA_POS = Vector3.new(24.64, 11.0, -482.76)
local ULQ_POS = Vector3.new(43.04, 10.88, -488.77)

task.spawn(function()
    while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
        if getgenv().HollowIsInMatch and getgenv().HollowIsInMatch() then
            getgenv().HollowFireRemote("PlayerVoteReplay")
            getgenv().HollowFireRemote("PlayerVoteToStartMatch")
        end
        task.wait(0.5)
    end
end)

task.spawn(function()
    task.wait(30)
    while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
        PlaceTower("RageDrago", Vector3.new(0, 0, 0))
        task.wait(15)
    end
end)

while readfile("AutoShibuyaTrainStation_" .. LocalPlayerName .. ".Hollow") == "true" do
    PlaceTowerExact("Rukia", RUKIA_POS)
    PlaceTowerExact("Ulq", ULQ_POS)
    task.wait(0.001)
end

SetGame2x()

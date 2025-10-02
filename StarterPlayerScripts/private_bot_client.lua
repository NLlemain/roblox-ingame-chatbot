local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local PRIVATE_EVENT_NAME = "PrivateBotRequest"
local privateEvent = ReplicatedStorage:WaitForChild(PRIVATE_EVENT_NAME)
print("[Client] PrivateBot: RemoteEvent found ->", privateEvent:GetFullName())

local player = Players.LocalPlayer

local function displayLocalMessage(text)
    StarterGui:SetCore("ChatMakeSystemMessage", {
        Text = text,
        Color = Color3.fromRGB(150, 200, 255),
        Font = Enum.Font.SourceSansBold,
        FontSize = Enum.FontSize.Size24,
    })
end

local TALK_RADIUS = 300

if privateEvent then
    privateEvent.OnClientEvent:Connect(function(message)
        print("[Client] OnClientEvent got message ->", typeof(message) == "table" and "table" or tostring(message))
        if typeof(message) == "string" then
            displayLocalMessage("NPC: " .. message)
            return
        end

        if typeof(message) == "table" then
            local text = message.text
            local npcPos = message.npcPosition
            if text and npcPos then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if hrp and TALK_RADIUS then
                    local dist = (hrp.Position - npcPos).Magnitude
                    if dist <= TALK_RADIUS then
                        displayLocalMessage("NPC (nearby): " .. text)
                    else
                        print("[Client] Broadcast received but player is too far (", dist, ") to display")
                    end
                end
            end
        end
    end)
end

local npc
local npcHead
for _, obj in ipairs(workspace:GetChildren()) do
    if obj:IsA("Model") then
        local headPart = obj:FindFirstChild("Head") or obj:FindFirstChild("head")
        if headPart then
            npc = obj
            npcHead = headPart
            break
        end
    end
end

local TALK_RADIUS = 300

local function resolveNpcIfMissing()
    if npc and npc.Parent then return end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") then
            local headPart = obj:FindFirstChild("Head") or obj:FindFirstChild("head")
            if headPart then
                npc = obj
                npcHead = headPart
                print("[Client] Found NPC ->", npc:GetFullName())
                return
            end
        end
    end
end

workspace.ChildAdded:Connect(function(child)
    if not npc then
        resolveNpcIfMissing()
    end
end)

local function isPlayerNear()
    resolveNpcIfMissing()
    if not npc then return false end
    local npcPos
    if npc.PrimaryPart then
        npcPos = npc.PrimaryPart.Position
    elseif npcHead then
        npcPos = npcHead.Position
    else
        local headPart = npc:FindFirstChild("Head") or npc:FindFirstChild("head")
        if headPart then
            npcHead = headPart
            npcPos = npcHead.Position
        else
            return false
        end
    end

    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return (hrp.Position - npcPos).Magnitude <= TALK_RADIUS
end

player.Chatted:Connect(function(msg)
    if not msg then return end
    if isPlayerNear() then
        if privateEvent then
            print("[Client] Firing server with message ->", tostring(msg))
            privateEvent:FireServer(msg)
        else
            warn("[Client] Cannot FireServer: RemoteEvent missing")
        end
        displayLocalMessage("You: " .. (msg ~= "" and msg or "(no message)"))
    end
end)

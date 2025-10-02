
	local npc    = script.Parent
	local head   = npc:FindFirstChild("Head") or npc:FindFirstChild("head")
	local Chat   = game:GetService("Chat")
	local Players = game:GetService("Players")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PRIVATE_EVENT_NAME = "PrivateBotRequest"
	local privateEvent = ReplicatedStorage:FindFirstChild(PRIVATE_EVENT_NAME)
	if not privateEvent then
	    privateEvent = Instance.new("RemoteEvent")
	    privateEvent.Name = PRIVATE_EVENT_NAME
	    privateEvent.Parent = ReplicatedStorage
	end
	print("[Server] PrivateBot: RemoteEvent present in ReplicatedStorage ->", privateEvent and privateEvent:GetFullName())


			local TALK_RADIUS = 300

			local NEBIUS_API_KEY = "YOUR_NEBIUS_API_KEY_HERE"
			local NEBIUS_URL = "https://api.studio.nebius.com/v1/chat/completions"

			local function truncateTo50Words(s)
			    if not s then return "" end
			    local words = {}
			    for w in s:gmatch("%S+") do
			        table.insert(words, w)
			        if #words >= 50 then break end
			    end
			    return table.concat(words, " ")
			end

			local function fetchAIReply(message, player)
				local prompt = "You are a friendly NPC in Roblox. Reply naturally to the user, and keep your response under 50 words. Keep the tone conversational and short."

				if not HttpService.HttpEnabled then
					warn("[Server] HttpService is disabled on this server. Enable HTTP requests in the Game Settings or Studio settings.")
					return "I can't reach the chat service right now. (Http disabled)"
				end

				local payload = {
					model = "meta-llama/Meta-Llama-3.1-8B-Instruct",
					messages = {
						{ role = "system", content = prompt },
						{ role = "user", content = message }
					}
				}

				local body = HttpService:JSONEncode(payload)
				local headers = {
					["Content-Type"] = "application/json",
					["Accept"] = "*/*",
					["Authorization"] = "Bearer " .. NEBIUS_API_KEY
				}

				local maskedAuth = "Bearer " .. (string.sub(NEBIUS_API_KEY, 1, 6) or "") .. "..." .. (string.sub(NEBIUS_API_KEY, -4) or "")

				print(string.format("[Server] Nebius request -> URL=%s Method=POST Headers={Content-Type=%s, Authorization=%s} BodyLength=%d",
					NEBIUS_URL, headers["Content-Type"], maskedAuth, #body))

				local response
				local ok, err = pcall(function()
					response = HttpService:RequestAsync({
						Url = NEBIUS_URL,
						Method = "POST",
						Headers = headers,
						Body = body,
					})
				end)

				if not ok then
					warn("[Server] RequestAsync failed with error:", err)
					return "Sorry, I couldn't reach the chat service."
				end

				if not response then
					warn("[Server] RequestAsync returned nil response")
					return "Sorry, I couldn't reach the chat service."
				end

				print(string.format("[Server] Nebius response -> StatusCode=%s Success=%s BodyLength=%d",
					tostring(response.StatusCode or response.statusCode or "?"), tostring(response.Success or response.success or "?"), tostring(response.Body and #response.Body or 0)))

				local bodyText = response.Body or response.body or ""

				local decoded, decodeErr
				local ok2, dec = pcall(function() return HttpService:JSONDecode(bodyText) end)
				if ok2 and dec then
					decoded = dec
				else
					decodeErr = dec
				end

				if not decoded then
					warn("[Server] Failed to decode JSON response from Nebius:", tostring(decodeErr))
					warn("[Server] Raw body:", bodyText)
					return "Sorry, I couldn't understand the chat response."
				end

				if decoded.choices and decoded.choices[1] then
					local choice = decoded.choices[1]
					if choice.message and choice.message.content then
						return truncateTo50Words(tostring(choice.message.content))
					elseif choice.text then
						return truncateTo50Words(tostring(choice.text))
					end
				end

				if decoded.output and type(decoded.output) == "string" then
					return truncateTo50Words(decoded.output)
				end

				warn("[Server] Nebius response did not contain an expected field. Full decoded response:", HttpService:JSONEncode(decoded))
				return "Sorry, I couldn't generate a reply."
			end

			local function getPosition()
			    if npc.PrimaryPart then
			        return npc.PrimaryPart.Position
			    elseif head then
			        return head.Position
			    end
			    return nil
			end

			local function isPlayerNear(player)
			    local pos = getPosition()
			    if not pos then return false end
			    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			    if not hrp then return false end
			    return (hrp.Position - pos).Magnitude <= TALK_RADIUS
			end

			privateEvent.OnServerEvent:Connect(function(player, message)
			    print(string.format("[Server] OnServerEvent received from %s with message: %s", player.Name or "?", tostring(message)))

			    if not isPlayerNear(player) then
			        print(string.format("[Server] Player %s is too far from NPC; sending too-far reply", player.Name or "?"))
			        privateEvent:FireClient(player, "You are too far away to talk to me.")
			        return
			    end

			    local delaySeconds = 1 + math.random()
			    task.spawn(function()
			        task.wait(delaySeconds)
			        local reply = fetchAIReply(message, player)
			        print(string.format("[Server] Sending reply to %s after %.2fs: %s", player.Name or "?", delaySeconds, tostring(reply)))

			        local speakFrom = head or (npc.PrimaryPart and npc.PrimaryPart)
			        if speakFrom then
			            local ok, err = pcall(function()
			                Chat:Chat(speakFrom, reply, Enum.ChatColor.Blue)
			            end)
			            if not ok then
			                warn("[Server] Chat:Chat failed while replying:", err)
			            end
			        else
			            warn("[Server] Cannot make NPC speak while replying: no Head or PrimaryPart found on NPC")
			        end

					privateEvent:FireClient(player, reply)

					local npcPosition = nil
					if speakFrom and speakFrom.Position then
						npcPosition = speakFrom.Position
					else
						npcPosition = getPosition()
					end

					local broadcast = { text = reply, npcPosition = npcPosition, fromUserId = player and player.UserId }
					privateEvent:FireAllClients(broadcast)
			    end)
			end)

			math.randomseed(tick())
			math.random(); math.random(); math.random()
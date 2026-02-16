local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local spawnPart = workspace:WaitForChild("SpawnPoint")
local deletePart = workspace:WaitForChild("DeletePoint")
local pathPart = workspace:WaitForChild("PathPart")
local modelFolder = ReplicatedStorage:WaitForChild("modelzombi")

local modelSpawnChances = {
	["ssddtt1"] = 50,
	["ssddtt2"] = 30,
}

local spawnDelay = 5
local moveSpeed = 10
local minDistance = 10 

local function selectRandomModel()
	local models = {}
	for _, item in ipairs(modelFolder:GetChildren()) do
		if item:IsA("Tool") then
			local modelInside = item:FindFirstChildWhichIsA("Model")
			if modelInside then
				table.insert(models, {tool = item, model = modelInside})
			end
		elseif item:IsA("Model") then
			table.insert(models, {tool = nil, model = item})
		end
	end

	if #models == 0 then return nil end

	local totalWeight = 0
	for _, data in ipairs(models) do
		local name = data.tool and data.tool.Name or data.model.Name
		local weight = modelSpawnChances[name] or 10
		totalWeight = totalWeight + weight
	end

	local random = math.random() * totalWeight
	local currentWeight = 0
	for _, data in ipairs(models) do
		local name = data.tool and data.tool.Name or data.model.Name
		local weight = modelSpawnChances[name] or 10
		currentWeight = currentWeight + weight
		if random <= currentWeight then
			return data
		end
	end

	return models[1]
end

local function giveToolToRandomPlayer(toolName)
	local players = Players:GetPlayers()
	if #players == 0 then return end

	local randomPlayer = players[math.random(1, #players)]
	local backpack = randomPlayer:FindFirstChild("Backpack")

	if not backpack then return end

	local toolTemplate = modelFolder:FindFirstChild(toolName)
	if toolTemplate and toolTemplate:IsA("Tool") then
		local toolClone = toolTemplate:Clone()
		toolClone.Parent = backpack
		print("Tool given to:", randomPlayer.Name, "Tool:", toolClone.Name)
		return
	end

	for _, item in pairs(modelFolder:GetChildren()) do
		if item:IsA("Tool") then
			local modelInside = item:FindFirstChild(toolName)
			if modelInside then
				local toolClone = item:Clone()
				toolClone.Parent = backpack
				print("Tool given to:", randomPlayer.Name, "Tool:", toolClone.Name)
				return
			end
		end
	end

	warn("Tool not found for:", toolName)
end

local function spawnModel()
	local modelData = selectRandomModel()
	if not modelData then 
		warn("No models found in modelzombi folder")
		return nil 
	end

	local modelTemplate = modelData.model
	local toolName = modelData.tool and modelData.tool.Name or modelTemplate.Name

	if not modelTemplate:IsA("Model") then
		warn("Template is not a Model:", toolName)
		return nil
	end

	local newModel = modelTemplate:Clone()

	local folderName
	local originalName = modelData.tool and modelData.tool.Name or modelTemplate.Name
	if originalName == "ssddtt1" then
		folderName = "ssdd1"
	elseif originalName == "ssddtt2" then
		folderName = "ssdd2"
	else
		folderName = originalName
	end

	local targetFolder = workspace:FindFirstChild(folderName)
	if not targetFolder then
		targetFolder = Instance.new("Folder")
		targetFolder.Name = folderName
		targetFolder.Parent = workspace
	end

	newModel.Parent = targetFolder

	local primaryPart = newModel.PrimaryPart or newModel:FindFirstChildWhichIsA("BasePart", true)
	if not primaryPart then
		warn("Model has no parts:", originalName)
		newModel:Destroy()
		return nil
	end

	newModel.PrimaryPart = primaryPart

	local humanoid = newModel:FindFirstChild("Humanoid")
	if humanoid then
		local savedToolName = toolName
		humanoid.Died:Connect(function()
			print("Zombie died:", savedToolName)
			giveToolToRandomPlayer(savedToolName)
			task.wait(0.5)
			if newModel and newModel.Parent then
				newModel:Destroy()
			end
		end)
	end

	newModel:SetPrimaryPartCFrame(spawnPart.CFrame)

	return newModel
end

local function moveModelOnPath(model)
	if not model or not model.Parent then return end

	local primaryPart = model.PrimaryPart
	if not primaryPart then 
		if model and model.Parent then
			model:Destroy()
		end
		return 
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	local pathHeight = pathPart.Position.Y + (pathPart.Size.Y / 2) + (primaryPart.Size.Y / 0.99)
	local startPos = spawnPart.Position
	local endPos = deletePart.Position

	local directionVector = endPos - startPos
	if directionVector.Magnitude == 0 then
		directionVector = Vector3.new(1, 0, 0)
	end
	local direction = directionVector.Unit

	local startPos3D = Vector3.new(startPos.X, pathHeight, startPos.Z)
	local endPos3D = Vector3.new(endPos.X, pathHeight, endPos.Z)

	local lookAtCFrame = CFrame.lookAt(startPos3D, endPos3D)
	primaryPart.CFrame = lookAtCFrame

	local distance = (endPos3D - startPos3D).Magnitude
	local duration = distance / moveSpeed

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	local targetCFrame = CFrame.lookAt(endPos3D, endPos3D + direction)

	local tween = TweenService:Create(primaryPart, tweenInfo, {CFrame = targetCFrame})
	tween:Play()

	tween.Completed:Connect(function()
		task.wait(0.5)
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

local function canSpawnHere(position)
	if not position then return false end

	for _, folderName in pairs({"ssdd1", "ssdd2"}) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, zombie in pairs(folder:GetChildren()) do
				if zombie:IsA("Model") and zombie.PrimaryPart then
					local distance = (zombie.PrimaryPart.Position - position).Magnitude
					if distance < minDistance then
						return false
					end
				end
			end
		end
	end

	return true
end

local function startSpawning()
	print("Zombie spawning system started")
	while true do
		local spawnPos = spawnPart.Position

		if canSpawnHere(spawnPos) then
			local success, errorMsg = pcall(function()
				local model = spawnModel()
				if model then
					moveModelOnPath(model)
				end
			end)

			if not success then
				warn("Spawn error:", errorMsg)
			end
		end

		task.wait(spawnDelay)
	end
end

startSpawning()

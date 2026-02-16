local module = {}

module.Parts = {
	["MyPart"] = {
		Cost = 10,
		Earn = 1,
		Location = "Forest",
		PartName = "MyPart",
		Damage = 10,
		FireRate = 0.5,
		Range = 200,
		KillReward = 5
	},
}

local activeEarningLoops = {}
local activeShootingLoops = {}
local RunService = game:GetService("RunService")
local isServer = RunService:IsServer()

function module.GetInfo(partName)
	return module.Parts[partName]
end

local function findNearestEnemy(position, range)
	local nearestEnemy = nil
	local nearestDistance = range or 50
	local enemyFolders = {"ssdd1", "ssdd2"}
	for _, folderName in pairs(enemyFolders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			for _, enemy in pairs(folder:GetChildren()) do
				if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") then
					local humanoid = enemy:FindFirstChild("Humanoid")
					if humanoid and humanoid.Health > 0 then
						local distance = (enemy.HumanoidRootPart.Position - position).Magnitude
						if distance < nearestDistance then
							nearestDistance = distance
							nearestEnemy = enemy
						end
					end
				end
			end
		end
	end
	return nearestEnemy
end

local function createProjectile(startPos, targetEnemy, damage, player, killReward)
	if not targetEnemy or not targetEnemy:FindFirstChild("HumanoidRootPart") then
		return
	end
	local projectile = Instance.new("Part")
	projectile.Name = "Projectile"
	projectile.Size = Vector3.new(0.8, 0.8, 0.8)
	projectile.Shape = Enum.PartType.Ball
	projectile.BrickColor = BrickColor.new("New Yeller")
	projectile.Material = Enum.Material.Neon
	projectile.Position = startPos
	projectile.Anchored = false
	projectile.CanCollide = false
	projectile.CFrame = CFrame.new(startPos)
	projectile.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.new(1, 1, 0)
	light.Brightness = 2
	light.Range = 10
	light.Parent = projectile

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Parent = projectile

	local hasHit = false

	local updateConnection
	updateConnection = RunService.Heartbeat:Connect(function()
		if not projectile.Parent or not targetEnemy.Parent or not targetEnemy:FindFirstChild("HumanoidRootPart") then
			if updateConnection then
				updateConnection:Disconnect()
			end
			if projectile.Parent then
				projectile:Destroy()
			end
			return
		end
		local targetPos = targetEnemy.HumanoidRootPart.Position
		local direction = (targetPos - projectile.Position).Unit
		bodyVelocity.Velocity = direction * 120
	end)

	game:GetService("Debris"):AddItem(projectile, 5)

	local touchConnection
	touchConnection = projectile.Touched:Connect(function(hit)
		if hasHit then return end
		if hit.Parent and hit.Parent:FindFirstChild("Humanoid") and hit.Parent:FindFirstChild("HumanoidRootPart") then
			local parent = hit.Parent
			local humanoid = parent:FindFirstChild("Humanoid")
			local isEnemy = false
			local enemyFolders = {"ssdd1", "ssdd2"}
			for _, folderName in pairs(enemyFolders) do
				local folder = workspace:FindFirstChild(folderName)
				if folder and parent.Parent == folder then
					isEnemy = true
					break
				end
			end
			if isEnemy and humanoid and humanoid.Health > 0 then
				hasHit = true
				local currentHealth = humanoid.Health
				humanoid:TakeDamage(damage)
				if humanoid.Health <= 0 and currentHealth > 0 then
					if player and killReward then
						local stats = player:FindFirstChild("leaderstats")
						if stats then
							local coins = stats:FindFirstChild("Coins")
							if coins then
								coins.Value += killReward
							end
						end
					end
				end
				if updateConnection then
					updateConnection:Disconnect()
				end
				if touchConnection then
					touchConnection:Disconnect()
				end
				projectile:Destroy()
			end
		end
	end)

	return projectile
end

function module.SetupPlacementTool(tool, partName, previewPartName)
	if isServer then return end
	previewPartName = previewPartName or partName
	local player = game.Players.LocalPlayer
	local mouse = player:GetMouse()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local event = ReplicatedStorage:WaitForChild("PlacementRemote")
	local clonepart
	local hasPlaced = false
	local partInfo = module.GetInfo(partName)
	if not partInfo then return end

	tool.Equipped:Connect(function()
		if not clonepart and not hasPlaced then
			local actualPartName = partInfo.PartName or previewPartName
			local partTemplate = ReplicatedStorage:FindFirstChild(actualPartName)
			if partTemplate then
				clonepart = partTemplate:Clone()
				clonepart.Parent = workspace
				clonepart.Anchored = true
				clonepart.CanCollide = false
				clonepart.Transparency = 0.5
			end
		end
	end)

	tool.Unequipped:Connect(function()
		if clonepart then
			clonepart:Destroy()
			clonepart = nil
		end
	end)

	mouse.Move:Connect(function()
		if clonepart and tool.Parent == player.Character then
			local rayOrigin = mouse.Hit.Position + Vector3.new(0, 100, 0)
			local rayDirection = Vector3.new(0, -200, 0)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {player.Character, clonepart}
			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if raycastResult then
				local hitPart = raycastResult.Instance
				local plotNumber = player:FindFirstChild("PlotNumber")
				local isPlayerPlot = false
				if plotNumber and plotNumber.Value > 0 then
					local playerPlot = workspace.Map.Plots:FindFirstChild(tostring(plotNumber.Value))
					if playerPlot then
						local tempPlot = playerPlot:FindFirstChild("TempPlot")
						if tempPlot then
							local difo2 = tempPlot:FindFirstChild("DIFO2")
							local difo3 = tempPlot:FindFirstChild("DIFO3")
							if (difo2 and (hitPart == difo2 or hitPart:IsDescendantOf(difo2))) or 
								(difo3 and (hitPart == difo3 or hitPart:IsDescendantOf(difo3))) then
								isPlayerPlot = true
							end
						end
					end
				end
				local groundPos = raycastResult.Position
				clonepart.Position = Vector3.new(groundPos.X, groundPos.Y + clonepart.Size.Y/2, groundPos.Z)
				clonepart.Color = isPlayerPlot and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
			else
				clonepart.Position = Vector3.new(mouse.Hit.Position.X, mouse.Hit.Position.Y + clonepart.Size.Y/2, mouse.Hit.Position.Z)
				clonepart.Color = Color3.fromRGB(255, 0, 0)
			end
		end
	end)

	tool.Activated:Connect(function()
		if clonepart and not hasPlaced then
			local rayOrigin = clonepart.Position + Vector3.new(0, 100, 0)
			local rayDirection = Vector3.new(0, -200, 0)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {player.Character, clonepart}
			local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if not raycastResult then return end
			local hitPart = raycastResult.Instance
			local plotNumber = player:FindFirstChild("PlotNumber")
			local isPlayerPlot = false
			if plotNumber and plotNumber.Value > 0 then
				local playerPlot = workspace.Map.Plots:FindFirstChild(tostring(plotNumber.Value))
				if playerPlot then
					local tempPlot = playerPlot:FindFirstChild("TempPlot")
					if tempPlot then
						local difo2 = tempPlot:FindFirstChild("DIFO2")
						local difo3 = tempPlot:FindFirstChild("DIFO3")
						if (difo2 and (hitPart == difo2 or hitPart:IsDescendantOf(difo2))) or 
							(difo3 and (hitPart == difo3 or hitPart:IsDescendantOf(difo3))) then
							isPlayerPlot = true
						end
					end
				end
			end
			if not isPlayerPlot then return end
			local pos = clonepart.Position
			local rotation = clonepart.Orientation
			event:FireServer(partName, pos, rotation, partInfo.Cost, partInfo.Earn, partInfo.Damage, partInfo.FireRate, partInfo.Range, partInfo.KillReward)
			clonepart:Destroy()
			clonepart = nil
			hasPlaced = true
			task.wait(0.1)
			tool:Destroy()
		end
	end)
end

function module.HandleServerPlacement()
	if not isServer then return end
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local placementRemote = ReplicatedStorage:FindFirstChild("PlacementRemote")
	if not placementRemote then
		placementRemote = Instance.new("RemoteEvent")
		placementRemote.Name = "PlacementRemote"
		placementRemote.Parent = ReplicatedStorage
	end

	placementRemote.OnServerEvent:Connect(function(player, partName, position, rotation, cost, earnAmount, damage, fireRate, range, killReward)
		local plotNumber = player:FindFirstChild("PlotNumber")
		if not plotNumber or plotNumber.Value == 0 then return end
		local playerPlot = workspace.Map.Plots:FindFirstChild(tostring(plotNumber.Value))
		if not playerPlot then return end
		local tempPlot = playerPlot:FindFirstChild("TempPlot")
		if not tempPlot then return end
		local difo2 = tempPlot:FindFirstChild("DIFO2")
		local difo3 = tempPlot:FindFirstChild("DIFO3")
		if not difo2 and not difo3 then return end
		local playerStats = player:FindFirstChild("leaderstats")
		local money = playerStats and playerStats:FindFirstChild("Coins")
		if not money or money.Value < cost then return end
		local partTemplate = ReplicatedStorage:FindFirstChild(partName)
		if not partTemplate then
			local partInfo = module.GetInfo(partName)
			if partInfo and partInfo.PartName then
				partTemplate = ReplicatedStorage:FindFirstChild(partInfo.PartName)
			end
		end
		if not partTemplate then return end
		money.Value -= cost
		local newPart = partTemplate:Clone()
		if newPart:IsA("Model") then
			newPart:SetPrimaryPartCFrame(CFrame.new(position) * CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
			for _, part in pairs(newPart:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = true
					part.Transparency = 0
				end
			end
		else
			newPart.Position = position
			newPart.Orientation = rotation
			newPart.Anchored = true
			newPart.CanCollide = true
			newPart.Transparency = 0
		end
		newPart.Parent = tempPlot
		local partId = tostring(newPart)
		if not activeEarningLoops[player.UserId] then activeEarningLoops[player.UserId] = {} end
		local earningTask = task.spawn(function()
			while newPart and newPart.Parent do
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local coins = stats:FindFirstChild("Coins")
					if coins then coins.Value += earnAmount end
				end
				task.wait(2)
			end
			if activeEarningLoops[player.UserId] then activeEarningLoops[player.UserId][partId] = nil end
		end)
		activeEarningLoops[player.UserId][partId] = earningTask
		if damage and fireRate and range then
			if not activeShootingLoops[player.UserId] then activeShootingLoops[player.UserId] = {} end
			local shootingTask = task.spawn(function()
				while newPart and newPart.Parent do
					local towerPos = newPart:IsA("Model") and newPart.PrimaryPart.Position or newPart.Position
					local nearestEnemy = findNearestEnemy(towerPos, range)
					if nearestEnemy and nearestEnemy:FindFirstChild("HumanoidRootPart") then
						if newPart:IsA("Model") and newPart.PrimaryPart then
							local targetPos = nearestEnemy.HumanoidRootPart.Position
							local lookAt = CFrame.lookAt(towerPos, Vector3.new(targetPos.X, towerPos.Y, targetPos.Z))
							newPart:SetPrimaryPartCFrame(lookAt)
						end
						createProjectile(towerPos + Vector3.new(0, 3, 0), nearestEnemy, damage, player, killReward)
					end
					task.wait(fireRate)
				end
				if activeShootingLoops[player.UserId] then activeShootingLoops[player.UserId][partId] = nil end
			end)
			activeShootingLoops[player.UserId][partId] = shootingTask
		end
		local connection
		connection = newPart.AncestryChanged:Connect(function()
			if not newPart.Parent then
				if activeEarningLoops[player.UserId] and activeEarningLoops[player.UserId][partId] then
					task.cancel(activeEarningLoops[player.UserId][partId])
					activeEarningLoops[player.UserId][partId] = nil
				end
				if activeShootingLoops[player.UserId] and activeShootingLoops[player.UserId][partId] then
					task.cancel(activeShootingLoops[player.UserId][partId])
					activeShootingLoops[player.UserId][partId] = nil
				end
				connection:Disconnect()
			end
		end)
	end)
end

function module.HandleToolShooting()
	if not isServer then return end
	local Players = game:GetService("Players")
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.ChildAdded:Connect(function(child)
				if not child:IsA("Tool") then return end
				local tool = child
				local damage = tool:FindFirstChild("Damage")
				local fireRate = tool:FindFirstChild("FireRate")
				local range = tool:FindFirstChild("Range")
				local killReward = tool:FindFirstChild("KillReward")
				if not (damage and fireRate and range and killReward) then return end
				local shootingLoop
				local equipped = false
				tool.Equipped:Connect(function()
					equipped = true
					shootingLoop = task.spawn(function()
						while equipped and tool.Parent == character do
							if not character:FindFirstChild("HumanoidRootPart") then task.wait(0.1) continue end
							local characterPos = character.HumanoidRootPart.Position
							local nearestEnemy = findNearestEnemy(characterPos, range.Value)
							if nearestEnemy and nearestEnemy:FindFirstChild("HumanoidRootPart") then
								local shootPos = characterPos + Vector3.new(0, 2, 0)
								createProjectile(shootPos, nearestEnemy, damage.Value, player, killReward.Value)
							end
							task.wait(fireRate.Value)
						end
					end)
				end)
				tool.Unequipped:Connect(function()
					equipped = false
					if shootingLoop then task.cancel(shootingLoop) end
				end)
			end)
		end)
	end)
end

function module.CleanupPlayer(player)
	if activeEarningLoops[player.UserId] then
		for _, taskThread in pairs(activeEarningLoops[player.UserId]) do
			task.cancel(taskThread)
		end
		activeEarningLoops[player.UserId] = nil
	end
	if activeShootingLoops[player.UserId] then
		for _, taskThread in pairs(activeShootingLoops[player.UserId]) do
			task.cancel(taskThread)
		end
		activeShootingLoops[player.UserId] = nil
	end
end

return module



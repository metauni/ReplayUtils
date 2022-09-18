-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replay = script.Parent

-- Imports
local t = require(replay.Packages.t)
local NexusVRCharacterModel = require(ReplicatedStorage:WaitForChild("NexusVRCharacterModel"))
local Character = NexusVRCharacterModel:GetResource("Character")
local UpdateInputs = NexusVRCharacterModel:GetResource("UpdateInputs")
local VRCharacterReplay = require(script.VRCharacterReplay)
local persist = require(script.persist)

local VRCharacterRecorder = {}
VRCharacterRecorder.__index = VRCharacterRecorder

local check = t.strictInterface({

	Origin = t.CFrame,
	Player = t.instanceOf("Player"),
	CharacterId = t.union(t.string, t.number),
})

function VRCharacterRecorder.new(args)
	
	assert(check(args))

	return setmetatable(args, VRCharacterRecorder)
end

function VRCharacterRecorder:Start(startTime)
	
	-- Start time is passed as argument for consistency between recorders
	self.StartTime = startTime
	self.Timeline = {}
	
	self.CharacterConnection = UpdateInputs.OnServerEvent:Connect(function(player, HeadCFrame, LeftHandCFrame, RightHandCFrame)
		if player ~= self.Player then
			return
		end
		
		local now = os.clock() - self.StartTime
		
		table.insert(self.Timeline, {now, {self.Origin:Inverse() * HeadCFrame, self.Origin:Inverse() * LeftHandCFrame, self.Origin:Inverse() * RightHandCFrame}})
	end)
end

function VRCharacterRecorder:Stop()
	
	if self.CharacterConnection then
		self.CharacterConnection:Disconnect()
		self.CharacterConnection = nil
	end
end

function VRCharacterRecorder:CreateReplay(replayArgs)
	
	return VRCharacterReplay.new({
		
		Timeline = self.Timeline,
		Origin = self.Origin,
		
		Character = replayArgs.Character,
	})
end

function VRCharacterRecorder:Serialise()
	
	local metadata = {

		CharacterId = self.CharacterId,
	}

	local data = self.Timeline
end

return VRCharacterRecorder

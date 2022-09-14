-- Services
local RunService = game:GetService("RunService")
local replay = script.Parent

-- Imports
local t = require(replay.Packages.t)
local CharacterReplay = require(script.CharacterReplay)
local persist = require(script.persist)
local config = require(script.config)

local CharacterRecorder = {}
CharacterRecorder.__index = CharacterRecorder

local check = t.strictInterface({

	Origin = t.CFrame,
	Player = t.instanceOf("Player"),
	CharacterId = t.union(t.string, t.number),
})

function CharacterRecorder.new(args)

	assert(check(args))
	
	return setmetatable(args, CharacterRecorder)
end

local function capture(originInverse: CFrame, character: Model)

	if not character then
		
		return nil
	end

	local charCFrames = table.create(#config.PartOrder)

	for i, partName in ipairs(config.PartOrder) do
		
		charCFrames[i] = originInverse * character[partName].CFrame
	end

	return charCFrames
end


function CharacterRecorder:Start(startTime)
	
	local originInverse = self.Origin:Inverse()
	
	-- Start time is passed as argument for consistency between recorders
	self.StartTime = startTime
	self.Timeline = {{0, capture(originInverse, self.Player.Character)}}
	
	self.CharacterConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock() - self.StartTime
		local lastFrameTime = self.Timeline[#self.Timeline][1]
		
		if lastFrameTime + 1/config.FPS <= now then
			
			table.insert(self.Timeline, {now, capture(originInverse, self.Player.Character)})
		end
	end)
end

function CharacterRecorder:Stop()

	self.CharacterConnection:Disconnect()
end

function CharacterRecorder:CreateReplay(replayArgs)

	return CharacterReplay.new({

		Character = replayArgs.Character,
		
		Timeline = self.Timeline,
		Origin = self.Origin,
	})
end

function CharacterRecorder:Store(dataStore: DataStore, key: string)
	
	return persist.Store(self, dataStore, key)
end

return CharacterRecorder

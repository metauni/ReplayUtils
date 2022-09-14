-- Services
local RunService = game:GetService("RunService")
local replay = script.Parent

-- Imports
local t = require(replay.Packages.t)

local persist = require(script.Parent.persist)

local Replayer = {}
Replayer.__index = Replayer

local check = t.array(t.interface({

	Init = t.optional(t.callback),
	PlayUpTo = t.callback,
	Stop = t.optional(t.callback),
}))

function Replayer.new(replays)

	assert(check(replays))

	return setmetatable({
		
		Replays = replays
	}, Replayer)
end

function Replayer:Play()

	self.Playhead = 0
	self.Paused = false
	self.StartTime = os.clock()

	for _, replay in ipairs(self.Replays) do
		
		if replay.Init then
			
			replay:Init()
		end
	end
	
	-- The non-nil status of this field tells you whether the replay is active
	self.PlayConnection = RunService.Heartbeat:Connect(function()

		if self.Paused then
			return
		end

		self.Playhead = os.clock() - self.StartTime
		
		local allFinished = true
		
		for _, replay in ipairs(self.Replays) do
			
			if not replay.Finished then

				replay:PlayUpTo(self.Playhead)
			end
			
			allFinished = allFinished and replay.Finished
		end
		
		if allFinished then

			self.PlayConnection:Disconnect()
			self.PlayConnection = nil
		end
		
	end)
end

function Replayer:Pause()

	self.Paused = true
end

function Replayer:Resume()
	
	self.Paused = false
end

function Replayer:Stop()

	if self.PlayConnection then
		
		self.PlayConnection:Disconnect()
		self.PlayConnection = nil
	end
	
	for _, replay in self:__allReplays() do
		
		if replay.Stop then

			replay:Stop()
		end
	end
end

function Replayer.Restore(dataStore, replayId: string, liveData)

	local origin: CFrame = liveData.Origin
	local boards = liveData.Boards
	local chalk: Tool = liveData.Chalk
	local charactersById: {[string]: Model} = liveData.CharactersById
	local eventCallbacks: {[string]: (any...) -> any} = liveData.EventCallbacks
	
	local replays = persist.Restore(dataStore, replayId, {

		Origin = origin,
		Boards = boards,
		Chalk = chalk,
		CharactersById = charactersById,
		EventCallbacks = eventCallbacks,
	})

	return Replayer.new(replays)
end

return Replayer

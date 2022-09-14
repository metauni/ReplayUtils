-- Services
local replay = script.Parent

-- Imports
local t = require(replay.Packages.t)
local EventReplay = require(script.EventReplay)
local persist = require(script.persist)
local dataSerialiser = require(replay.dataSerialiser)

local EventRecorder = {}
EventRecorder.__index = EventRecorder

local check = t.strictInterface({

	Signal = t.union(t.typeof("RBXScriptSignal"), t.interface({ Connect = t.callback })),
})

function EventRecorder.new(args)

	assert(check(args))
	
	return setmetatable(args, EventRecorder)
end

function EventRecorder:Start(startTime)
	
	-- Start time is passed as argument for consistency between recorders
	self.StartTime = startTime
	self.Timeline = {}
	
	self.Connection = self.Signal:Connect(function(...)
		
		local now = os.clock() - self.StartTime

		local args = {...}

		for i=1, #args do

			if i == 1 then
			
				if typeof(args[1]) == "Instance" and args[1]:IsA("Player") then
					
					args[1] = tostring(args[1].UserId)
				end
			end
			
			if not dataSerialiser.CanSerialise(args[i]) then
				
				warn("[Replay] EventRecorder will not be able to serialise args["..i.."] = "..tostring(args[i])) 
			end
		end
		
		table.insert(self.Timeline, {now, args})
	end)
end

function EventRecorder:Stop()
	
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
end

function EventRecorder:CreateReplay(replayArgs)
	
	return EventReplay.new({

		Callback = replayArgs.Callback,
		Timeline = self.Timeline,
	})
end

function EventRecorder:Store(dataStore: DataStore, key: string)
	
	return persist.Store(self, dataStore, key)
end


return EventRecorder

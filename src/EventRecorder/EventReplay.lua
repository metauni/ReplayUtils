-- Services
local replay = script.Parent.Parent

-- Imports
local t = require(replay.Packages.t)

-- Helper functions
local persist = require(script.Parent.persist)

local EventReplay = {}
EventReplay.__index = EventReplay

local check = t.strictInterface({

	Callback = t.callback,
	Timeline = t.table,
})

function EventReplay.new(args)

	assert(check(args))

	return setmetatable(args, EventReplay)
end

function EventReplay:Init()

	self.TimelineIndex = 1
	self.Finished = false
end

function EventReplay:PlayUpTo(playhead: number)

	while self.TimelineIndex <= #self.Timeline do

		local event = self.Timeline[self.TimelineIndex]

		if event[1] <= playhead then

			local timeStamp, args = unpack(event)

			self.Callback(unpack(args))

			self.TimelineIndex += 1
			continue
		end

		break
	end

	if self.TimelineIndex > #self.Timeline then

		self.Finished = true
	end
end

function EventReplay.Restore(dataStore: DataStore, key: string, replayArgs)
	
	local restoredArgs = persist.Restore(dataStore, key)

	return EventReplay.new({

		Timeline = restoredArgs.Timeline,

		Callback = replayArgs.Callback,
	})
end

return EventReplay

-- Services
local replay = script.Parent.Parent
local metaboard = game:GetService("ServerScriptService").metaboard

-- Imports
local t = require(replay.Packages.t)

-- Helper functions
local persist = require(script.Parent.persist)

local BoardReplay = {}
BoardReplay.__index = BoardReplay

local check = t.strictInterface({

	Board = t.any,
	InitFigures = t.table,
	InitNextFigureZIndex = t.number,
	Timeline = t.table,
})

function BoardReplay.new(args)

	assert(check(args))

	return setmetatable(args, BoardReplay)
end

function BoardReplay:Init()

	for watcher in pairs(self.Board.Watchers) do
		self.Board.Remotes.SetData:FireClient(watcher, self.InitFigures, {}, {}, self.InitNextFigureZIndex, nil, nil)
	end

	self.Board:LoadData(self.InitFigures, {}, {}, self.InitNextFigureZIndex, nil, nil)
	self.Board:DataChanged()

	self.TimelineIndex = 1
	self.Finished = false
end

function BoardReplay:PlayUpTo(playhead: number)

	while self.TimelineIndex <= #self.Timeline do

		local event = self.Timeline[self.TimelineIndex]

		if event[1] <= playhead then

			local timeStamp, remoteName, args = unpack(event)

			for watcher in pairs(self.Board.Watchers) do
				self.Board.Remotes[remoteName]:FireClient(watcher, unpack(args))
			end

			self.Board["Process"..remoteName](self.Board, unpack(args))

			self.TimelineIndex += 1
			continue
		end

		break
	end

	if self.TimelineIndex > #self.Timeline then

		self.Finished = true
	end
end

function BoardReplay.Restore(dataStore: DataStore, key: string, replayArgs)
	
	local restoredArgs = persist.Restore(dataStore, key, replayArgs.Board)

	return BoardReplay.new({
		
		InitFigures = restoredArgs.InitFigures,
		InitNextFigureZIndex = restoredArgs.InitNextFigureZIndex,
		Timeline = restoredArgs.Timeline,

		Board = replayArgs.Board,
	})
end

return BoardReplay

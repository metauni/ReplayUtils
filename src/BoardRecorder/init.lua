-- Services
local replay = script.Parent

-- Imports
local t = require(replay.Packages.t)
local BoardReplay = require(script.BoardReplay)
local persist = require(script.persist)

local BoardRecorder = {}
BoardRecorder.__index = BoardRecorder

local check = t.strictInterface({

	Board = t.any,
	Origin = t.CFrame,
})

function BoardRecorder.new(args)

	assert(check(args))
	
	return setmetatable(args, BoardRecorder)
end

function BoardRecorder:Start(startTime)
	
	-- Start time is passed as argument for consistency between recorders
	self.StartTime = startTime
	self.Timeline = {}
	
	self.InitFigures = self.Board:CommitAllDrawingTasks()
	self.InitNextFigureZIndex = self.Board.NextFigureZIndex
	
	local connections = {}
	
	table.insert(connections, self.Board.Remotes.InitDrawingTask.OnServerEvent:Connect(function(player, drawingTask, canvasPos)

		drawingTask.Verified = true
		
		table.insert(self.Timeline, {os.clock() - self.StartTime, "InitDrawingTask", {"replay-"..tostring(player.UserId), drawingTask, canvasPos}})
	end))
	
	for _, remoteName in ipairs({"UpdateDrawingTask", "FinishDrawingTask", "Undo", "Redo", "Clear"}) do

		local con = self.Board.Remotes[remoteName].OnServerEvent:Connect(function(player, ...)
			
			table.insert(self.Timeline, {os.clock() - self.StartTime, remoteName, {"replay-"..tostring(player.UserId), ...}})
		end)
		
		table.insert(connections, con)
	end
	
	self.Connections = connections
end

function BoardRecorder:Stop()
	
	for _, con in ipairs(self.Connections) do
		con:Disconnect()
	end
end

function BoardRecorder:CreateReplay()
	
	return BoardReplay.new({

		Board = self.Board,
		InitFigures = self.InitFigures,
		InitNextFigureZIndex = self.InitNextFigureZIndex,
		Timeline = self.Timeline,
	})
end

function BoardRecorder:Store(dataStore: DataStore, key: string)
	
	return persist.Store(self, dataStore, key)
end


return BoardRecorder

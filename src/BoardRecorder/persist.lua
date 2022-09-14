-- Services
local replay = script.Parent.Parent
local metaboard = game:GetService("ServerScriptService").metaboard

-- Imports
local Persistence = require(metaboard.Persistence)

-- Helper functions
local chunker = require(replay.persistTools.chunker)
local waitForBudget = require(replay.persistTools.waitForBudget)
local safeSet = require(replay.persistTools.safeSet)
local dataSerialiser = require(script.Parent.Parent.dataSerialiser)


local function store(self, datastore: DataStore, key: string)
	
	local timelineData = table.create(#self.Timeline)
	
	for _, event in ipairs(self.Timeline) do

		local timestamp, remoteName, args = unpack(event)

		local serialisedArgs = table.create(#args)

		for _, arg in ipairs(args) do
			
			table.insert(serialisedArgs, dataSerialiser.Serialise(arg))
		end
		
		table.insert(timelineData, {timestamp, remoteName, serialisedArgs})
	end
	
	local chunks = chunker.Chunk(timelineData)
	
	local surfaceSize = self.Board:SurfaceSize()
	
	local data = {
		
		_FormatVersion = "Board-v1",
		
		InitBoardKey = key.."/init",
		InitBoardEmpty = next(self.InitFigures) == nil and self.InitNextFigureZIndex == 0,
		
		BoardSurfaceCFrame = dataSerialiser.Serialise(self.Origin:Inverse() * self.Board:SurfaceCFrame()),
		BoardSurfaceSize = dataSerialiser.Serialise(surfaceSize),
		
		TimelineChunkCount = #chunks,
		TimelineFirstChunk = chunks[1],
	}
	
	local allSuccess = true
	
	waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	allSuccess = safeSet(datastore, key, data) and allSuccess
		
	for i=2, #chunks do
		
		waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		allSuccess = safeSet(datastore, key..":"..i, chunks[i]) and allSuccess
	end

	-- Don't bother wasting a key on an empty board

	if not data.InitBoardEmpty then
		
		-- TODO: HACK
		local fakeBoard = {
			
			CommitAllDrawingTasks = function(_)
				
				return self.InitFigures
			end,
			AspectRatio = function(_)
				
				return self.Board:AspectRatio()
			end,
			NextFigureZIndex = self.InitNextFigureZIndex,
			ClearCount = 0,
		}
		
		allSuccess = Persistence.StoreWhenBudget(datastore, data.InitBoardKey, fakeBoard) and allSuccess
	end
	
	
	return allSuccess
end

local function restore(dataStore: DataStore, key: string, board)
		
	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	local data = dataStore:GetAsync(key)

	assert(data._FormatVersion == "Board-v1", "Format version "..tostring(data._FormatVersion).." unrecognised")

	local timelineChunks = {}

	if data.TimelineFirstChunk then
		
		table.insert(timelineChunks, data.TimelineFirstChunk)
	end

	for i=2, data.TimelineChunkCount do

		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local chunk = dataStore:GetAsync(key..":"..i)
		
		table.insert(timelineChunks, chunk)
	end

	local initFigures, initNextFigureZIndex do
		
		if data.InitBoardEmpty then
			
			initFigures = {}
			initNextFigureZIndex = 0

		else

			local success, result = Persistence.Restore(dataStore, data.InitBoardKey, board)
			
			if not success then
				
				error("[Replay] Restore failed.\n"..result)
			end
		
			initFigures = result.Figures
			initNextFigureZIndex = result.NextFigureZIndex
		end
	end
	
	local timelineData = chunker.Gather(timelineChunks)
	
	local timeline = table.create(#timelineData)
	
	for _, eventData in ipairs(timelineData) do

		local timestamp, remoteName, serialisedArgs = unpack(eventData)

		local args = table.create(#serialisedArgs)

		for _, serialisedArg in ipairs(serialisedArgs) do
			
			table.insert(args, dataSerialiser.Deserialise(serialisedArg))
		end
		
		table.insert(timeline, {timestamp, remoteName, args})
	end
	
	return {
		InitFigures = initFigures,
		InitNextFigureZIndex = initNextFigureZIndex,
		Timeline = timeline,
	}
end

return {

	Store = store,
	Restore = restore,
}
-- Services
local replay = script.Parent.Parent

-- Imports

-- Helper functions
local chunker = require(replay.persistTools.chunker)
local waitForBudget = require(replay.persistTools.waitForBudget)
local safeSet = require(replay.persistTools.safeSet)
local dataSerialiser = require(replay.dataSerialiser)

local function store(self, datastore: DataStore, key: string)
	
	local timelineData = table.create(#self.Timeline)
	
	for _, event in ipairs(self.Timeline) do

		local timestamp, args = unpack(event)
		local serialisedArgs = {}

		for _, arg in ipairs(args) do
			
			table.insert(serialisedArgs, dataSerialiser.Serialise(arg))
		end
		
		table.insert(timelineData, {timestamp, serialisedArgs})
	end
	
	local chunks = chunker.Chunk(timelineData)
	
	local data = {
		
		_FormatVersion = "Event-v1",
		
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
	
	return allSuccess
end

local function restore(dataStore: DataStore, key: string)
		
	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	local data = dataStore:GetAsync(key)

	assert(data._FormatVersion == "Event-v1", "Format version "..tostring(data._FormatVersion).." unrecognised")

	local timelineChunks = {}

	if data.TimelineFirstChunk then
		
		table.insert(timelineChunks, data.TimelineFirstChunk)
	end

	for i=2, data.TimelineChunkCount do

		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local chunk = dataStore:GetAsync(key..":"..i)
		
		table.insert(timelineChunks, chunk)
	end

	local timelineData = chunker.Gather(timelineChunks)
	
	local timeline = table.create(#timelineData)
	
	for _, eventData in ipairs(timelineData) do

		local timestamp, serialisedArgs = unpack(eventData)

		local args = {}

		for _, serialisedArg in ipairs(serialisedArgs) do
			
			table.insert(args, dataSerialiser.Deserialise(serialisedArg))
		end
		
		table.insert(timeline, {timestamp, args})
	end
	
	return {

		Timeline = timeline,
	}
end

return {

	Store = store,
	Restore = restore,
}
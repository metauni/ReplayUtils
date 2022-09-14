-- Services
local replay = script.Parent.Parent

-- Helper functions
local serialiser = require(script.Parent.serialiser)
local chunker = require(replay.persistTools.chunker)
local waitForBudget = require(replay.persistTools.waitForBudget)
local safeSet = require(replay.persistTools.safeSet)

local function store(self, dataStore, key)

	local timelineData = serialiser.Serialise(self.Timeline)
	local timelineChunks = chunker.Chunk(timelineData)

	local data = {

		_FormatVersion = "Character-v1",

		CharacterId = self.CharacterId,

		TimelineKey = key.."/timeline", -- Format that remembers itself!
	}

	local timelineData = {

		TimelineChunkCount = #timelineChunks,
		TimelineFirstChunk = timelineChunks[1],
	}

	local allSuccess = true

	waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	allSuccess = safeSet(dataStore, key, data) and allSuccess

	waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	allSuccess = safeSet(dataStore, data.TimelineKey, timelineData) and allSuccess
	
	for i=2, #timelineChunks do
		
		waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		allSuccess = safeSet(dataStore, data.TimelineKey..":"..i, timelineChunks[i]) and allSuccess
	end

	return allSuccess
end

local function restore(dataStore: DataStore, key: string)

	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	local data = dataStore:GetAsync(key)

	assert(data._FormatVersion == "Character-v1", "Format version "..tostring(data._FormatVersion).." unrecognised")

	-- Check everything is present
	assert(data.CharacterId)
	assert(data.TimelineKey)

	-- Timeline

	local timelineChunks do
		
		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local timelineData = dataStore:GetAsync(data.TimelineKey)

		timelineChunks = table.create(timelineData.TimelineChunkCount)

		if timelineData.TimelineFirstChunk then

			table.insert(timelineChunks, timelineData.TimelineFirstChunk)
		end

		for i=2, timelineData.TimelineChunkCount do

			waitForBudget(Enum.DataStoreRequestType.GetAsync)
			local chunk = dataStore:GetAsync(data.TimelineKey..":"..i)

			table.insert(timelineChunks, chunk)
		end
	end

	local timelineData = chunker.Gather(timelineChunks)
	local timeline = serialiser.Deserialise(timelineData)

	return {
		CharacterId = data.CharacterId,
		Timeline = timeline,
	}
end

return {

	Store = store,
	Restore = restore,
}
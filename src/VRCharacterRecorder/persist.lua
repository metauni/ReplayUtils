-- Services
local replay = script.Parent.Parent

-- Helper functions
local serialiser = require(script.Parent.serialiser)
local chunker = require(replay.persistTools.chunker)
local waitForBudget = require(replay.persistTools.waitForBudget)
local safeSet = require(replay.persistTools.safeSet)

local function store(self, dataStore, key)

	local timelineData, chalkTimelineData = serialiser.Serialise(self.Timeline, self.ChalkTimeline)
	local timelineChunks = chunker.Chunk(timelineData)
	local chalkTimelineChunks = chunker.Chunk(chalkTimelineData)

	local data = {

		_FormatVersion = "VRCharacter-v1",

		CharacterId = self.CharacterId,

		TimelineKey = key.."/timeline", -- Format that remembers itself!
		ChalkTimelineKey = key.."/chalkTimeline",

		ChalkTimelineChunkCount = #chalkTimelineChunks,
		ChalkTimelineFirstChunk = chalkTimelineChunks[1],
	}

	local timelineData = {

		TimelineChunkCount = #timelineChunks,
		TimelineFirstChunk = timelineChunks[1],
	}

	local allSuccess = true

	waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
	allSuccess = safeSet(dataStore, data.TimelineKey, timelineData) and allSuccess

	for i=2, #timelineChunks do

		waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		allSuccess = safeSet(dataStore, data.TimelineKey..":"..i, timelineChunks[i]) and allSuccess
	end

	allSuccess = safeSet(dataStore, key, data) and allSuccess

	-- It is *very* unlikely that there is more than 4MB of equipping/unequipping chalk
	for i=2, #chalkTimelineChunks do

		warn("[Replay] Unexpectedly large number of chalk timeline entries")

		waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		allSuccess = safeSet(dataStore, data.ChalkTimelineKey..":"..i, chalkTimelineChunks[i]) and allSuccess
	end

	return allSuccess
end

local function restore(dataStore: DataStore, key: string)

	waitForBudget(Enum.DataStoreRequestType.GetAsync)
	local data = dataStore:GetAsync(key)

	assert(data._FormatVersion == "VRCharacter-v1", "Format version "..tostring(data._FormatVersion).." unrecognised")

	-- ChalkTimeline

	local chalkTimelineChunks do

		chalkTimelineChunks = table.create(data.ChalkTimelineChunkCount)

		if data.ChalkTimelineFirstChunk then

			table.insert(chalkTimelineChunks, data.ChalkTimelineFirstChunk)
		end

		for i=2, data.ChalkTimelineChunkCount do

			waitForBudget(Enum.DataStoreRequestType.GetAsync)
			local chunk = dataStore:GetAsync(data.ChalkTimelineKey..":"..i)

			table.insert(chalkTimelineChunks, chunk)
		end
	end

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
	local chalkTimelineData = chunker.Gather(chalkTimelineChunks)
	local timeline, chalkTimeline = serialiser.Deserialise(timelineData, chalkTimelineData)

	return {

		Timeline = timeline,
		ChalkTimeline = chalkTimeline,
		CharacterId = data.CharacterId,
	}
end

return {

	Store = store,
	Restore = restore,
}
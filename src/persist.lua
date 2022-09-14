-- Imports
local BoardReplay = require(script.Parent.BoardRecorder.BoardReplay)
local VRCharacterReplay = require(script.Parent.VRCharacterRecorder.VRCharacterReplay)
local CharacterReplay = require(script.Parent.CharacterRecorder.CharacterReplay)
local EventReplay = require(script.Parent.EventRecorder.EventReplay)

-- Helper functions
local waitForBudget = require(script.Parent.persistTools.waitForBudget)
local safeSet = require(script.Parent.persistTools.safeSet)

local function store(self, dataStore: DataStore, replayId: number, replayName: string, force: boolean, retryOnFail: boolean)
	
	if not force then
		
		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local data = dataStore:GetAsync("ReplayIndex/"..replayId)
		
		if data then
			
			local errormsg = "[Replay] Key: ReplayIndex/"..replayId.." already in use. Use force=true to silence"
			warn(errormsg)
			
			return false, errormsg, data
		end
	end
	
	local boardsData = {}
	
	for boardId, board in self.Boards do

		boardsData[boardId] = {
			
			Name = board:FullName(),
			Key = "ReplayData/"..replayId.."/Boards/"..boardId,
		}
	end
	
	local vrCharactersData = {}
	
	for i, vrPlayer in ipairs(self.VRPlayers) do
		
		table.insert(vrCharactersData, {
			
			CharacterId = tostring(vrPlayer.UserId),
			Key = "ReplayData/"..replayId.."/VRCharacters/"..i
		})
	end
	
	local charactersData = {}

	for i, player in ipairs(self.Players) do

		table.insert(charactersData, {

			CharacterId = tostring(player.UserId),
			Key = "ReplayData/"..replayId.."/Characters/"..i
		})
	end

	local eventsData = {}

	for signalId, signal in self.Signals do
		
		eventsData[signalId] = {

			SignalId = signalId,
			Key = "ReplayData/"..replayId.."/Events/"..signalId,
		}
	end

	local data = {

		_FormatVersion = "Replay-v1",
		
		Name = replayName,
		
		BoardReplays = boardsData,
		VRCharacterReplays = vrCharactersData,
		CharacterReplays = charactersData,
		EventReplays = eventsData,
	}
	
	local allSuccess = true
	
	while true do
		
		waitForBudget(Enum.DataStoreRequestType.SetIncrementAsync)
		allSuccess = safeSet(dataStore, "ReplayIndex/"..replayId, data) and allSuccess
		
		if retryOnFail and not allSuccess then
			
			warn("[Replay] Replay "..replayId..", "..replayName..", failed. Retrying in 5sec.")
			task.wait(5)
			continue
		end

		for boardId, board in self.Boards do

			local key = data.BoardReplays[boardId].Key
			local boardRecorder = self.BoardRecorders[boardId]

			allSuccess = boardRecorder:Store(dataStore, key) and allSuccess
		end

		if retryOnFail and not allSuccess then

			warn("[Replay] Replay "..replayId..", "..replayName..", failed. Retrying in 5sec.")
			task.wait(5)
			continue
		end

		for i, vrPlayer in ipairs(self.VRPlayers) do

			local replayData = data.VRCharacterReplays[i]
			local key = replayData.Key
			local vrCharacterRecorder = self.VRCharacterRecorders[i]
		
			allSuccess = vrCharacterRecorder:Store(dataStore, key) and allSuccess
		end

		if retryOnFail and not allSuccess then

			warn("[Replay] Replay "..replayId..", "..replayName..", failed. Retrying in 5sec.")
			task.wait(5)
			continue
		end
		
		for i, player in ipairs(self.Players) do

			local replayData = data.CharacterReplays[i]
			local key = replayData.Key
			local characterRecorder = self.CharacterRecorders[i]

			allSuccess = characterRecorder:Store(dataStore, key) and allSuccess
		end

		if retryOnFail and not allSuccess then

			warn("[Replay] Replay "..replayId..", "..replayName..", failed. Retrying in 5sec.")
			task.wait(5)
			continue
		end

		for signalId, signal in self.Signals do
			
			local replayData = data.EventReplays[signalId]
			local key = replayData.Key
			local eventRecorder = self.EventRecorders[signalId]

			allSuccess = eventRecorder:Store(dataStore, key) and allSuccess
		end

		if retryOnFail and not allSuccess then

			warn("[Replay] Replay "..replayId..", "..replayName..", failed. Retrying in 5sec.")
			task.wait(5)
			continue
		end
		
		break
	end
	
	if allSuccess then
		
		print("[Replay] Successfully stored replay "..replayName.." at ReplayIndex/"..replayId)
		
	else
		
		warn("[Replay] Replay "..replayId..", "..replayName..", failed. It may be possible to partially recover it by inspecting keys")
	end
end

local function restore(dataStore: DataStore, replayId: string, liveData)

	local origin: CFrame = liveData.Origin
	local boards = liveData.Boards
	local chalk: Tool = liveData.Chalk
	local charactersById: {[string]: Model} = liveData.CharactersById
	local eventCallbacks: {[string]: () -> nil} = liveData.EventCallbacks
	
	local replays = {}
	
	local success, errormsg = xpcall(function()
	
		waitForBudget(Enum.DataStoreRequestType.GetAsync)
		local data = dataStore:GetAsync("ReplayIndex/"..replayId)

		if not data then

			return nil
		end

		assert(data._FormatVersion == "Replay-v1", "Format version "..tostring(data._FormatVersion).." unrecognised")

		-- Board Replays

		for boardId, replayData in data.BoardReplays or {} do
	
			local key = replayData.Key
			local replay = BoardReplay.Restore(dataStore, key, {
				Board = boards[boardId],
			})
			
			table.insert(replays, replay)
		end

		-- VRCharacter Replays

		for i, replayData in ipairs(data.VRCharacterReplays or {}) do
			
			local key = replayData.Key
			local soundTimelineData = replayData.SoundTimeline or {}

			local soundTimeline = {}

			for i, soundData in ipairs(soundTimelineData) do
				
				local timestamp = soundData.Timestamp
				local startPosition = soundData.StartPosition or 0
				local soundId = soundData.SoundId

				local sound = Instance.new("Sound")
				sound.SoundId = soundId
				sound.TimePosition = startPosition

				table.insert(soundTimeline, {timestamp, sound})
			end

			table.insert(replays, VRCharacterReplay.Restore(dataStore, key, {

				Origin = origin,
				Chalk = chalk:Clone(),
				SoundTimeline = soundTimeline,
				CharactersById = charactersById,
			}))
		end

		-- Character Replays

		for i, replayData in ipairs(data.CharacterReplays or {}) do

			local key = replayData.Key
			local soundTimelineData = replayData.SoundTimeline or {}

			local soundTimeline = {}

			for i, soundData in ipairs(soundTimelineData) do
				
				local timestamp = soundData.Timestamp
				local startPosition = soundData.StartPosition or 0
				local soundId = soundData.SoundId

				local sound = Instance.new("Sound")
				sound.SoundId = soundId
				sound.TimePosition = startPosition

				table.insert(soundTimeline, {timestamp, sound})
			end

			table.insert(replays, CharacterReplay.Restore(dataStore, key, {

				Origin = origin,
				Chalk = chalk:Clone(),
				SoundTimeline = soundTimeline,
				CharactersById = charactersById,
			}))
		end

		-- Event Replays

		for signalId, replayData in (data.EventReplays or {}) do
	
			local key = replayData.Key
			local replay = EventReplay.Restore(dataStore, key, {
				
				Callback = eventCallbacks[signalId]
			})
			
			table.insert(replays, replay)
		end
		
	end, debug.traceback)
	
	if not success then
		
		error("[Replay] Restore failed for replayId "..replayId.."\n"..errormsg)
	end
	
	print("[Replay] Successfully restored Replay with Id: "..replayId)
	
	return replays
end

return {

	Store = store,
	Restore = restore,
}
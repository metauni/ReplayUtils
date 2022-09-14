-- Services
local replay = script.Parent

--Imports
local t = require(replay.Packages.t)
local BoardRecorder = require(replay.BoardRecorder)
local CharacterRecorder = require(replay.CharacterRecorder)
local VRCharacterRecorder = require(replay.VRCharacterRecorder)
local EventRecorder = require(replay.EventRecorder)

-- Helper functions
local persist = require(replay.persist)

local Recorder = {}
Recorder.__index = Recorder

local check = t.strictInterface({

	Origin = t.CFrame,
	Boards = t.table,
	VRPlayers = t.array(t.instanceOf("Player")),
	Players = t.array(t.instanceOf("Player")),
	Signals = t.values(t.union(t.typeof("RBXScriptSignal"), t.interface({ Connect = t.callback }))),
	
})

--[[
	NOTE: The keys of the boards table are used as identifiers for each board
	and are used in the datastore keys for each board (so keep them short)
	The boards table can be a dictionary or an array (which will result in numeric keys).

	If it's an array. Ensure to keep the order consistent (don't use :GetChildren() anywhere).
--]]
function Recorder.new(args)

	assert(check(args))
	
	local self = setmetatable(args, Recorder)
	
	self.BoardRecorders = {}
	self.VRCharacterRecorders = table.create(#self.VRPlayers)
	self.CharacterRecorders = table.create(#self.Players)
	self.EventRecorders = {}

	for boardId, board in self.Boards do
		
		self.BoardRecorders[boardId] = BoardRecorder.new({
			
			Board = board,
			Origin = self.Origin
		})
	end
	
	for i, player in ipairs(self.VRPlayers) do
		
		table.insert(self.VRCharacterRecorders, VRCharacterRecorder.new({
			
			Player = player,
			CharacterId  = player.UserId,
			Origin = self.Origin
		}))
	end
	
	for i, player in ipairs(self.Players) do
		
		table.insert(self.CharacterRecorders, CharacterRecorder.new({
			
			-- TODO: Make this actually take a player not a character
			Player = player,
			CharacterId  = player.UserId,
			Origin = self.Origin
		}))
	end

	for signalId, signal in self.Signals do
		
		self.EventRecorders[signalId] = EventRecorder.new({
			
			Signal = signal
		})
	end

	return self
end

function Recorder:__allRecorders()
	
	local recorders = {}

	for _, boardRecorder in self.BoardRecorders do
		
		table.insert(recorders, boardRecorder)
	end
	
	for _, vrCharacterRecorder in ipairs(self.VRCharacterRecorders) do
		
		table.insert(recorders, vrCharacterRecorder)
	end
	
	for _, characterRecorder in ipairs(self.CharacterRecorders) do
		
		table.insert(recorders, characterRecorder)
	end

	for _, eventRecorder in self.EventRecorders do
		
		table.insert(recorders, eventRecorder)
	end

	return recorders
end

function Recorder:Start()
	
	-- Globally agreed start time across recorders
	self.StartTime = os.clock()
	
	for _, recorder in self:__allRecorders() do
		
		recorder:Start(self.StartTime)
	end
end

function Recorder:Stop()
	
	for _, recorder in self:__allRecorders() do
		
		recorder:Stop()
	end
end

function Recorder:CreateReplays(args)

	local eventCallbacks = args.EventCallbacks or {}

	local replays = {}

	for _, boardRecorder in self.BoardRecorders do

		table.insert(replays, boardRecorder:CreateReplay())
	end

	for i, vrCharacterRecorder in ipairs(self.VRCharacterRecorders) do
		
		local player = self.VRPlayers[i]

		local archivable = player.Character.Archivable
		player.Character.Archivable = true
		local clone = player.Character:Clone()
		player.Character.Archivable = archivable

		table.insert(replays, vrCharacterRecorder:CreateReplay({

			Character = clone,
		}))
	end

	for i, characterRecorder in ipairs(self.CharacterRecorders) do
		
		local player = self.Players[i]

		local archivable = player.Character.Archivable
		player.Character.Archivable = true
		local clone = player.Character:Clone()
		player.Character.Archivable = archivable

		table.insert(replays, characterRecorder:CreateReplay({
			
			Character = clone
		}))
	end

	for signalId, eventRecorder in self.EventRecorders do
		
		local callback = (eventCallbacks or {})[signalId]

		if not callback then
			
			error("[replay] No callback given for signalId "..signalId)
		end

		table.insert(replays, eventRecorder:CreateReplay({

			Callback = callback,
		}))
	end
	
	return replays
end

function Recorder:Store(datastore: DataStore, replayId: number, replayName: string, force: boolean, retryOnFail: boolean)
	
	return persist.Store(self, datastore, replayId, replayName, force, retryOnFail)
end

return Recorder
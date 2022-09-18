-- Services
local replay = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local metaboard = ServerScriptService.metaboard

--Imports
local t = require(replay.Packages.t)
local GoodSignal = require(replay.Packages.GoodSignal)
local BoardRecorder = require(replay.BoardRecorder)
local CharacterRecorder = require(replay.CharacterRecorder)
local VRCharacterRecorder = require(replay.VRCharacterRecorder)
local EventRecorder = require(replay.EventRecorder)
local NexusVRCharacterModel = require(ReplicatedStorage:WaitForChild("NexusVRCharacterModel"))
local CharacterService = NexusVRCharacterModel:GetInstance("State.CharacterService")

-- Helper functions
local persist = require(replay.persist)

local BoardTalkRecorder = {}
BoardTalkRecorder.__index = BoardTalkRecorder

local check = t.strictInterface({

	Origin = t.CFrame,
	Boards = t.table,
	Players = t.array(t.instanceOf("Player")),
	Signals = t.values(t.union(t.typeof("RBXScriptSignal"), t.interface({ Connect = t.callback }))),
	
})

--[[
	NOTE: The keys of the boards table are used as identifiers for each board
	and are used in the datastore keys for each board (so keep them short)
	The boards table can be a dictionary or an array (which will result in numeric keys).

	If it's an array. Ensure to keep the order consistent (don't use :GetChildren() anywhere).
--]]
function BoardTalkRecorder.new(args)

	assert(check(args))
	
	local self = setmetatable(args, BoardTalkRecorder)
	
	self.BoardRecorders = {}
	
	for boardId, board in self.Boards do
		
		self.BoardRecorders[boardId] = BoardRecorder.new({
			
			Board = board,
			Origin = self.Origin
		})
	end
	
	self.PlayerRecordData = {}
	
	for i, player in ipairs(self.Players) do

		local recordData = {}

		local isVR = CharacterService.Characters[player] ~= nil

		recordData.IsVR = isVR

		recordData.Character = (isVR and VRCharacterRecorder or CharacterRecorder).new({

			Player = player,
			CharacterId  = tostring(player.UserId),
			Origin = self.Origin,
		})

		if isVR then
			
			local character = player.Character or player.CharacterAdded:Wait()
	
			local chalk = character:FindFirstChild("MetaChalk")
				or player.Backpack:FindFirstChild("MetaChalk")
				or error("[Replay] "..player.DisplayName.." has no chalk")
	
			recordData.Chalk = EventRecorder.new({
	
				Signal = chalk.AncestryChanged,
				ProcessArgs = function(...)
					
					return chalk.Parent == player.Character
				end,
			})
	
			recordData.StartWithChalk = chalk.Parent == character,
		end

		self.PlayerRecordData[tostring(player.UserId)] = recordData
	end

	return self
end

function BoardTalkRecorder:__allRecorders()
	
	local recorders = {}

	for _, boardRecorder in self.BoardRecorders do
		
		table.insert(recorders, boardRecorder)
	end
	
	for i, recordData in ipairs(self.PlayerRecordData) do
		
		table.insert(recorders, recordData.Character)
		if recordData.Chalk then
			table.insert(recorders, recordData.Chalk)
		end
	end

	return recorders
end

function BoardTalkRecorder:Start()
	
	-- Globally agreed start time across recorders
	self.StartTime = os.clock()
	
	for _, recorder in self:__allRecorders() do
		
		recorder:Start(self.StartTime)
	end
end

function BoardTalkRecorder:Stop()
	
	for _, recorder in self:__allRecorders() do
		
		recorder:Stop()
	end
end

function BoardTalkRecorder:CreateReplays()

	local replays = {}

	for _, boardRecorder in self.BoardRecorders do

		table.insert(replays, boardRecorder:CreateReplay())
	end

	for _, player in ipairs(self.Players) do
		
		local character do
			
			player.Character or player.CharacterAdded:Wait()
			character = player.Character:Clone()
		end

		local heldChalk = character:FindFirstChild("MetaChalk")
		if heldChalk then
			
			heldChalk:Destroy()
		end

		local recordData = self.PlayerRecordData[tostring(player.UserId)]

		table.insert(replays, recordData.Character:CreateReplay({

			Character = character,
		}))

		if recordData.Chalk then
			
			local chalk = ServerScriptService.ManageVRChalk.MetaChalk:Clone()
			local chalkCallback = function(equipped)
				
				chalk.Parent = equipped and character or nil
			end

			-- initialise chalk
			chalkCallback(chalk.StartWithChalk)

			table.insert(replays, recordData.Chalk:CreateReplay({

				Callback = chalkCallback,
			}))
		end
	end
	
	return replays
end

function BoardTalkRecorder:Store(datastore: DataStore, replayId: number, replayName: string, force: boolean, retryOnFail: boolean)
	
	return persist.Store(self, datastore, replayId, replayName, force, retryOnFail)
end

function BoardTalkRecorder.Restore()

return BoardTalkRecorder
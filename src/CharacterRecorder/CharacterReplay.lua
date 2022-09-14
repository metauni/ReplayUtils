-- Service
local TweenService = game:GetService("TweenService")
local replay = script.Parent.Parent

-- Imports
local t = require(replay.Packages.t)

-- Helper functions
local persist = require(script.Parent.persist)
local config = require(script.Parent.config)

local CharacterReplay = {}
CharacterReplay.__index = CharacterReplay

local checkCharacter = t.instanceOf("Model", {

	["Humanoid"] = t.instanceOf("Humanoid"),

	["HumanoidRootPart"] = t.instanceIsA("BasePart"),
	["Head"] = t.instanceIsA("BasePart"),
	["RightLowerArm"] = t.instanceIsA("BasePart"),
	["RightUpperArm"] = t.instanceIsA("BasePart"),
	["RightUpperLeg"] = t.instanceIsA("BasePart"),
	["RightLowerLeg"] = t.instanceIsA("BasePart"),
	["RightFoot"] = t.instanceIsA("BasePart"),
	["LeftUpperLeg"] = t.instanceIsA("BasePart"),
	["LeftLowerLeg"] = t.instanceIsA("BasePart"),
	["LeftFoot"] = t.instanceIsA("BasePart"),
	["UpperTorso"] = t.instanceIsA("BasePart"),
	["LowerTorso"] = t.instanceIsA("BasePart"),
	["LeftUpperArm"] = t.instanceIsA("BasePart"),
	["LeftLowerArm"] = t.instanceIsA("BasePart"),
	["LeftHand"] = t.instanceIsA("BasePart"),
	["RightHand"] = t.instanceIsA("BasePart"),
})

local check = t.strictInterface({

	Timeline = t.table,
	Origin = t.CFrame,
	SoundTimeline = t.optional(t.table),
	Character = checkCharacter,
})

function CharacterReplay.new(args)

	assert(check(args))

	return setmetatable(args, CharacterReplay)
end

local tweenInfo = TweenInfo.new(1/config.FPS, Enum.EasingStyle.Linear)

local function update(origin: CFrame, character: Model, charCFrames, instantly: boolean?)

	if instantly then
		
		for i, partName in ipairs(config.PartOrder) do

			character[partName].CFrame = origin * charCFrames[i]
		end

		return
	end

	for i, partName in ipairs(config.PartOrder) do

		TweenService:Create(character[partName], tweenInfo, {
			CFrame = origin * charCFrames[i]
		}):Play()
	end
end

function CharacterReplay:Init()
	
	for _, child in ipairs(self.Character:GetChildren()) do
			
		if child:IsA("BasePart") then
			
			child.Anchored = true
		end
	end

	self.Character.Parent = workspace

	if #self.Timeline >= 1 then
		
		update(self.Origin, self.Character, self.Timeline[1][2], true)
	end

	-- Sound
	
	local soundQueue = {}
	
	for i, soundData in ipairs(self.SoundTimeline or {}) do

		local timestamp, sound = unpack(soundData)
	
		table.insert(soundQueue, {timestamp, sound:Clone()})
	end

	table.sort(soundQueue, function(a, b)
		
		return a[1] < b[1]
	end)

	self.SoundQueue = soundQueue

	self.SoundQueueIndex = 1
	self.TimelineIndex = 1
	self.Finished = false
end

function CharacterReplay:PlayUpTo(playhead: number)

	-- Character

	while self.TimelineIndex <= #self.Timeline do

		local event = self.Timeline[self.TimelineIndex]

		if event[1] <= playhead then

			local timeStamp, charCFrames = unpack(event)

			update(self.Origin, self.Character, charCFrames, false)

			self.TimelineIndex += 1
			continue
		end

		break
	end

	-- Sound

	while self.SoundQueueIndex <= #self.SoundQueue do
		
		if self.SoundQueue[self.SoundQueueIndex][1] <= playhead then
			
			local timestamp, sound = unpack(self.SoundQueue[self.SoundQueueIndex])

			local delta = timestamp - playhead

			sound.TimePosition = sound.TimePosition + delta
			sound:Resume()

			self.SoundQueueIndex += 1

			continue
		end

		break
	end

	if self.TimelineIndex > #self.Timeline and self.SoundQueueIndex > #self.SoundQueue then

		self.Finished = true
	end
end

function CharacterReplay.Restore(dataStore: DataStore, key: string, replayArgs)
	
	local restoredArgs = persist.Restore(dataStore, key)

	local characterId = restoredArgs.CharacterId
	local character = replayArgs.CharactersById[tostring(characterId)]

	if not character then
				
		error("No Character Model given with ID: "..tostring(characterId))
	end

	assert(checkCharacter(character))
	
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable

	clone.Name = "replay-"..characterId

	return CharacterReplay.new({

		Character = clone,
		Origin = replayArgs.Origin,

		Timeline = restoredArgs.Timeline,
		SoundTimeline = restoredArgs.SoundTimeline,
	})
end

return CharacterReplay

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replay = script.Parent.Parent

-- Imports
local t = require(replay.Packages.t)
local NexusVRCharacterModel = require(ReplicatedStorage:WaitForChild("NexusVRCharacterModel"))
local Character = NexusVRCharacterModel:GetResource("Character")
local UpdateInputs = NexusVRCharacterModel:GetResource("UpdateInputs")

-- Helper functions
local updateAnchoredFromInputs = require(script.Parent.updateAnchoredFromInputs)
local persist = require(script.Parent.persist)

local VRCharacterReplay = {}
VRCharacterReplay.__index = VRCharacterReplay

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
	Character = checkCharacter,
})

function VRCharacterReplay.new(args)

	assert(check(args))

	return setmetatable(args, VRCharacterReplay)
end

function VRCharacterReplay:Init()

	for _, child in ipairs(self.Character:GetChildren()) do
			
		if child:IsA("BasePart") then
			
			child.Anchored = true
		end
	end

	self.Character.Parent = workspace

	self.NexusCharacter = Character.new(self.Character)

	if #self.Timeline >= 1 then

		local HeadControllerCFrame, LeftHandControllerCFrame, RightHandControllerCFrame = unpack(self.Timeline[1][2])
		
		updateAnchoredFromInputs(self.NexusCharacter, self.Origin * HeadControllerCFrame, self.Origin * LeftHandControllerCFrame, self.Origin * RightHandControllerCFrame, true)
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

	-- Initial values

	self.TimelineIndex = 1
	self.ChalkTimelineIndex = 1
	self.SoundQueueIndex = 1
	self.Finished = false
end

local BLACKLIST = {"HumanoidRootPart", "OrbEar"}
local TRANSPARENCY_FACTOR = 1/5

local _originalTransparency = {}

local function updateChalk(chalk, character, equipped)

	chalk.Parent = equipped and character or nil

	for _, desc in ipairs(character:GetDescendants()) do

		if desc:IsA("BasePart") and not table.find(BLACKLIST, desc.Name) and not desc:IsDescendantOf(chalk) then

			if not _originalTransparency[desc] then
				_originalTransparency[desc] = desc.Transparency
			end

			desc.Transparency = equipped and (1 - TRANSPARENCY_FACTOR * (1 - _originalTransparency[desc])) or _originalTransparency[desc]
		end
	end
end

function VRCharacterReplay:PlayUpTo(playhead: number)

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

	-- Character

	while self.TimelineIndex <= #self.Timeline do

		local event = self.Timeline[self.TimelineIndex]

		if event[1] <= playhead then

			local timeStamp, charCFrames = unpack(event)

			local HeadControllerCFrame, LeftHandControllerCFrame, RightHandControllerCFrame = unpack(charCFrames)

			updateAnchoredFromInputs(self.NexusCharacter, self.Origin * HeadControllerCFrame, self.Origin * LeftHandControllerCFrame, self.Origin * RightHandControllerCFrame)

			self.TimelineIndex += 1
			continue
		end

		break
	end

	-- Chalk

	while self.ChalkTimelineIndex <= #self.ChalkTimeline do

		local event = self.ChalkTimeline[self.ChalkTimelineIndex]

		if event[1] <= playhead then

			updateChalk(self.Chalk, self.Character, event[2])

			self.ChalkTimelineIndex += 1
			continue
		end

		break	
	end

	-- Check finished

	if self.TimelineIndex > #self.Timeline
		and self.ChalkTimelineIndex > #self.ChalkTimeline
		and self.SoundQueueIndex > #self.SoundQueue
		
	then

		self.Finished = true
	end
end

function VRCharacterReplay:Stop()
	
	for _, soundData in ipairs(self.SoundQueue) do
		
		local _, sound = unpack(soundData)

		sound:Stop()
	end
end

function VRCharacterReplay.Restore(metadata, data, replayArgs)

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

	return VRCharacterReplay.new({

		Timeline = restoredArgs.Timeline,
		
		Character = clone,
		Chalk = replayArgs.Chalk,
		SoundTimeline = restoredArgs.SoundTimeline,
		Origin = replayArgs.Origin,
	})
end



return VRCharacterReplay
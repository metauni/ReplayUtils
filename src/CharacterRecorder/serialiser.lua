local function serialiseCFrame(cframe: CFrame)
	
	return table.pack(cframe:GetComponents())
end

local function deserialiseCFrame(data)
	
	return CFrame.new(table.unpack(data))
end

local function serialise(timeline)
	
	local timelineData = table.create(#timeline)
	
	for _, event in ipairs(timeline) do
		
		local timestamp, charCframes = unpack(event)

		local serialisedCharCFrames = {}

		for _, cframe in ipairs(charCframes) do
			
			table.insert(serialisedCharCFrames, serialiseCFrame(cframe))
		end
		
		table.insert(timelineData, {timestamp, serialisedCharCFrames})
	end
	
	return timelineData
end

local function deserialise(timelineData)

	local timeline = table.create(#timelineData)

	for _, eventData in ipairs(timelineData) do

		local timestamp, charCframeData = unpack(eventData)

		local charCFrames = {}

		for _, cframeData in ipairs(charCframeData) do
			
			table.insert(charCFrames, deserialiseCFrame(cframeData))
		end

		table.insert(timeline, {timestamp, charCFrames})
	end

	return timeline
end


return {
	
	Serialise = serialise,
	Deserialise = deserialise,
}

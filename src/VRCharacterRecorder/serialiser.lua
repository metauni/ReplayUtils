local function serialiseCFrame(cframe: CFrame)
	
	return table.pack(cframe:GetComponents())
end

local function deserialiseCFrame(data)
	
	return CFrame.new(table.unpack(data))
end

local function serialise(timeline, chalkTimeline)
	
	local timelineData = table.create(#timeline)
	
	for _, event in ipairs(timeline) do
		
		local timestamp, charCframes = unpack(event)
		
		table.insert(timelineData, {timestamp, {serialiseCFrame(charCframes[1]), serialiseCFrame(charCframes[2]), serialiseCFrame(charCframes[3])}})
	end
	
	-- Nothing to serialise
	local chalkTimelineData = chalkTimeline
	
	return timelineData, chalkTimelineData
end

local function deserialise(timelineData, chalkTimelineData)

	local timeline = table.create(#timelineData)

	for _, eventData in ipairs(timelineData) do

		local timestamp, charCframeData = unpack(eventData)

		table.insert(timeline, {timestamp, {deserialiseCFrame(charCframeData[1]), deserialiseCFrame(charCframeData[2]), deserialiseCFrame(charCframeData[3])}})
	end

	-- Nothing to deserialise
	local chalkTimeline = chalkTimelineData

	return timeline, chalkTimeline
end


return {
	
	Serialise = serialise,
	Deserialise = deserialise,
}

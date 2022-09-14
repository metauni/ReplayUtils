local function serialise(data)
	
	local typ = typeof(data)
	
	if typ == "number" or typ == "string" or typ == "boolean" or typ == "nil" then
		
		return data
	end

	local encData = {
		
		_dataType = typ
	}
	
	if typ == "table" then

		for key, value in data do

			if key == "_dataType" then
				
				error("Table cannot have '_dataType' as key (reserved for deserialising)")
			end
			
			encData[key] = serialise(value)
		end

		return encData
	end

	if typ == "BrickColor" then
		
		encData.Name = data.Name
		return encData
	end

	if typ == "CFrame" then
		
		encData.Comps = data:GetComponents()
		return encData
	end

	if typ == "Color3" then
		
		encData.R = data.R
		encData.G = data.G
		encData.B = data.B
		return encData
	end

	if typ == "Vector2" then
		
		encData.X = data.X
		encData.Y = data.Y
		return encData
	end

	if typ == "Vector3" then
		
		encData.X = data.X
		encData.Y = data.Y
		encData.Z = data.Z
		return encData
	end

	error("[Replay] Cannot serialise "..tostring(typ))
end

local function deserialise(encData)
	
	local encDataType = typeof(encData)
	
	if encDataType == "number" or encDataType == "string" or encDataType == "boolean" or encDataType == "nil" then
		
		return encData
	end
	
	local typ = encData._dataType
	
	if typ == "table" then

		local data = {}

		for key, value in encData do

			if key == "_dataType" then
				continue
			end
			
			data[key] = deserialise(value)
		end

		return data
	end

	if typ == "BrickColor" then
		
		return BrickColor.new(encData.Name)
	end

	if typ == "CFrame" then

		return CFrame.new(encData.Comps)
	end

	if typ == "Color3" then
	
		return Color3.new(encData.R, encData.G, encData.B)
	end

	if typ == "Vector2" then
		
		return Vector2.new(encData.X, encData.Y)
	end

	if typ == "Vector3" then
		
		return Vector3.new(encData.X, encData.Y, encData.Z)
	end

	error("[Replay] Deserialiser _dataType: "..tostring(typ).." not recognised")
end

local _dataTypes = {
	"number",
	"string",
	"boolean",
	"nil",
	"table",
	"BrickColor",
	"CFrame",
	"Color3",
	"Vector2",
	"Vector3",
}

local CAN_ENCODE = {}

for _, typ in ipairs(_dataTypes) do
	
	CAN_ENCODE[typ] = true
end

local function canSerialise(data)
	
	if typeof(data) == "table" then
			
		for _, value in data do
			
			if not canSerialise(data) then
				
				return false
			end
		end

		return true
	end

	return CAN_ENCODE[typeof(data)]
end

return {

	Serialise = serialise,
	Deserialise = deserialise,
	CanSerialise = canSerialise,
}
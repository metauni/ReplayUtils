local HttpService = game:GetService("HttpService")

local DEFAULT_MAX_CHUNK_SIZE = 3900000

local function chunk(entries, maxChunkSize: number?)
	
	maxChunkSize = maxChunkSize or DEFAULT_MAX_CHUNK_SIZE
	
	local lines = table.create(#entries)
	
	for _, entry in ipairs(entries) do
		
		local entryData = HttpService:JSONEncode(entry).."\n"
		
		if #entryData > maxChunkSize then
			error("Entry exceeds max chunk size")
		end
		
		table.insert(lines, entryData)
	end
	
	local chunks = {} do
		
		local i = 1
		while i <= #lines do
			
			local chunkSize = 0
			local j = i
			
			while j <= #lines and chunkSize <= maxChunkSize do
				
				chunkSize += lines[j]:len()
				j += 1
			end

			-- entries i through j-1 don't exceed the chunk limit when concatenated

			table.insert(chunks, table.concat(lines, "", i, j - 1))

			i = j
		end
	end

	return chunks
end

local function gather(chunks)
	
	local entries = {}
	
	for _, chunk in ipairs(chunks) do

		local j = 1

		while j < chunk:len() do

			local k = chunk:find("\n", j + 1)
			local entry = HttpService:JSONDecode(chunk:sub(j, k - 1))
			table.insert(entries, entry)
			
			j = k + 1
		end
	end
	
	return entries
end

return {
	
	Chunk = chunk,
	Gather = gather,
}
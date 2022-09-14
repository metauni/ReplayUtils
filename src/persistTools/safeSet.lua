return function(dataStore: DataStore, key: string, data)
	
	local success, errormsg = xpcall(function()
		
		dataStore:SetAsync(key, data)
		
		return true
		
	end, debug.traceback)
	
	if not success then
		
		warn("[Replay] SetAsync fail for key "..key.."\n"..errormsg)
	end
	
	return success
end
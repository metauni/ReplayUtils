local DataStoreService = game:GetService("DataStoreService")

return function(requestType: Enum.DataStoreRequestType)

	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetAsync) <= 0 do
		task.wait()
	end
end
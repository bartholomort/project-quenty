local Maid = {}
Maid.ClassName = "Maid"

local State = {
	ActiveMaids = setmetatable({}, { __mode = "k" }),
	IsDisposed = false,
	IsStarted = false,
	IsStarting = false,
	IsStopping = false,
	LastError = nil,
}

local function ClearTable(TargetTable)
	if type(TargetTable) ~= "table" then
		return
	end

	for Key in pairs(TargetTable) do
		TargetTable[Key] = nil
	end
end

local function DisposeTable(TargetTable)
	if type(TargetTable) ~= "table" then
		return
	end

	ClearTable(TargetTable)
	pcall(setmetatable, TargetTable, nil)
end

local function IsTaskLibraryMethod(TaskLibrary, MethodName)
	return TaskLibrary and type(TaskLibrary[MethodName]) == "function"
end

local function CleanupTask(Job)
	if not Job then
		return
	end

	local JobType = typeof(Job)

	if JobType == "function" then
		Job()
		return
	end

	if JobType == "table" then
		local Destroy = Job.Destroy
		if type(Destroy) == "function" then
			Destroy(Job)
		end
		return
	end

	if JobType == "Instance" then
		Job:Destroy()
		return
	end

	if JobType == "thread" then
		local TaskLibrary = task
		local Cancelled = false

		if IsTaskLibraryMethod(TaskLibrary, "cancel") and coroutine.running() ~= Job then
			Cancelled = pcall(TaskLibrary.cancel, Job)
		end

		if not Cancelled and IsTaskLibraryMethod(TaskLibrary, "cancel") and IsTaskLibraryMethod(TaskLibrary, "defer") then
			local ThreadToCancel = Job
			TaskLibrary.defer(function()
				pcall(TaskLibrary.cancel, ThreadToCancel)
			end)
		end

		return
	end

	if JobType == "RBXScriptConnection" then
		Job:Disconnect()
	end
end

local function AssertModuleStarted()
	if State.IsDisposed then
		error("Maid has been stopped and disposed. Reload the module before using it again.", 3)
	end

	if State.IsStarted then
		return
	end

	error("Maid is not started. Call Maid.Start() before using Maid.New().", 3)
end

local function AssertMaidActive(Self)
	if not rawget(Self, "_IsDestroyed") then
		return
	end

	error("Cannot use a destroyed Maid.", 3)
end

local function ResetState()
	State.ActiveMaids = setmetatable({}, { __mode = "k" })
	State.IsDisposed = false
	State.IsStarted = false
	State.IsStarting = false
	State.IsStopping = false
	State.LastError = nil
end

function Maid.New()
	AssertModuleStarted()

	local NewMaid = setmetatable({
		_IsDestroyed = false,
		_Tasks = {},
	}, Maid)

	State.ActiveMaids[NewMaid] = true
	return NewMaid
end

function Maid.IsMaid(Value)
	return type(Value) == "table" and Value.ClassName == "Maid"
end

function Maid.IsStarted()
	return State.IsStarted
end

function Maid.GetLastError()
	return State.LastError
end

function Maid.Start()
	if State.IsDisposed then
		return false, "Maid has been disposed; reload the module before starting it again"
	end

	if State.IsStarting then
		return false, "Maid is already starting"
	end

	if State.IsStarted then
		return true
	end

	State.IsStarting = true
	State.LastError = nil
	State.ActiveMaids = setmetatable({}, { __mode = "k" })
	State.IsStarted = true
	State.IsStarting = false

	return true
end

function Maid.Stop()
	if State.IsStarting then
		return false, "Maid is still starting"
	end

	if State.IsStopping then
		return false, "Maid is already stopping"
	end

	State.IsStopping = true

	for ActiveMaid in pairs(State.ActiveMaids) do
		local DidCleanup, CleanupError = pcall(function()
			ActiveMaid:DoCleaning()
		end)

		if not DidCleanup then
			State.LastError = CleanupError
			State.IsStopping = false
			return false, CleanupError
		end
	end

	ResetState()
	State.IsDisposed = true
	DisposeTable(Maid)
	return true
end

function Maid.__index(Self, Index)
	if Maid[Index] then
		return Maid[Index]
	end

	return Self._Tasks[Index]
end

function Maid.__newindex(Self, Index, NewTask)
	AssertMaidActive(Self)

	if Maid[Index] ~= nil then
		error(string.format("Cannot use '%s' as a Maid key", tostring(Index)), 2)
	end

	local Tasks = Self._Tasks
	local PreviousTask = Tasks[Index]

	if PreviousTask == NewTask then
		return
	end

	Tasks[Index] = NewTask
	CleanupTask(PreviousTask)
end

function Maid.Add(Self, TaskItem)
	AssertMaidActive(Self)

	if not TaskItem then
		error("Task cannot be false or nil", 2)
	end

	Self[#Self._Tasks + 1] = TaskItem

	if type(TaskItem) == "table" and not TaskItem.Destroy then
		warn("[Maid.Add] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return TaskItem
end

function Maid.GiveTask(Self, TaskItem)
	AssertMaidActive(Self)

	if not TaskItem then
		error("Task cannot be false or nil", 2)
	end

	local TaskId = #Self._Tasks + 1
	Self[TaskId] = TaskItem

	if type(TaskItem) == "table" and not TaskItem.Destroy then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return TaskId
end

function Maid.GivePromise(Self, Promise)
	AssertMaidActive(Self)

	if not Promise:IsPending() then
		return Promise
	end

	local NewPromise = Promise.resolved(Promise)
	local TaskId = Self:GiveTask(NewPromise)

	NewPromise:Finally(function()
		if rawget(Self, "_IsDestroyed") then
			return
		end

		Self[TaskId] = nil
	end)

	return NewPromise
end

function Maid.DoCleaning(Self)
	if rawget(Self, "_IsDestroyed") then
		return
	end

	local Tasks = Self._Tasks
	rawset(Self, "_IsDestroyed", true)
	State.ActiveMaids[Self] = nil

	for Index, Job in pairs(Tasks) do
		if typeof(Job) == "RBXScriptConnection" then
			Tasks[Index] = nil
			local DidDisconnect, DisconnectError = pcall(Job.Disconnect, Job)
			if not DidDisconnect and State.LastError == nil then
				State.LastError = DisconnectError
			end
		end
	end

	local Index, Job = next(Tasks)
	while Job ~= nil do
		Tasks[Index] = nil
		local DidCleanup, CleanupError = pcall(CleanupTask, Job)
		if not DidCleanup and State.LastError == nil then
			State.LastError = CleanupError
		end
		Index, Job = next(Tasks)
	end
end

Maid.Destroy = Maid.DoCleaning

Maid.new = Maid.New
Maid.isMaid = Maid.IsMaid

return Maid

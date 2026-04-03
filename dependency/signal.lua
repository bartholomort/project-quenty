local function SafeGetMemoryCategory()
	local DebugLibrary = debug
	if type(DebugLibrary) ~= "table" then
		return ""
	end

	local GetMemoryCategory = DebugLibrary.getmemorycategory
	if type(GetMemoryCategory) ~= "function" then
		return ""
	end

	local Success, MemoryCategory = pcall(GetMemoryCategory)
	if Success and type(MemoryCategory) == "string" then
		return MemoryCategory
	end

	return ""
end

local function SafeSetMemoryCategory(MemoryCategory)
	local DebugLibrary = debug
	if type(DebugLibrary) ~= "table" then
		return
	end

	local SetMemoryCategory = DebugLibrary.setmemorycategory
	if type(SetMemoryCategory) ~= "function" then
		return
	end

	local CategoryName = MemoryCategory == "" and "signal_unknown" or MemoryCategory
	pcall(SetMemoryCategory, CategoryName)
end

local State = {
	ActiveSignals = setmetatable({}, { __mode = "k" }),
	FreeThreads = setmetatable({}, { __mode = "kv" }),
	IsDisposed = false,
	IsStarted = false,
	IsStarting = false,
	IsStopping = false,
	LastError = nil,
}

local function AssertModuleStarted()
	if State.IsDisposed then
		error("Signal has been stopped and disposed. Reload the module before using it again.", 3)
	end

	if State.IsStarted then
		return
	end

	error("Signal is not started. Call Signal.Start() before using Signal.New().", 3)
end

local function AssertSignalActive(Self)
	if not rawget(Self, "_IsDestroyed") then
		return
	end

	error("Cannot use a destroyed Signal.", 3)
end

local function ResetState()
	State.ActiveSignals = setmetatable({}, { __mode = "k" })
	State.FreeThreads = setmetatable({}, { __mode = "kv" })
	State.IsDisposed = false
	State.IsStarted = false
	State.IsStarting = false
	State.IsStopping = false
	State.LastError = nil
end

local EventHandlerUtils = {}

function EventHandlerUtils._FireEvent(MemoryCategory, Callback, ...)
	local AcquiredRunnerThread = State.FreeThreads[MemoryCategory]
	State.FreeThreads[MemoryCategory] = nil
	Callback(...)
	State.FreeThreads[MemoryCategory] = AcquiredRunnerThread
end

function EventHandlerUtils._InitializeThread(MemoryCategory)
	SafeSetMemoryCategory(MemoryCategory)

	while true do
		EventHandlerUtils._FireEvent(coroutine.yield())
	end
end

function EventHandlerUtils.Fire(MemoryCategory, Callback, ...)
	assert(type(MemoryCategory) == "string", "Bad memoryCategory")
	assert(type(Callback) == "function", "Bad callback")

	if not State.FreeThreads[MemoryCategory] then
		State.FreeThreads[MemoryCategory] = coroutine.create(EventHandlerUtils._InitializeThread)
		coroutine.resume(State.FreeThreads[MemoryCategory], MemoryCategory)
	end

	task.spawn(State.FreeThreads[MemoryCategory], MemoryCategory, Callback, ...)
end

local Connection = {}
Connection.ClassName = "Connection"
Connection.__index = Connection

function Connection.New(SignalObject, Callback)
	return setmetatable({
		_MemoryCategory = SafeGetMemoryCategory(),
		_Signal = SignalObject,
		_Fn = Callback,
	}, Connection)
end

function Connection.IsConnected(Self)
	return rawget(Self, "_Signal") ~= nil
end

function Connection.Disconnect(Self)
	local SignalObject = rawget(Self, "_Signal")
	if not SignalObject then
		return
	end

	local OurNext = rawget(Self, "_Next")

	if SignalObject._HandlerListHead == Self then
		SignalObject._HandlerListHead = OurNext or false
	else
		local PreviousConnection = SignalObject._HandlerListHead
		while PreviousConnection and rawget(PreviousConnection, "_Next") ~= Self do
			PreviousConnection = rawget(PreviousConnection, "_Next")
		end

		if PreviousConnection then
			assert(rawget(PreviousConnection, "_Next") == Self, "Bad state")
			rawset(PreviousConnection, "_Next", OurNext)
		end
	end

	rawset(Self, "_Signal", nil)
	rawset(Self, "_Fn", nil)
	rawset(Self, "_MemoryCategory", nil)
	rawset(Self, "_Next", nil)
end

Connection.Destroy = Connection.Disconnect
Connection.new = Connection.New

setmetatable(Connection, {
	__index = function(_, Key)
		error(string.format("Attempt to get Connection::%s (not a valid member)", tostring(Key)), 2)
	end,
	__newindex = function(_, Key)
		error(string.format("Attempt to set Connection::%s (not a valid member)", tostring(Key)), 2)
	end,
})

local Signal = {}
Signal.ClassName = "Signal"
Signal.__index = Signal

function Signal.New()
	AssertModuleStarted()

	local NewSignal = setmetatable({
		_HandlerListHead = false,
		_IsDestroyed = false,
		_WaitingThreads = {},
	}, Signal)

	State.ActiveSignals[NewSignal] = true
	return NewSignal
end

function Signal.IsSignal(Value)
	return type(Value) == "table" and getmetatable(Value) == Signal
end

function Signal.IsStarted()
	return State.IsStarted
end

function Signal.GetLastError()
	return State.LastError
end

function Signal.Start()
	if State.IsDisposed then
		return false, "Signal has been disposed; reload the module before starting it again"
	end

	if State.IsStarting then
		return false, "Signal is already starting"
	end

	if State.IsStarted then
		return true
	end

	State.IsStarting = true
	State.LastError = nil
	State.ActiveSignals = setmetatable({}, { __mode = "k" })
	State.FreeThreads = setmetatable({}, { __mode = "kv" })
	State.IsStarted = true
	State.IsStarting = false

	return true
end

function Signal.Stop()
	if State.IsStarting then
		return false, "Signal is still starting"
	end

	if State.IsStopping then
		return false, "Signal is already stopping"
	end

	State.IsStopping = true

	for ActiveSignal in pairs(State.ActiveSignals) do
		local DidDestroy, DestroyError = pcall(function()
			ActiveSignal:DisconnectAll()
		end)

		if not DidDestroy then
			State.LastError = DestroyError
			State.IsStopping = false
			return false, DestroyError
		end
	end

	local CancelTask = task and task.cancel
	if type(CancelTask) == "function" then
		for _, ThreadValue in pairs(State.FreeThreads) do
			pcall(CancelTask, ThreadValue)
		end
	end

	ResetState()
	State.IsDisposed = true
	return true
end

function Signal.Connect(Self, Callback)
	AssertSignalActive(Self)

	local NewConnection = Connection.New(Self, Callback)
	if Self._HandlerListHead then
		rawset(NewConnection, "_Next", Self._HandlerListHead)
		Self._HandlerListHead = NewConnection
	else
		Self._HandlerListHead = NewConnection
	end

	return NewConnection
end

function Signal.GetConnectionCount(Self)
	local ConnectionCount = 0
	local CurrentConnection = Self._HandlerListHead
	while CurrentConnection do
		ConnectionCount = ConnectionCount + 1
		CurrentConnection = rawget(CurrentConnection, "_Next")
	end

	return ConnectionCount
end

function Signal.DisconnectAll(Self)
	if rawget(Self, "_IsDestroyed") then
		return
	end

	rawset(Self, "_IsDestroyed", true)
	State.ActiveSignals[Self] = nil

	while Self._HandlerListHead do
		local LastConnection = Self._HandlerListHead
		LastConnection:Disconnect()
		assert(Self._HandlerListHead ~= LastConnection, "Self._HandlerListHead should not be LastConnection")
	end

	Self._HandlerListHead = false

	local WaitingThreads = rawget(Self, "_WaitingThreads")
	for WaitingCoroutine in pairs(WaitingThreads) do
		WaitingThreads[WaitingCoroutine] = nil
		task.spawn(WaitingCoroutine, nil)
	end
end

function Signal.Fire(Self, ...)
	AssertSignalActive(Self)

	local CurrentConnection = Self._HandlerListHead
	while CurrentConnection do
		local NextNode = rawget(CurrentConnection, "_Next")

		if rawget(CurrentConnection, "_Signal") ~= nil then
			EventHandlerUtils.Fire(CurrentConnection._MemoryCategory or "", CurrentConnection._Fn, ...)
		end

		CurrentConnection = NextNode
	end
end

function Signal.Wait(Self)
	AssertSignalActive(Self)

	local WaitingCoroutine = coroutine.running()
	local WaitingThreads = rawget(Self, "_WaitingThreads")
	local NewConnection

	WaitingThreads[WaitingCoroutine] = true

	NewConnection = Self:Connect(function(...)
		WaitingThreads[WaitingCoroutine] = nil
		NewConnection:Disconnect()
		task.spawn(WaitingCoroutine, ...)
	end)

	return coroutine.yield()
end

function Signal.Once(Self, Callback)
	AssertSignalActive(Self)

	local NewConnection

	NewConnection = Self:Connect(function(...)
		NewConnection:Disconnect()
		Callback(...)
	end)

	return NewConnection
end

Signal.Destroy = Signal.DisconnectAll

Signal.new = Signal.New
Signal.isSignal = Signal.IsSignal

setmetatable(Signal, {
	__index = function(_, Key)
		error(string.format("Attempt to get Signal::%s (not a valid member)", tostring(Key)), 2)
	end,
	__newindex = function(_, Key)
		error(string.format("Attempt to set Signal::%s (not a valid member)", tostring(Key)), 2)
	end,
})

return Signal

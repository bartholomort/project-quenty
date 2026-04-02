if not getmetatable or not setmetatable or not type or not select or type(select(2, pcall(getmetatable, setmetatable({}, {__index = function(self, ...) while true do end end})))['__index']) ~= 'function' or not pcall or not debug or not rawget or not rawset or not pcall(rawset,{}," "," ") or getmetatable(require) or getmetatable(print) or getmetatable(error) or ({debug.info(print,'a')})[1]~=0 or ({debug.info(tostring,'a')})[1]~=0 or ({debug.info(print,'a')})[2]~=true or not select or not getfenv or select(1, pcall(getfenv, 69)) == true or not select(2, pcall(rawget, debug, "info")) or #(((select(2, pcall(rawget, debug, "info")))(getfenv, "n")))<=1 or #(((select(2, pcall(rawget, debug, "info")))(print, "n")))<=1 or not (select(2, pcall(rawget, debug, "info")))(print, "s") == "[C]" or not (select(2, pcall(rawget, debug, "info")))(require, "s") == "[C]" or (select(2, pcall(rawget, debug, "info")))((function()end), "s") == "[C]" or not select(1, pcall(debug.info, coroutine.wrap(function() end)(), 's')) == false then return false and tostring([[]]) or nil end
if not LPH_OBFUSCATED then function LPH_JIT(Function) return Function end function LPH_JIT_MAX(Function) return Function end function LPH_NO_VIRTUALIZE(Function) return Function end function LPH_ENCSTR(Value) return Value end end

local LogService = game:GetService("LogService")
local ScriptContext = game:GetService("ScriptContext")

local GlobalEnv = getgenv and getgenv() or _G
local GetConnections = getconnections
local GlobalKey = LPH_ENCSTR("__ClientConsoleSuppressor")
local HookFunction = hookfunction
local NewCClosure = newcclosure
local SuppressedWarningText = "Bullet went over the raycast budget. Removing from world."

local ClientConsoleSuppressor = {}
local State = {
	IsConsoleOutputSuppressed = false,
	IsStarted = false,
	IsStarting = false,
	IsStopping = false,
	LastError = nil,
	OriginalWarn = nil,
}

local ForEachConsoleSignal = LPH_NO_VIRTUALIZE(function(Callback)
	local function TryCallbackSignal(Object, MemberName)
		local Success, SignalObject = pcall(function()
			return Object[MemberName]
		end)

		if Success and SignalObject then
			Callback(SignalObject)
		end
	end

	TryCallbackSignal(LogService, "MessageOut")
	TryCallbackSignal(LogService, "MessageOutWithStack")
	TryCallbackSignal(LogService, "MessageOutWithStackTrace")
	TryCallbackSignal(LogService, "HttpResultOut")
	TryCallbackSignal(ScriptContext, "Warning")
	TryCallbackSignal(ScriptContext, "Error")
end)

local DisableAllSignalConnections = LPH_JIT_MAX(function(SignalObject)
	if type(GetConnections) ~= "function" then
		return
	end

	local DidGetConnections, ConnectionList = pcall(GetConnections, SignalObject)
	if not DidGetConnections or not ConnectionList then
		return
	end

	for ConnectionIndex = 1, #ConnectionList do
		local Connection = ConnectionList[ConnectionIndex]
		pcall(function()
			Connection:Disconnect()
		end)
	end
end)

local function SuppressConsoleOutput()
	if State.IsConsoleOutputSuppressed then
		return
	end

	State.IsConsoleOutputSuppressed = true
	ForEachConsoleSignal(DisableAllSignalConnections)
	pcall(function()
		LogService:ClearOutput()
	end)
end

local function HookWarn()
	if type(HookFunction) ~= "function" or State.OriginalWarn then
		return
	end

	local OriginalWarn
	local WarnHook = function(...)
		for Index = 1, select("#", ...) do
			if select(Index, ...) == SuppressedWarningText then
				return
			end
		end

		return OriginalWarn(...)
	end

	if type(NewCClosure) == "function" then
		WarnHook = NewCClosure(WarnHook)
	end

	local Success, HookedWarn = pcall(HookFunction, warn, WarnHook)
	if Success and type(HookedWarn) == "function" then
		OriginalWarn = HookedWarn
		State.OriginalWarn = OriginalWarn
	end
end

local function RestoreWarn()
	if type(HookFunction) ~= "function" or not State.OriginalWarn then
		return
	end

	pcall(HookFunction, warn, State.OriginalWarn)
	State.OriginalWarn = nil
end

local function ApplyClientConsoleSuppressor()
	if type(GetConnections) ~= "function" then
		return false, "ClientConsoleSuppressor requires getconnections()"
	end

	local ExistingModule = rawget(GlobalEnv, GlobalKey)
	if ExistingModule and ExistingModule ~= ClientConsoleSuppressor and type(ExistingModule.Stop) == "function" then
		local DidStop, StopResult, StopError = pcall(ExistingModule.Stop, ExistingModule)
		if not DidStop or not StopResult then
			return false, DidStop and (StopError or "ClientConsoleSuppressor failed to stop the previous module") or StopResult
		end
	end

	SuppressConsoleOutput()
	HookWarn()
	State.IsStarted = true
	GlobalEnv[GlobalKey] = ClientConsoleSuppressor
	return true
end

local function CleanupClientConsoleSuppressor()
	State.IsStarted = false
	State.IsConsoleOutputSuppressed = false
	RestoreWarn()

	if rawget(GlobalEnv, GlobalKey) == ClientConsoleSuppressor then
		GlobalEnv[GlobalKey] = nil
	end

	return true
end

local function FinalizeClientConsoleSuppressorUnload()
	State.IsStarted = false
	State.IsStarting = false
	State.IsStopping = false
end

local function Start()
	if State.IsStarting then
		return false, "ClientConsoleSuppressor is already starting"
	end

	if State.IsStopping then
		return false, "ClientConsoleSuppressor is still stopping"
	end

	if State.IsStarted then
		return true
	end

	State.IsStarting = true

	local DidApply, ApplyResult, ApplyError = pcall(ApplyClientConsoleSuppressor)
	State.IsStarting = false

	if DidApply and ApplyResult then
		State.LastError = nil
		return true
	end

	local StartError = DidApply and (ApplyError or "Failed to start ClientConsoleSuppressor") or ApplyResult
	State.LastError = StartError

	local DidCleanup, CleanupError = pcall(CleanupClientConsoleSuppressor)
	if not DidCleanup then
		State.LastError = CleanupError
		return false, CleanupError
	end

	FinalizeClientConsoleSuppressorUnload()
	return false, StartError
end

local function Stop()
	if State.IsStarting then
		return false, "ClientConsoleSuppressor is still starting"
	end

	if State.IsStopping then
		return false, "ClientConsoleSuppressor is already stopping"
	end

	if not State.IsStarted and not State.IsConsoleOutputSuppressed then
		return true
	end

	State.IsStopping = true

	local DidCleanup, CleanupError = pcall(CleanupClientConsoleSuppressor)
	if not DidCleanup then
		State.LastError = CleanupError
		State.IsStopping = false
		return false, CleanupError
	end

	State.LastError = nil
	FinalizeClientConsoleSuppressorUnload()
	return true
end

ClientConsoleSuppressor.Start = Start
ClientConsoleSuppressor.Stop = Stop
ClientConsoleSuppressor.Destroy = Stop

function ClientConsoleSuppressor.IsStarted()
	return State.IsStarted
end

function ClientConsoleSuppressor.GetLastError()
	return State.LastError
end

return ClientConsoleSuppressor

if not getmetatable or not setmetatable or not type or not select or type(select(2, pcall(getmetatable, setmetatable({}, {__index = function(self, ...) while true do end end})))['__index']) ~= 'function' or not pcall or not debug or not rawget or not rawset or not pcall(rawset,{}," "," ") or getmetatable(require) or getmetatable(print) or getmetatable(error) or ({debug.info(print,'a')})[1]~=0 or ({debug.info(tostring,'a')})[1]~=0 or ({debug.info(print,'a')})[2]~=true or not select or not getfenv or select(1, pcall(getfenv, 69)) == true or not select(2, pcall(rawget, debug, "info")) or #(((select(2, pcall(rawget, debug, "info")))(getfenv, "n")))<=1 or #(((select(2, pcall(rawget, debug, "info")))(print, "n")))<=1 or not (select(2, pcall(rawget, debug, "info")))(print, "s") == "[C]" or not (select(2, pcall(rawget, debug, "info")))(require, "s") == "[C]" or (select(2, pcall(rawget, debug, "info")))((function()end), "s") == "[C]" or not select(1, pcall(debug.info, coroutine.wrap(function() end)(), 's')) == false then return false and tostring([[]]) or nil end
if not LPH_OBFUSCATED then function LPH_JIT(Function) return Function end function LPH_JIT_MAX(Function) return Function end function LPH_NO_VIRTUALIZE(Function) return Function end function LPH_ENCSTR(Value) return Value end end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalEnv = getgenv and getgenv() or _G
local GlobalKey = LPH_ENCSTR("__ClientDisableTelemetry")
local MissingValue = {}

local WaitForPath = LPH_NO_VIRTUALIZE(function(Root, PathSegments)
	local Current = Root

	for Index = 1, #PathSegments do
		Current = Current:WaitForChild(PathSegments[Index])
	end

	return Current
end)

local AllStarsFolder = ReplicatedStorage:WaitForChild(LPH_ENCSTR("AllStars"))

local AvatarEditorClientModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"avatareditor",
	"Client",
	"Editor",
	"AvatarEditorClient",
})
local PlayerMetricsUIServiceClientModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"playermetricsui",
	"Client",
	"PlayerMetricsUIServiceClient",
})
local PlayerTelemetryClientModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"adorneeeditorarea",
	"node_modules",
	"@quentystudios",
	"receipt",
	"node_modules",
	"@quentystudios",
	"pricingdata",
	"node_modules",
	"@quentystudios",
	"currency",
	"node_modules",
	"@quentystudios",
	"telemetry",
	"Client",
	"Telemetry",
	"PlayerTelemetryClient",
})
local TelemetryServiceClientModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"adorneeeditorarea",
	"node_modules",
	"@quentystudios",
	"receipt",
	"node_modules",
	"@quentystudios",
	"pricingdata",
	"node_modules",
	"@quentystudios",
	"currency",
	"node_modules",
	"@quentystudios",
	"telemetry",
	"Client",
	"TelemetryServiceClient",
})

local AvatarEditorBinder = require(AvatarEditorClientModule)
local PlayerMetricsUIServiceClient = require(PlayerMetricsUIServiceClientModule)
local PlayerTelemetryBinder = require(PlayerTelemetryClientModule)
local TelemetryServiceClient = require(TelemetryServiceClientModule)

local AvatarEditorClientClass = assert(AvatarEditorBinder:GetConstructor(), "Missing AvatarEditor constructor")
local PlayerTelemetryClientClass = assert(PlayerTelemetryBinder:GetConstructor(), "Missing PlayerTelemetry constructor")

local ClientDisableTelemetry = {}
local State = {
	IsStarted = false,
	IsStarting = false,
	IsStopping = false,
	LastError = nil,
	OriginalFieldValues = setmetatable({}, {
		__mode = "k",
	}),
	PlayerMetricsWasVisible = nil,
}

local function Noop()
end

local function RememberOriginalValue(TargetTable, FieldName)
	if type(TargetTable) ~= "table" then
		return
	end

	local FieldValues = State.OriginalFieldValues[TargetTable]
	if not FieldValues then
		FieldValues = {}
		State.OriginalFieldValues[TargetTable] = FieldValues
	end

	if FieldValues[FieldName] ~= nil then
		return
	end

	local OriginalValue = TargetTable[FieldName]
	FieldValues[FieldName] = OriginalValue == nil and MissingValue or OriginalValue
end

local function SetPatchedValue(TargetTable, FieldName, Replacement)
	if type(TargetTable) ~= "table" then
		return
	end

	RememberOriginalValue(TargetTable, FieldName)
	TargetTable[FieldName] = Replacement
end

local function RestorePatchedValues()
	for TargetTable, FieldValues in pairs(State.OriginalFieldValues) do
		for FieldName, OriginalValue in pairs(FieldValues) do
			if OriginalValue == MissingValue then
				TargetTable[FieldName] = nil
			else
				TargetTable[FieldName] = OriginalValue
			end

			FieldValues[FieldName] = nil
		end

		State.OriginalFieldValues[TargetTable] = nil
	end

	State.OriginalFieldValues = setmetatable({}, {
		__mode = "k",
	})
end

local function GetPlayerMetricsVisible()
	local VisibleObject = rawget(PlayerMetricsUIServiceClient, "_visible")
	if type(VisibleObject) == "table" and rawget(VisibleObject, "Value") ~= nil then
		return VisibleObject.Value
	end

	return nil
end

local function ForcePlayerMetricsHidden(TargetService)
	local VisibleObject = type(TargetService) == "table" and rawget(TargetService, "_visible")
	if type(VisibleObject) == "table" and rawget(VisibleObject, "Value") ~= nil then
		VisibleObject.Value = false
	end
end

local function PatchedSetPlayerMetricsVisible(Self)
	ForcePlayerMetricsHidden(Self)
end

local function ApplyClientDisableTelemetry()
	local ExistingModule = rawget(GlobalEnv, GlobalKey)
	if ExistingModule and ExistingModule ~= ClientDisableTelemetry and type(ExistingModule.Stop) == "function" then
		local DidStop, StopResult, StopError = pcall(ExistingModule.Stop, ExistingModule)
		if not DidStop or not StopResult then
			return false, DidStop and (StopError or "ClientDisableTelemetry failed to stop the previous module") or StopResult
		end
	end

	State.PlayerMetricsWasVisible = GetPlayerMetricsVisible()

	SetPatchedValue(TelemetryServiceClient, "QueuePoint", Noop)
	SetPatchedValue(PlayerMetricsUIServiceClient, "SetPlayerMetricsVisible", PatchedSetPlayerMetricsVisible)
	SetPatchedValue(PlayerTelemetryClientClass, "PromiseQueuePoint", Noop)
	SetPatchedValue(AvatarEditorClientClass, "FirePurchasePromptForTelemetry", Noop)

	ForcePlayerMetricsHidden(PlayerMetricsUIServiceClient)

	State.IsStarted = true
	GlobalEnv[GlobalKey] = ClientDisableTelemetry
	return true
end

local function CleanupClientDisableTelemetry()
	State.IsStarted = false

	RestorePatchedValues()

	if State.PlayerMetricsWasVisible ~= nil and type(PlayerMetricsUIServiceClient.SetPlayerMetricsVisible) == "function" then
		pcall(PlayerMetricsUIServiceClient.SetPlayerMetricsVisible, PlayerMetricsUIServiceClient, State.PlayerMetricsWasVisible)
	end

	State.PlayerMetricsWasVisible = nil

	if rawget(GlobalEnv, GlobalKey) == ClientDisableTelemetry then
		GlobalEnv[GlobalKey] = nil
	end

	return true
end

local function FinalizeClientDisableTelemetryUnload()
	State.IsStarted = false
	State.IsStarting = false
	State.IsStopping = false
end

local function Start()
	if State.IsStarting then
		return false, "ClientDisableTelemetry is already starting"
	end

	if State.IsStopping then
		return false, "ClientDisableTelemetry is still stopping"
	end

	if State.IsStarted then
		return true
	end

	State.IsStarting = true

	local DidApply, ApplyResult, ApplyError = pcall(ApplyClientDisableTelemetry)
	State.IsStarting = false

	if DidApply and ApplyResult then
		State.LastError = nil
		return true
	end

	local StartError = DidApply and (ApplyError or "Failed to start ClientDisableTelemetry") or ApplyResult
	State.LastError = StartError

	local DidCleanup, CleanupError = pcall(CleanupClientDisableTelemetry)
	if not DidCleanup then
		State.LastError = CleanupError
		return false, CleanupError
	end

	FinalizeClientDisableTelemetryUnload()
	return false, StartError
end

local function Stop()
	if State.IsStarting then
		return false, "ClientDisableTelemetry is still starting"
	end

	if State.IsStopping then
		return false, "ClientDisableTelemetry is already stopping"
	end

	if not State.IsStarted then
		return true
	end

	State.IsStopping = true

	local DidCleanup, CleanupError = pcall(CleanupClientDisableTelemetry)
	if not DidCleanup then
		State.LastError = CleanupError
		State.IsStopping = false
		return false, CleanupError
	end

	State.LastError = nil
	FinalizeClientDisableTelemetryUnload()
	return true
end

ClientDisableTelemetry.Start = Start
ClientDisableTelemetry.Stop = Stop
ClientDisableTelemetry.Destroy = Stop

function ClientDisableTelemetry.IsStarted()
	return State.IsStarted
end

function ClientDisableTelemetry.GetLastError()
	return State.LastError
end

return ClientDisableTelemetry

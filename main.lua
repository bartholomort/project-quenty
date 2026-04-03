if not getmetatable or not setmetatable or not type or not select or type(select(2, pcall(getmetatable, setmetatable({}, {__index = function(self, ...) while true do end end})))['__index']) ~= 'function' or not pcall or not debug or not rawget or not rawset or not pcall(rawset,{}," "," ") or getmetatable(require) or getmetatable(print) or getmetatable(error) or ({debug.info(print,'a')})[1]~=0 or ({debug.info(tostring,'a')})[1]~=0 or ({debug.info(print,'a')})[2]~=true or not select or not getfenv or select(1, pcall(getfenv, 69)) == true or not select(2, pcall(rawget, debug, "info")) or #(((select(2, pcall(rawget, debug, "info")))(getfenv, "n")))<=1 or #(((select(2, pcall(rawget, debug, "info")))(print, "n")))<=1 or not (select(2, pcall(rawget, debug, "info")))(print, "s") == "[C]" or not (select(2, pcall(rawget, debug, "info")))(require, "s") == "[C]" or (select(2, pcall(rawget, debug, "info")))((function()end), "s") == "[C]" or not select(1, pcall(debug.info, coroutine.wrap(function() end)(), 's')) == false then return false and tostring([[]]) or nil end
if not LPH_OBFUSCATED then function LPH_JIT(Function) return Function end function LPH_JIT_MAX(Function) return Function end function LPH_NO_VIRTUALIZE(Function) return Function end function LPH_ENCSTR(Value) return Value end end

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")

local AllStarsPlayButtonClientName = LPH_ENCSTR("AllStarsPlayButtonClient")
local AllStarsPlayButtonTag = LPH_ENCSTR("AllStarsPlayButton")
local BartholomortGuiKeyName = "BartholomortGUI"
local ButtonName = "button"
local CharacterAttributeName = "Character"
local CharacterEquipName = "equip"
local CharacterSelectionEntryName = LPH_ENCSTR("CharacterSelectionEntry")
local CharacterSelectionHeaderName = LPH_ENCSTR("CharacterSelectionHeader")
local CharacterSelectionScreenName = LPH_ENCSTR("CharacterSelectionScreen")
local CharacterSelectionServiceRemoteFolderName = LPH_ENCSTR("CharacterSelectionServiceRemotes")
local ConsoleSuppressorFlagName = "ConsoleSuppressor"
local ErrorPromptName = "ErrorPrompt"
local FireActivateName = LPH_ENCSTR("FireActivate")
local HumanoidRootPartName = "HumanoidRootPart"
local IsTeleportingAttributeName = "IsTeleporting"
local NoobCharacterName = LPH_ENCSTR("Noob")
local PromptOverlayName = "promptOverlay"
local PlayActivateCooldown = 15
local LabelName = "label"
local RemotesName = LPH_ENCSTR("Remotes")
local RequestCharacterChangeEventName = LPH_ENCSTR("RequestCharacterChangeEvent")
local RobloxPromptGuiName = "RobloxPromptGui"
local ServerActionCheckDelay = 5
local ServerActionRetryDelay = 60
local ServerHopDelay = 180
local ServerJoinedAt = os.clock()
local TrainingWorldLocation = LPH_ENCSTR("Training")
local WorldLocationAttributeName = "WorldLocation"

local AutoRocketMaid = nil
local AutoRocketToggle = nil
local ClientAutoRocketLauncher = nil
local ClientConsoleSuppressor = nil
local ClientDisableTelemetry = nil
local GlobalEnv = getgenv and getgenv() or _G
local IsUnloading = false
local Library = nil
local LoadedMaid = false
local LoadedSignal = false
local LocalPlayer = Players.LocalPlayer
local Maid = nil
local MainTab = nil
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlayActivateCooldownUntil = 0
local Repo = "https://raw.githubusercontent.com/bartholomort/project-quenty/main/"
local RequestCharacterChange = nil
local SetClientAutoRocketLauncherStarted = nil
local Signal = nil
local StartedMaid = false
local StartedSignal = false

local function EnsureAutoFlag()
	if type(GlobalEnv.auto) ~= "boolean" then
		GlobalEnv.auto = false
	end
end

local function EnsureConsoleSuppressorFlag()
	if type(GlobalEnv[ConsoleSuppressorFlagName]) ~= "boolean" then
		GlobalEnv[ConsoleSuppressorFlagName] = true
	end
end

local function StartModule(Module, Name)
	if not Module or type(Module.Start) ~= "function" then
		return false, Name .. " is missing Start()"
	end

	local Success, ErrorMessage = Module.Start()
	if Success then
		return true
	end

	return false, ErrorMessage or ("Failed to start " .. Name)
end

local function StopModule(Module, Name)
	if not Module or type(Module.Stop) ~= "function" then
		return true
	end

	local Success, ErrorMessage = Module.Stop()
	if not Success and ErrorMessage then
		warn("[" .. Name .. "]", ErrorMessage)
	end

	return Success, ErrorMessage
end

local function DestroyAutoRocketMaid()
	if not AutoRocketMaid then
		return
	end

	local CurrentAutoRocketMaid = AutoRocketMaid
	AutoRocketMaid = nil

	SetClientAutoRocketLauncherStarted(false)
	pcall(CurrentAutoRocketMaid.Destroy, CurrentAutoRocketMaid)
end

local function FinalizeUnload()
	if GlobalEnv[BartholomortGuiKeyName] == Library then
		GlobalEnv[BartholomortGuiKeyName] = nil
	end

	if StartedSignal then
		StopModule(Signal, "Signal")
	end

	if LoadedSignal and GlobalEnv.Signal == Signal then
		GlobalEnv.Signal = nil
	end

	if StartedMaid then
		StopModule(Maid, "Maid")
	end

	if LoadedMaid and GlobalEnv.Maid == Maid then
		GlobalEnv.Maid = nil
	end

	AutoRocketToggle = nil
	ClientAutoRocketLauncher = nil
	ClientConsoleSuppressor = nil
	ClientDisableTelemetry = nil
	Library = nil
	Maid = nil
	MainTab = nil
	PlayActivateCooldownUntil = 0
	Repo = nil
	RequestCharacterChange = nil
	Signal = nil
	StartedMaid = false
	StartedSignal = false
	LoadedMaid = false
	LoadedSignal = false
end

local function Unload()
	if IsUnloading then
		return
	end

	IsUnloading = true

	DestroyAutoRocketMaid()
	StopModule(ClientAutoRocketLauncher, "ClientAutoRocketLauncher")
	StopModule(ClientConsoleSuppressor, "ClientConsoleSuppressor")
	StopModule(ClientDisableTelemetry, "ClientDisableTelemetry")

	task.defer(FinalizeUnload)
end

local TryServerHop = LPH_NO_VIRTUALIZE(function()
	local Success, ResponseBody = pcall(function()
		return game:HttpGet(("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"):format(game.PlaceId))
	end)
	if not Success then
		return false
	end

	local DecodedSuccess, ResponseData = pcall(HttpService.JSONDecode, HttpService, ResponseBody)
	local ServerDataList = DecodedSuccess and ResponseData and ResponseData.data
	if type(ServerDataList) ~= "table" then
		return false
	end

	local ServerIds = {}
	for Index = 1, #ServerDataList do
		local ServerData = ServerDataList[Index]
		if type(ServerData) == "table"
			and type(ServerData.id) == "string"
			and tonumber(ServerData.playing)
			and tonumber(ServerData.maxPlayers)
			and ServerData.playing < ServerData.maxPlayers
			and ServerData.id ~= game.JobId
		then
			ServerIds[#ServerIds + 1] = ServerData.id
		end
	end

	if #ServerIds == 0 then
		return false
	end

	local TeleportSuccess = pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, ServerIds[math.random(1, #ServerIds)], LocalPlayer)
	return TeleportSuccess
end)

local function TryRejoin()
	local Success = pcall(TeleportService.Teleport, TeleportService, game.PlaceId, LocalPlayer)
	return Success
end

local function FindCharacterSelectionScreen()
	return PlayerGui:FindFirstChild(CharacterSelectionScreenName, true)
end

local function ActivateButton(Button)
	if not Button or not Button:IsA("GuiButton") or not Button.Visible then
		return false
	end

	if type(firesignal) == "function" then
		if pcall(firesignal, Button.Activated) then
			return true
		end

		pcall(firesignal, Button.MouseButton1Down)
		if pcall(firesignal, Button.MouseButton1Click) then
			return true
		end
		if pcall(firesignal, Button.MouseButton1Up) then
			return true
		end
	end

	local Success = pcall(function()
		Button:Activate()
	end)
	return Success
end

local function FindNoobButton(CharacterSelectionScreen)
	if not CharacterSelectionScreen then
		return nil
	end

	local Descendants = CharacterSelectionScreen:GetDescendants()
	for Index = 1, #Descendants do
		local CharacterSelectionEntry = Descendants[Index]
		if CharacterSelectionEntry.Name == CharacterSelectionEntryName and CharacterSelectionEntry:FindFirstChild(NoobCharacterName, true) then
			local Button = CharacterSelectionEntry:FindFirstChild(ButtonName, true)
			if Button and Button:IsA("GuiButton") then
				return Button
			end
		end
	end

	return nil
end

local function FindEquipButton(CharacterSelectionScreen)
	if not CharacterSelectionScreen then
		return nil
	end

	local CharacterSelectionHeader = CharacterSelectionScreen:FindFirstChild(CharacterSelectionHeaderName, true)
	if not CharacterSelectionHeader then
		return nil
	end

	local EquipContainer = CharacterSelectionHeader:FindFirstChild(CharacterEquipName, true)
	if not EquipContainer then
		return nil
	end

	local Button = EquipContainer:FindFirstChild(ButtonName, true)
	if Button and Button:IsA("GuiButton") and Button.Visible then
		local Label = EquipContainer:FindFirstChild(LabelName, true)
		if Label and Label:IsA("TextLabel") then
			return Button
		end
	end

	return nil
end

local TrySelectNoob = LPH_JIT(function()
	local CharacterName = LocalPlayer:GetAttribute(CharacterAttributeName)
	local CharacterSelectionScreen = FindCharacterSelectionScreen()
	if CharacterSelectionScreen then
		if CharacterName ~= NoobCharacterName then
			ActivateButton(FindNoobButton(CharacterSelectionScreen))
		end

		if ActivateButton(FindEquipButton(CharacterSelectionScreen)) then
			return true
		end
	end

	if CharacterName == NoobCharacterName then
		return true
	end

	local Success = pcall(RequestCharacterChange.FireServer, RequestCharacterChange, NoobCharacterName)
	return Success
end)

local TryActivatePlayButton = LPH_JIT(function()
	local Now = os.clock()
	if Now < PlayActivateCooldownUntil then
		return false
	end

	local CharacterName = LocalPlayer:GetAttribute(CharacterAttributeName)
	if CharacterName ~= NoobCharacterName then
		return false
	end

	local WorldLocation = LocalPlayer:GetAttribute(WorldLocationAttributeName)
	local IsTeleporting = LocalPlayer:GetAttribute(IsTeleportingAttributeName)
	if WorldLocation == TrainingWorldLocation or IsTeleporting == true then
		PlayActivateCooldownUntil = 0
		return true
	end

	local PlayButton = CollectionService:GetTagged(AllStarsPlayButtonTag)[1]
	local PlayButtonClient = PlayButton and PlayButton:FindFirstChild(AllStarsPlayButtonClientName)
	local FireActivate = PlayButtonClient and PlayButtonClient:FindFirstChild(FireActivateName)

	if not FireActivate then
		return false
	end

	PlayActivateCooldownUntil = Now + PlayActivateCooldown
	local Success = pcall(function()
		FireActivate:Invoke()
	end)
	return Success
end)

SetClientAutoRocketLauncherStarted = function(IsStarted)
	if not ClientAutoRocketLauncher or ClientAutoRocketLauncher.IsStarted() == IsStarted then
		return
	end

	local Success, ErrorMessage
	if IsStarted then
		Success, ErrorMessage = ClientAutoRocketLauncher.Start()
	else
		Success, ErrorMessage = ClientAutoRocketLauncher.Stop()
	end

	if not Success and ErrorMessage then
		warn("[ClientAutoRocketLauncher]", ErrorMessage)
	end
end

local function UpdateAutomationControls()
	if AutoRocketToggle then
		AutoRocketToggle:SetText("Bot")
	end

	if Library and type(Library.SetPanicText) == "function" then
		Library:SetPanicText(GlobalEnv.auto and "Disable" or "Enable")
	end
end

local function SetAutoRocketEnabled(Value)
	Value = Value == true
	GlobalEnv.auto = Value
	UpdateAutomationControls()
	DestroyAutoRocketMaid()

	if not Value then
		return
	end

	AutoRocketMaid = Maid.New()
	local CurrentAutoRocketMaid = AutoRocketMaid

	local RetryAt = ServerJoinedAt + ServerHopDelay
		local UpdateCharacterState = nil

	local function RefreshCharacterAutomation()
		if type(UpdateCharacterState) == "function" then
			UpdateCharacterState()
			return
		end

		SetClientAutoRocketLauncherStarted(false)
	end

	local function BindCharacter(Character)
		CurrentAutoRocketMaid.CharacterMaid = nil
		UpdateCharacterState = nil
		SetClientAutoRocketLauncherStarted(false)

		if not Character then
			return
		end

		local CharacterMaid = Maid.New()
		local LockedHumanoid = nil
		local LockedRootCFrame = nil
		local LockedRootPart = nil
		local OriginalAutoRotate = nil
		local OriginalJumpHeight = nil
		local OriginalJumpPower = nil
		local OriginalRootPartAnchored = nil
		local OriginalWalkSpeed = nil

		CurrentAutoRocketMaid.CharacterMaid = CharacterMaid

		local function RestoreHumanoidMovement()
			local CurrentHumanoid = LockedHumanoid
			local CurrentRootPart = LockedRootPart
			local CurrentAutoRotate = OriginalAutoRotate
			local CurrentJumpHeight = OriginalJumpHeight
			local CurrentJumpPower = OriginalJumpPower
			local CurrentWalkSpeed = OriginalWalkSpeed
			local CurrentRootPartAnchored = OriginalRootPartAnchored

			LockedHumanoid = nil
			LockedRootCFrame = nil
			LockedRootPart = nil
			OriginalAutoRotate = nil
			OriginalJumpHeight = nil
			OriginalJumpPower = nil
			OriginalRootPartAnchored = nil
			OriginalWalkSpeed = nil

			if CurrentRootPart then
				pcall(function()
					CurrentRootPart.Anchored = CurrentRootPartAnchored == true
					CurrentRootPart.AssemblyAngularVelocity = Vector3.zero
					CurrentRootPart.AssemblyLinearVelocity = Vector3.zero
				end)
			end

			if CurrentHumanoid then
				pcall(function()
					CurrentHumanoid.AutoRotate = CurrentAutoRotate
					CurrentHumanoid.JumpHeight = CurrentJumpHeight
					CurrentHumanoid.JumpPower = CurrentJumpPower
					CurrentHumanoid.WalkSpeed = CurrentWalkSpeed
					CurrentHumanoid:Move(Vector3.zero)
				end)
			end
		end

		local function SetHumanoidMovementLocked(IsLocked)
			if not IsLocked then
				RestoreHumanoidMovement()
				return
			end

			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local RootPart = Character:FindFirstChild(HumanoidRootPartName)
			if RootPart and not RootPart:IsA("BasePart") then
				RootPart = nil
			end

			if not Humanoid and not RootPart then
				return
			end

			if LockedHumanoid ~= Humanoid or LockedRootPart ~= RootPart then
				RestoreHumanoidMovement()
				LockedHumanoid = Humanoid
				LockedRootPart = RootPart

				if Humanoid then
					OriginalAutoRotate = Humanoid.AutoRotate
					OriginalJumpHeight = Humanoid.JumpHeight
					OriginalJumpPower = Humanoid.JumpPower
					OriginalWalkSpeed = Humanoid.WalkSpeed
				end

				if RootPart then
					OriginalRootPartAnchored = RootPart.Anchored
					LockedRootCFrame = RootPart.CFrame
				end
			end

			if Humanoid then
				Humanoid.AutoRotate = false
				Humanoid.JumpHeight = 0
				Humanoid.JumpPower = 0
				Humanoid.WalkSpeed = 0
				Humanoid:Move(Vector3.zero)
			end

			if RootPart then
				if LockedRootCFrame then
					Character:PivotTo(LockedRootCFrame)
				end

				RootPart.AssemblyAngularVelocity = Vector3.zero
				RootPart.AssemblyLinearVelocity = Vector3.zero
				RootPart.Anchored = true
			end
		end

		CharacterMaid:GiveTask(RestoreHumanoidMovement)
		CharacterMaid:GiveTask(RunService.Heartbeat:Connect(function()
			if LockedRootPart and LockedRootCFrame then
				Character:PivotTo(LockedRootCFrame)
				LockedRootPart.AssemblyAngularVelocity = Vector3.zero
				LockedRootPart.AssemblyLinearVelocity = Vector3.zero
				LockedRootPart.Anchored = true
			end
		end))

		UpdateCharacterState = function()
			local CharacterName = LocalPlayer:GetAttribute(CharacterAttributeName)
			local WorldLocation = LocalPlayer:GetAttribute(WorldLocationAttributeName)
			local IsTeleporting = LocalPlayer:GetAttribute(IsTeleportingAttributeName)
			local IsStarted = Character == LocalPlayer.Character
				and CharacterName == NoobCharacterName
				and WorldLocation == TrainingWorldLocation
				and IsTeleporting ~= true

			SetClientAutoRocketLauncherStarted(IsStarted)
			SetHumanoidMovementLocked(IsStarted)
		end

		CharacterMaid:GiveTask(Character.DescendantAdded:Connect(function(Descendant)
			if Descendant:IsA("Humanoid") or (Descendant.Name == HumanoidRootPartName and Descendant:IsA("BasePart")) then
				UpdateCharacterState()
			end
		end))

		CharacterMaid:GiveTask(function()
			if UpdateCharacterState then
				UpdateCharacterState = nil
			end
		end)

		UpdateCharacterState()
	end

		local function EnableAntiAfk()
			CurrentAutoRocketMaid:GiveTask(LocalPlayer.Idled:Connect(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new(0, 0))
			end))
		end

		CurrentAutoRocketMaid:GiveTask(function()
			SetClientAutoRocketLauncherStarted(false)
			UpdateCharacterState = nil
		end)

	CurrentAutoRocketMaid:GiveTask(LocalPlayer:GetAttributeChangedSignal(CharacterAttributeName):Connect(function()
		TrySelectNoob()
		TryActivatePlayButton()
		RefreshCharacterAutomation()
	end))
	CurrentAutoRocketMaid:GiveTask(LocalPlayer:GetAttributeChangedSignal(WorldLocationAttributeName):Connect(function()
		TryActivatePlayButton()
		RefreshCharacterAutomation()
	end))
	CurrentAutoRocketMaid:GiveTask(LocalPlayer:GetAttributeChangedSignal(IsTeleportingAttributeName):Connect(function()
		TryActivatePlayButton()
		RefreshCharacterAutomation()
	end))
	CurrentAutoRocketMaid:GiveTask(CollectionService:GetInstanceAddedSignal(AllStarsPlayButtonTag):Connect(function()
		TryActivatePlayButton()
	end))
	CurrentAutoRocketMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(BindCharacter))
	CurrentAutoRocketMaid:GiveTask(LocalPlayer.CharacterRemoving:Connect(function()
		BindCharacter(nil)
	end))
	CurrentAutoRocketMaid:GiveTask(CoreGui.DescendantAdded:Connect(function(Descendant)
		if Descendant.Name ~= ErrorPromptName then
			return
		end

		local Parent = Descendant.Parent
		if not Parent or Parent.Name ~= PromptOverlayName then
			return
		end

		local PromptGui = Parent.Parent
		if not PromptGui or PromptGui.Name ~= RobloxPromptGuiName then
			return
		end

		TryRejoin()
	end))
	CurrentAutoRocketMaid:GiveTask(task.spawn(function()
		while AutoRocketMaid == CurrentAutoRocketMaid do
			local Now = os.clock()

			TrySelectNoob()
			TryActivatePlayButton()

			if Now >= RetryAt then
				if TryServerHop() then
					return
				end

				RetryAt = Now + ServerActionRetryDelay
			end

			task.wait(ServerActionCheckDelay)
		end
	end))

	EnableAntiAfk()
	TrySelectNoob()
	TryActivatePlayButton()
	BindCharacter(LocalPlayer.Character)
end

local function LoadDependencies()
	RequestCharacterChange = ReplicatedStorage:WaitForChild(RemotesName):WaitForChild(CharacterSelectionServiceRemoteFolderName):WaitForChild(RequestCharacterChangeEventName)

	Maid = GlobalEnv.Maid
	if type(Maid) ~= "table" or type(Maid.IsStarted) ~= "function" then
		Maid = loadstring(game:HttpGet(Repo .. "dependency/maid.lua"))()
		GlobalEnv.Maid = Maid
		LoadedMaid = true
	end

	Signal = GlobalEnv.Signal
	if type(Signal) ~= "table" or type(Signal.IsStarted) ~= "function" then
		Signal = loadstring(game:HttpGet(Repo .. "dependency/signal.lua"))()
		GlobalEnv.Signal = Signal
		LoadedSignal = true
	end

	Library = loadstring(game:HttpGet(Repo .. "dependency/library.lua"))()
	ClientAutoRocketLauncher = loadstring(game:HttpGet(Repo .. "modules/clientautorocketlauncher.lua"))()
	ClientConsoleSuppressor = loadstring(game:HttpGet(Repo .. "modules/clientconsolesuppressor.lua"))()
	ClientDisableTelemetry = loadstring(game:HttpGet(Repo .. "modules/clientdisabletelemetry.lua"))()
end

local function StartDependencies()
	if not Maid.IsStarted() then
		local Success, ErrorMessage = StartModule(Maid, "Maid")
		if not Success then
			return false, ErrorMessage
		end

		StartedMaid = true
	end

	if not Signal.IsStarted() then
		local Success, ErrorMessage = StartModule(Signal, "Signal")
		if not Success then
			return false, ErrorMessage
		end

		StartedSignal = true
	end

	do
		local Success, ErrorMessage = StartModule(ClientDisableTelemetry, "ClientDisableTelemetry")
		if not Success then
			return false, ErrorMessage
		end
	end

	do
		if GlobalEnv[ConsoleSuppressorFlagName] then
			local Success, ErrorMessage = StartModule(ClientConsoleSuppressor, "ClientConsoleSuppressor")
			if not Success then
				return false, ErrorMessage
			end
		else
			StopModule(ClientConsoleSuppressor, "ClientConsoleSuppressor")
		end
	end

	return true
end

local function CreateUi()
	GlobalEnv[BartholomortGuiKeyName] = Library

	Library:Init({
		Version = "1.0",
		Title = "[ PRESS RSHIFT TO TOGGLE UI ]",
		Company = "Project Quenty",
		BarColor = Color3.fromRGB(0, 0, 0),
		RainbowEnabled = false,
		Key = Enum.KeyCode.RightShift,
		BlurEffect = true,
	})

	MainTab = Library:NewTab("Main")
	MainTab:NewSection("Automation")
	AutoRocketToggle = MainTab:NewToggle("Bot", false, SetAutoRocketEnabled)

	if type(Library.SetPanicFunction) == "function" then
		Library:SetPanicFunction(function()
			if AutoRocketToggle then
				AutoRocketToggle:Set(not GlobalEnv.auto)
				return
			end
			SetAutoRocketEnabled(not GlobalEnv.auto)
		end)
	end

	Library.Removing:Connect(Unload)
	MainTab:Open()
	Library:ShowUI(true)
	AutoRocketToggle:Set(GlobalEnv.auto)
	UpdateAutomationControls()
end

EnsureAutoFlag()
EnsureConsoleSuppressorFlag()
LoadDependencies()

local StartedDependencies, StartError = StartDependencies()
if not StartedDependencies then
	Unload()
	error(StartError)
end

local UiSuccess, UiError = pcall(CreateUi)
if not UiSuccess then
	Unload()
	error(UiError)
end

local CloneRef = cloneref or function(a)return a end

local Services = setmetatable({}, {
	__index = function(self, Name: string)
		local Service = CloneRef(game:GetService(Name))
		rawset(self, Name, Service)
		return Service
	end,
})

local Player = Services.Players.LocalPlayer
local Mouse = CloneRef(Player:GetMouse())

local UserInputService = Services.UserInputService
local TextService = Services.TextService
local TweenService = Services.TweenService
local RunService = Services.RunService
local CoreGui = RunService:IsStudio() and CloneRef(Player:WaitForChild("PlayerGui")) or Services.CoreGui
local TeleportService = Services.TeleportService
local Workspace = Services.Workspace
local CurrentCam = Workspace.CurrentCamera

local HiddenUI = get_hidden_gui or gethui or function(a)return CoreGui end
local HiddenUIParent = HiddenUI()
local ScreenDisplayOrder = 1000000
local NotificationDisplayOrder = ScreenDisplayOrder + 1
local WatermarkDisplayOrder = ScreenDisplayOrder + 2
local IntroductionDisplayOrder = ScreenDisplayOrder + 3

local OptionStates = {}
local Library = {
	Title = "Bartholomort",
	Company = "Company",
	CurrentTab = "",
	IsFirst = true,
	PanicText = "Panic",

	RainbowEnabled = true,
	BlurEffect = true,
	BlurSize = 24,
	FieldOfView = CurrentCam.FieldOfView,

	Key = UserInputService.TouchEnabled and Enum.KeyCode.P or Enum.KeyCode.RightShift,
	Fps = 0,
	Debug = true,
	LogoImageUrl = nil,
	LogoImageAsset = nil,
	LogoImageSize = UDim2.fromScale(1, 1),

	Transparency = 0,
	BackgroundColor = Color3.fromRGB(31, 31, 31),
	BarColor = nil,
	HeaderColor = Color3.fromRGB(255, 255, 255),
	CompanyColor = Color3.fromRGB(163, 151, 255),
	AcientColor = Color3.fromRGB(167, 154, 121),
	DarkGray = Color3.fromRGB(27, 27, 27),
	LightGray = Color3.fromRGB(48, 48, 48),

	Font = Enum.Font.Code,

	RainbowColors = ColorSequence.new{
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(241, 137, 53)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(241, 53, 106)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(133, 53, 241)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(53, 186, 241))
	}
}

local function Warn(...)
	if not Library.Debug then return end
	warn("Bartholomort:", ...)
end

local GlobalEnv = getgenv and getgenv() or _G

local function CleanupResource(Resource)
	if Resource == nil then
		return
	end

	local ResourceType = typeof(Resource)
	if ResourceType == "RBXScriptConnection" then
		Resource:Disconnect()
		return
	end

	if ResourceType == "Instance" then
		Resource:Destroy()
		return
	end

	if ResourceType == "function" then
		Resource()
		return
	end

	if type(Resource) == "table" then
		if type(Resource.DoCleaning) == "function" then
			Resource:DoCleaning()
			return
		end

		if type(Resource.Destroy) == "function" then
			Resource:Destroy()
		end
	end
end

local function StartModule(ModuleTable)
	if type(ModuleTable) ~= "table" then
		return false
	end

	local IsStarted = true
	if type(ModuleTable.IsStarted) == "function" then
		local Success, Result = pcall(ModuleTable.IsStarted)
		IsStarted = Success and Result or false
	end

	if IsStarted then
		return true
	end

	if type(ModuleTable.Start) ~= "function" then
		return false
	end

	local Success, Result = pcall(ModuleTable.Start)
	if not Success then
		Warn("Failed to start global module", Result)
		return false
	end

	return Result ~= false
end

local function CreateFallbackMaid()
	local MaidObject = {
		Tasks = {},
	}

	function MaidObject:GiveTask(TaskItem)
		if TaskItem == nil then
			return nil
		end

		self.Tasks[#self.Tasks + 1] = TaskItem
		return TaskItem
	end

	function MaidObject:DoCleaning()
		for Index = #self.Tasks, 1, -1 do
			CleanupResource(self.Tasks[Index])
			self.Tasks[Index] = nil
		end
	end

	MaidObject.Destroy = MaidObject.DoCleaning

	return MaidObject
end

local function CreateFallbackSignal()
	local SignalObject = {
		Connections = {},
	}

	function SignalObject:Connect(Callback)
		local Connection = {
			Connected = true,
		}

		function Connection:Disconnect()
			if not self.Connected then
				return
			end

			self.Connected = false
			SignalObject.Connections[self] = nil
		end

		Connection.Destroy = Connection.Disconnect
		SignalObject.Connections[Connection] = Callback

		return Connection
	end

	function SignalObject:Fire(...)
		for Connection, Callback in next, self.Connections do
			if Connection.Connected then
				Callback(...)
			end
		end
	end

	function SignalObject:DisconnectAll()
		for Connection in next, self.Connections do
			Connection:Disconnect()
		end
	end

	SignalObject.Destroy = SignalObject.DisconnectAll

	return SignalObject
end

local Maid = rawget(GlobalEnv, "Maid")
local Signal = rawget(GlobalEnv, "Signal")

StartModule(Maid)
StartModule(Signal)

local function CreateCleanupMaid()
	if type(Maid) == "table" then
		local Constructor = Maid.New or Maid.new
		if type(Constructor) == "function" then
			local Success, MaidObject = pcall(Constructor)
			if Success and type(MaidObject) == "table" then
				return MaidObject
			end
		end
	end

	return CreateFallbackMaid()
end

local function CreateCleanupSignal()
	if type(Signal) == "table" then
		local Constructor = Signal.New or Signal.new
		if type(Constructor) == "function" then
			local Success, SignalObject = pcall(Constructor)
			if Success and type(SignalObject) == "table" then
				return SignalObject
			end
		end
	end

	return CreateFallbackSignal()
end

local function TrackTask(MaidObject, TaskItem)
	if MaidObject == nil or TaskItem == nil then
		return TaskItem
	end

	if type(MaidObject.GiveTask) == "function" then
		MaidObject:GiveTask(TaskItem)
	elseif type(MaidObject.Add) == "function" then
		MaidObject:Add(TaskItem)
	end

	return TaskItem
end

local function DoCleaning(MaidObject)
	if MaidObject == nil then
		return
	end

	if type(MaidObject.DoCleaning) == "function" then
		MaidObject:DoCleaning()
	elseif type(MaidObject.Destroy) == "function" then
		MaidObject:Destroy()
	end
end

local function ConnectTracked(MaidObject, SignalObject, Callback)
	if SignalObject == nil or type(SignalObject.Connect) ~= "function" then
		return nil
	end

	local Connection = SignalObject:Connect(Callback)
	TrackTask(MaidObject, Connection)
	return Connection
end

local function FireSignal(SignalObject, ...)
	if SignalObject == nil or type(SignalObject.Fire) ~= "function" then
		return
	end

	pcall(SignalObject.Fire, SignalObject, ...)
end

local function RegisterOptionState(Key, StateValue, Api, MaidObject)
	OptionStates[Key] = {StateValue, Api}
	TrackTask(MaidObject, function()
		OptionStates[Key] = nil
	end)
end

local function NormalizeLogoImageAsset(Asset)
	if Asset == nil then
		return nil
	end

	local AssetString = tostring(Asset):gsub("^%s+", ""):gsub("%s+$", "")
	if AssetString == "" then
		return nil
	end

	if AssetString:match("^rbxassetid://") or AssetString:match("^rbxthumb://") or AssetString:match("^rbxasset://") then
		return AssetString
	end

	local AssetId = AssetString:match("[?&]id=(%d+)") or AssetString:match("(%d+)$")
	if AssetId then
		return "rbxassetid://" .. AssetId
	end

	return AssetString
end

Library._CleanupMaid = CreateCleanupMaid()
Library._SignalMaid = CreateCleanupMaid()
Library.Removing = CreateCleanupSignal()
Library.Removed = CreateCleanupSignal()

TrackTask(Library._SignalMaid, Library.Removing)
TrackTask(Library._SignalMaid, Library.Removed)
TrackTask(Library._CleanupMaid, function()
	if GlobalEnv.BartholomortGUI == Library then
		GlobalEnv.BartholomortGUI = nil
	end
end)

if GlobalEnv.BartholomortGUI then
	pcall(function()
		GlobalEnv.BartholomortGUI:Remove()
	end)
end
GlobalEnv.BartholomortGUI = Library

local Blur = Instance.new("BlurEffect", CurrentCam)
Blur.Enabled = true
Blur.Size = 0
TrackTask(Library._CleanupMaid, Blur)
ConnectTracked(Library._CleanupMaid, Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
	CurrentCam = Workspace.CurrentCamera
	if CurrentCam and Blur.Parent ~= CurrentCam then
		Blur.Parent = CurrentCam
	end
end)

local TweenWrapper = {}

function TweenWrapper:Init()
	self.RealStyles = {
		Default = {
			TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
		}
	}
	self.Styles = setmetatable({}, {
		__index = function(_, Key)
			local Value = self.RealStyles[Key]
			if not Value then
				Warn(`No Tween style for {Key}, returning default`)
				return self.RealStyles.Default
			end
			return Value
		end,
	})
end

function TweenWrapper:CreateStyle(Name, Speed, ...)
	if not Name then
		return TweenInfo.new(0)
	end

	local Tweeninfo = TweenInfo.new(
		Speed or 0.17,
		...
	)

	self.RealStyles[Name] = Tweeninfo
	return Tweeninfo
end

TweenWrapper:Init()

local function EnableDrag(Object, Latency, MaidObject)
	if not Object then
		return
	end
	Latency = Latency or 0.06

	local Toggled = false
	local InputObject = nil
	local StartPosition = nil
	local InitialPosition = Object.Position
	local DragTween = nil
	local DragTweenInfo = TweenInfo.new(Latency)

	local function InputIsAccepted(Input)
		local UserInputType = Input.UserInputType

		if UserInputType == Enum.UserInputType.Touch then return true end
		if UserInputType == Enum.UserInputType.MouseButton1 then return true end

		return false
	end

	ConnectTracked(MaidObject, Object.InputBegan, function(Input)
		if not InputIsAccepted(Input) then return end

		Toggled = true
		InputObject = Input
		StartPosition = Input.Position
		InitialPosition = Object.Position
	end)

	ConnectTracked(MaidObject, Object.InputChanged, function(Input)
		local MouseMovement = Input.UserInputType == Enum.UserInputType.MouseMovement
		if not MouseMovement and not InputIsAccepted(Input) then return end

		InputObject = Input
	end)

	ConnectTracked(MaidObject, UserInputService.InputEnded, function(Input)
		if Input == InputObject then
			Toggled = false
			InputObject = nil
		end
	end)

	ConnectTracked(MaidObject, UserInputService.InputChanged, function(Input)
		if Input == InputObject and Toggled and StartPosition then
			local Delta = InputObject.Position - StartPosition
			local Position = UDim2.new(InitialPosition.X.Scale, InitialPosition.X.Offset + Delta.X, InitialPosition.Y.Scale, InitialPosition.Y.Offset + Delta.Y)
			if DragTween then
				DragTween:Cancel()
			end
			DragTween = TweenService:Create(Object, DragTweenInfo, {Position = Position})
			DragTween:Play()
		end
	end)

	TrackTask(MaidObject, function()
		if DragTween then
			DragTween:Cancel()
			DragTween = nil
		end
	end)
end

ConnectTracked(Library._CleanupMaid, RunService.RenderStepped, function(v)
	Library.Fps = math.round(1 / v)
end)

function Library:RoundNumber(Digits, Value)
	return tonumber(string.format("%." .. (Digits or 0) .. "f", Value))
end

function Library:GetUsername()
	return Player.Name
end

function Library:Panic()
	for Frame, Data in next, OptionStates do
		local Functions = Data[2]
		local State = Data[1]

		Functions:Set(State)
	end
	return self
end

function Library:SetPanicText(Text)
	Text = Text or "Panic"
	self.PanicText = Text
	if self._PanicButton then
		self._PanicButton.Text = Text
	end
	return self
end

function Library:SetPanicFunction(Callback)
	if type(Callback) == "function" then
		self._PanicCallback = Callback
	else
		self._PanicCallback = nil
	end
	return self
end

function Library:SetKeybind(NewKey)
	Library.Key = NewKey
	return self
end

function Library:IsGameLoaded()
	return game:IsLoaded()
end

function Library:GetUserId()
	return Player.UserId
end

function Library:GetPlaceId()
	return game.PlaceId
end

function Library:GetJobId()
	return game.JobId
end

function Library:Rejoin()
	TeleportService:TeleportToPlaceInstance(
		Library:GetPlaceId(),
		Library:GetJobId(),
		Library:GetUserId()
	)
end

function Library:Copy(Input)
	local ClipboardFunction = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
	if ClipboardFunction then
		ClipboardFunction(Input)
	end
end

function Library:GetDay(FormatType)
	if FormatType == "word" then
		return os.date("%A")
	elseif FormatType == "short" then
		return os.date("%a")
	elseif FormatType == "month" then
		return os.date("%d")
	elseif FormatType == "year" then
		return os.date("%j")
	end

	return nil
end

function Library:GetTime(FormatType)
	if FormatType == "24h" then
		return os.date("%H")
	elseif FormatType == "12h" then
		return os.date("%I")
	elseif FormatType == "minute" then
		return os.date("%M")
	elseif FormatType == "half" then
		return os.date("%p")
	elseif FormatType == "second" then
		return os.date("%S")
	elseif FormatType == "full" then
		return os.date("%X")
	elseif FormatType == "ISO" then
		return os.date("%z")
	elseif FormatType == "zone" then
		return os.date("%Z")
	end

	return nil
end

function Library:GetMonth(FormatType)
	if FormatType == "word" then
		return os.date("%B")
	elseif FormatType == "short" then
		return os.date("%b")
	elseif FormatType == "digit" then
		return os.date("%m")
	end

	return nil
end

function Library:GetWeek(FormatType)
	if FormatType == "year_S" then
		return os.date("%U")
	elseif FormatType == "day" then
		return os.date("%w")
	elseif FormatType == "year_M" then
		return os.date("%W")
	end

	return nil
end

function Library:GetYear(FormatType)
	if FormatType == "digits" then
		return os.date("%y")
	elseif FormatType == "full" then
		return os.date("%Y")
	end

	return nil
end

function Library:UnlockFps(NewCap)
	if setfpscap then
		setfpscap(NewCap)
	end
end

TweenWrapper:CreateStyle("Rainbow", 5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
function Library:ApplyRainbow(InstanceObject, Wave)
	local Colors = Library.RainbowColors
	local RainbowEnabled = Library.RainbowEnabled

	if not RainbowEnabled then return end

	if not Wave then
		InstanceObject.BackgroundColor3 = Colors.Keypoints[1].Value
		TweenService:Create(InstanceObject, TweenWrapper.Styles["Rainbow"], {
			BackgroundColor3 =  Colors.Keypoints[#Colors.Keypoints].Value
		}):Play()

		return
	end

	local Gradient = Instance.new("UIGradient", InstanceObject)
	Gradient.Offset = Vector2.new(-0.8, 0)
	Gradient.Color = Colors

	TweenService:Create(Gradient, TweenWrapper.Styles["Rainbow"], {
		Offset = Vector2.new(0.8, 0)
	}):Play()
end

function Library:SetLogoImageUrl(Url)
	Library.LogoImageUrl = Url
	Library.LogoImageAsset = nil
	return self
end

function Library:SetLogoImageAsset(Asset)
	Library.LogoImageAsset = NormalizeLogoImageAsset(Asset)
	return self
end

function Library:ResolveLogoImageAsset()
	if type(Library.LogoImageAsset) == "string" and Library.LogoImageAsset ~= "" then
		return NormalizeLogoImageAsset(Library.LogoImageAsset)
	end

	return NormalizeLogoImageAsset(Library.LogoImageUrl)
end

TweenWrapper:CreateStyle("wm", 0.24)
TweenWrapper:CreateStyle("wm_2", 0.04)

function Library:Init(Config)

	for Key, Value in next, Config do
		Library[Key] = Value
	end

	self.CurrentTab = ""
	self.IsFirst = true
	self._PanicButton = nil

	if self._InitMaid then
		DoCleaning(self._InitMaid)
	end

	local InitMaid = CreateCleanupMaid()
	self._InitMaid = InitMaid
	TrackTask(self._CleanupMaid, InitMaid)

		local Watermark = Instance.new("ScreenGui", HiddenUIParent)
		Watermark.DisplayOrder = WatermarkDisplayOrder
		Watermark.IgnoreGuiInset = true
		Watermark.ResetOnSpawn = false
		Watermark.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		TrackTask(InitMaid, Watermark)

	local WatermarkPadding = Instance.new("UIPadding")
	WatermarkPadding.Parent = Watermark
	WatermarkPadding.PaddingBottom = UDim.new(0, 6)
	WatermarkPadding.PaddingLeft = UDim.new(0, 6)

	local WatermarkLayout = Instance.new("UIListLayout")
	WatermarkLayout.Parent = Watermark
	WatermarkLayout.FillDirection = Enum.FillDirection.Horizontal
	WatermarkLayout.SortOrder = Enum.SortOrder.LayoutOrder
	WatermarkLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	WatermarkLayout.Padding = UDim.new(0, 4)

	function Library:Watermark(Text)
		local Edge = Instance.new("Frame")
		local EdgeCorner = Instance.new("UICorner")
		local Background = Instance.new("Frame")
		local BarFolder = Instance.new("Folder")
		local Bar = Instance.new("Frame")
		local BarCorner = Instance.new("UICorner")
		local BarLayout = Instance.new("UIListLayout")
		local BackgroundGradient = Instance.new("UIGradient")
		local BackgroundCorner = Instance.new("UICorner")
		local WaterText = Instance.new("TextLabel")
		local WaterPadding = Instance.new("UIPadding")
		local BackgroundLayout = Instance.new("UIListLayout")

		Edge.Parent = Watermark
		Edge.AnchorPoint = Vector2.new(0.5, 0.5)
		Edge.BackgroundColor3 = Library.BackgroundColor
		Edge.Position = UDim2.new(0.5, 0, -0.03, 0)
		Edge.Size = UDim2.new(0, 0, 0, 26)
		Edge.BackgroundTransparency = 1

		EdgeCorner.CornerRadius = UDim.new(0, 2)
		EdgeCorner.Parent = Edge

		Background.Parent = Edge
		Background.AnchorPoint = Vector2.new(0.5, 0.5)
		Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Background.BackgroundTransparency = 1
		Background.ClipsDescendants = true
		Background.Position = UDim2.new(0.5, 0, 0.5, 0)
		Background.Size = UDim2.new(0, 0, 0, 24)

		BarFolder.Parent = Background

		Bar.Parent = BarFolder
			Bar.BackgroundColor3 = Library.BarColor or Library.AcientColor
		Bar.BackgroundTransparency = 0
		Bar.Size = UDim2.new(0, 0, 0, 2)

		self:ApplyRainbow(Bar, false)

		BarCorner.CornerRadius = UDim.new(0, 2)
		BarCorner.Parent = Bar

		BarLayout.Parent = BarFolder
		BarLayout.SortOrder = Enum.SortOrder.LayoutOrder

		BackgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
		BackgroundGradient.Rotation = 90
		BackgroundGradient.Parent = Background

		BackgroundCorner.CornerRadius = UDim.new(0, 2)
		BackgroundCorner.Parent = Background

		WaterText.Parent = Background
		WaterText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		WaterText.BackgroundTransparency = 1.000
		WaterText.Position = UDim2.new(0, 0, -0.0416666679, 0)
		WaterText.Size = UDim2.new(0, 0, 0, 24)
		WaterText.Font = Library.Font
		WaterText.Text = Text
		WaterText.TextColor3 = Color3.fromRGB(198, 198, 198)
		WaterText.TextTransparency = 1
		WaterText.TextSize = 14.000
		WaterText.RichText = true

		local NewSize = TextService:GetTextSize(WaterText.Text, WaterText.TextSize, WaterText.Font, Vector2.new(math.huge, math.huge))
		WaterText.Size = UDim2.new(0, NewSize.X + 8, 0, 24)

		WaterPadding.Parent = WaterText
		WaterPadding.PaddingBottom = UDim.new(0, 4)
		WaterPadding.PaddingLeft = UDim.new(0, 4)
		WaterPadding.PaddingRight = UDim.new(0, 4)
		WaterPadding.PaddingTop = UDim.new(0, 4)

		BackgroundLayout.Parent = Background
		BackgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
		BackgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

		coroutine.wrap(function()
			TweenService:Create(Edge, TweenWrapper.Styles["wm"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(Edge, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["wm"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
			wait(.2)
			TweenService:Create(Bar, TweenWrapper.Styles["wm"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
			wait(.1)
			TweenService:Create(WaterText, TweenWrapper.Styles["wm"], {TextTransparency = 0}):Play()
		end)()

		local WatermarkFunctions = {}

		function WatermarkFunctions:Hide()
			Edge.Visible = false
			return self
		end

		function WatermarkFunctions:Show()
			Edge.Visible = true
			return self
		end

		function WatermarkFunctions:SetText(NewText)
			NewText = NewText or Text
			WaterText.Text = NewText

			local NewSize = TextService:GetTextSize(WaterText.Text, WaterText.TextSize, WaterText.Font, Vector2.new(math.huge, math.huge))
			coroutine.wrap(function()
				TweenService:Create(Edge, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 10, 0, 26)}):Play()
				TweenService:Create(Background, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 24)}):Play()
				TweenService:Create(Bar, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
				TweenService:Create(WaterText, TweenWrapper.Styles["wm_2"], {Size = UDim2.new(0, NewSize.x + 8, 0, 1)}):Play()
			end)()

			return self
		end

		function WatermarkFunctions:Remove()
			Watermark:Destroy()
			return self
		end
		return WatermarkFunctions
	end

			local Notifications = Instance.new("ScreenGui", HiddenUIParent)
		TrackTask(InitMaid, Notifications)
		local NotificationsLayout = Instance.new("UIListLayout", Notifications)
		local NotificationsPadding = Instance.new("UIPadding", Notifications)

		Notifications.DisplayOrder = NotificationDisplayOrder
		Notifications.IgnoreGuiInset = true
		Notifications.ResetOnSpawn = false
		Notifications.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	NotificationsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	NotificationsLayout.Padding = UDim.new(0, 4)

	NotificationsPadding.PaddingLeft = UDim.new(0, 6)
	NotificationsPadding.PaddingTop = UDim.new(0, 18)

	function Library:Notify(Text, Duration, NotificationType, Callback)
		TweenWrapper:CreateStyle("notification_load", 0.2)

		Text = tostring(Text)
		Duration = Duration or 5
		NotificationType = NotificationType or "notification"
		Callback = Callback or function() end

		local Edge = Instance.new("Frame", Notifications)
		local EdgeCorner = Instance.new("UICorner")
		local Background = Instance.new("Frame")
		local BarFolder = Instance.new("Folder")
		local Bar = Instance.new("Frame")
		local BarCorner = Instance.new("UICorner")
		local BarLayout = Instance.new("UIListLayout")
		local BackgroundGradient = Instance.new("UIGradient")
		local BackgroundCorner = Instance.new("UICorner")
		local NotificationText = Instance.new("TextLabel")
		local NotificationPadding = Instance.new("UIPadding")
		local BackgroundLayout = Instance.new("UIListLayout")

		Edge.BackgroundColor3 = Library.BackgroundColor
		Edge.BackgroundTransparency = 1.000
		Edge.Size = UDim2.new(0, 0, 0, 26)

		EdgeCorner.CornerRadius = UDim.new(0, 2)
		EdgeCorner.Parent = Edge

		Background.Parent = Edge
		Background.AnchorPoint = Vector2.new(0.5, 0.5)
		Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Background.BackgroundTransparency = 1.000
		Background.ClipsDescendants = true
		Background.Position = UDim2.new(0.5, 0, 0.5, 0)
		Background.Size = UDim2.new(0, 0, 0, 24)

		BarFolder.Parent = Background

		Bar.Parent = BarFolder
			Bar.BackgroundColor3 = Library.BarColor or Library.AcientColor
		Bar.BackgroundTransparency = 0.200
		Bar.Size = UDim2.new(0, 0, 0, 1)

		if NotificationType == "alert" then
			Bar.BackgroundColor3 = Color3.fromRGB(255, 246, 112)
		elseif NotificationType == "error" then
			Bar.BackgroundColor3 = Color3.fromRGB(255, 74, 77)
		elseif NotificationType == "success" then
			Bar.BackgroundColor3 = Color3.fromRGB(131, 255, 103)
		else
			Library:ApplyRainbow(Bar, false)
		end

		BarCorner.CornerRadius = UDim.new(0, 2)
		BarCorner.Parent = Bar

		BarLayout.Parent = BarFolder
		BarLayout.SortOrder = Enum.SortOrder.LayoutOrder

		BackgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
		BackgroundGradient.Rotation = 90
		BackgroundGradient.Parent = Background

		BackgroundCorner.CornerRadius = UDim.new(0, 2)
		BackgroundCorner.Parent = Background

		NotificationText.Parent = Background
		NotificationText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		NotificationText.BackgroundTransparency = 1.000
		NotificationText.Size = UDim2.new(0, 230, 0, 26)
		NotificationText.Font = Library.Font
		NotificationText.Text = Text
		NotificationText.TextColor3 = Color3.fromRGB(198, 198, 198)
		NotificationText.TextSize = 14.000
		NotificationText.TextTransparency = 1.000
		NotificationText.TextXAlignment = Enum.TextXAlignment.Left
		NotificationText.RichText = true

		NotificationPadding.Parent = NotificationText
		NotificationPadding.PaddingBottom = UDim.new(0, 4)
		NotificationPadding.PaddingLeft = UDim.new(0, 4)
		NotificationPadding.PaddingRight = UDim.new(0, 4)
		NotificationPadding.PaddingTop = UDim.new(0, 4)

		BackgroundLayout.Parent = Background
		BackgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
		BackgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

		local NewSize = TextService:GetTextSize(NotificationText.Text, NotificationText.TextSize, NotificationText.Font, Vector2.new(math.huge, math.huge))
		TweenWrapper:CreateStyle("notification_wait", Duration, Enum.EasingStyle.Quad)
		local IsRunning = false
		coroutine.wrap(function()
			IsRunning = true
			TweenService:Create(Edge, TweenWrapper.Styles["notification_load"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["notification_load"], {BackgroundTransparency = 0}):Play()
			TweenService:Create(NotificationText, TweenWrapper.Styles["notification_load"], {TextTransparency = 0}):Play()
			TweenService:Create(Edge, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 10, 0, 26)}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
			TweenService:Create(NotificationText, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
			wait()
			local Tween = TweenService:Create(Bar, TweenWrapper.Styles["notification_wait"], {Size = UDim2.new(0, NewSize.X + 8, 0, 1)})
			Tween:Play()
			Tween.Completed:Wait()
			IsRunning = false
			TweenService:Create(Edge, TweenWrapper.Styles["notification_load"], {BackgroundTransparency = 1}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["notification_load"], {BackgroundTransparency = 1}):Play()
			TweenService:Create(NotificationText, TweenWrapper.Styles["notification_load"], {TextTransparency = 1}):Play()
			TweenService:Create(Bar, TweenWrapper.Styles["notification_load"], {BackgroundTransparency = 1}):Play()
			TweenService:Create(Edge, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, 0, 0, 26)}):Play()
			TweenService:Create(Background, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, 0, 0, 24)}):Play()
			TweenService:Create(NotificationText, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, 0, 0, 24)}):Play()
			TweenService:Create(Bar, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, 0, 0, 1)}):Play()
			wait(.2)
			Edge:Destroy()
		end)()

		TweenWrapper:CreateStyle("notification_reset", 0.4)
		local NotificationFunctions = {}
		function NotificationFunctions:SetText(NewText)
			NewText = NewText or Text
			NotificationText.Text = NewText

			NewSize = TextService:GetTextSize(NotificationText.Text, NotificationText.TextSize, NotificationText.Font, Vector2.new(math.huge, math.huge))
				if IsRunning then
				TweenService:Create(Edge, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 10, 0, 26)}):Play()
				TweenService:Create(Background, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
				TweenService:Create(NotificationText, TweenWrapper.Styles["notification_load"], {Size = UDim2.new(0, NewSize.X + 8, 0, 24)}):Play()
				wait()
				TweenService:Create(Bar, TweenWrapper.Styles["notification_reset"], {Size = UDim2.new(0, 0, 0, 1)}):Play()
				wait(.4)
				TweenService:Create(Bar, TweenWrapper.Styles["notification_wait"], {Size = UDim2.new(0, NewSize.X + 8, 0, 1)}):Play()
			end

			return self
		end
		return NotificationFunctions
	end

		local Introduction = Instance.new("ScreenGui", HiddenUIParent)
		TrackTask(InitMaid, Introduction)
	local Background = Instance.new("Frame")
	local LogoText = Instance.new("TextLabel")
	local LogoTextGradient = Instance.new("UIGradient")
	local LogoImage = Instance.new("ImageLabel")
	local Bar = Instance.new("Frame")
	local BarCorner = Instance.new("UICorner")
	local Messages = Instance.new("Frame")
	local LogExample = Instance.new("TextLabel")
	local BackgroundGradient3 = Instance.new("UIGradient")
	local PageLayout = Instance.new("UIListLayout")

		Introduction.DisplayOrder = IntroductionDisplayOrder
		Introduction.IgnoreGuiInset = true
		Introduction.ResetOnSpawn = false
		Introduction.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	Background.Parent = Introduction
	Background.BackgroundTransparency = 1
	Background.AnchorPoint = Vector2.new(0.5, 0.5)
	Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Background.ClipsDescendants = true
	Background.Position = UDim2.new(0.511773348, 0, 0.5, 0)
	Background.Size = UDim2.new(0, 300, 0, 308)

	local IntroStroke = Instance.new("UIStroke", Background)
	IntroStroke.Color = Color3.fromRGB(26, 26, 26)
	IntroStroke.Thickness = 2
	IntroStroke.Transparency = 1

	local BackgroundGradient = Instance.new("UIGradient", Background)
	BackgroundGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	BackgroundGradient.Rotation = 90

	local BackgroundCorner = Instance.new("UICorner", Background)
	BackgroundCorner.CornerRadius = UDim.new(0, 3)

	LogoText.Parent = Background
	LogoText.AnchorPoint = Vector2.new(0.5, 0.5)
	LogoText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	LogoText.BackgroundTransparency = 1.000
	LogoText.TextTransparency = 1
	LogoText.BorderColor3 = Color3.fromRGB(0, 0, 0)
	LogoText.BorderSizePixel = 0
	LogoText.Position = UDim2.new(0.5, 0, 0.5, 0)
	LogoText.Size = UDim2.new(0, 448, 0, 150)
	LogoText.Font = Enum.Font.Unknown
	LogoText.FontFace.Weight = Enum.FontWeight.Bold
	LogoText.Font = Enum.Font.FredokaOne
	LogoText.TextColor3 = Library.AcientColor
	LogoText.TextSize = 100.000

	LogoTextGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(171, 171, 171))}
	LogoTextGradient.Rotation = 90
	LogoTextGradient.Parent = LogoText

	LogoImage.Parent = Background
	LogoImage.AnchorPoint = Vector2.new(0.5, 0.5)
	LogoImage.BackgroundTransparency = 1
	LogoImage.BorderSizePixel = 0
	LogoImage.ImageTransparency = 1
	LogoImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	LogoImage.ScaleType = Enum.ScaleType.Stretch
	LogoImage.Size = Library.LogoImageSize
	LogoImage.Visible = false

	Bar.Parent = Background
	Bar.BackgroundColor3 = Library.BarColor or Library.AcientColor
	Bar.BackgroundTransparency = 1
	Bar.Size = UDim2.new(1, 0, 0, 2)
	Library:ApplyRainbow(Bar, true)

	BarCorner.CornerRadius = UDim.new(0, 2)
	BarCorner.Parent = Bar

	Messages.Parent = Background
	Messages.AnchorPoint = Vector2.new(0.5, 0.5)
	Messages.BackgroundColor3 = Color3.fromRGB(9, 9, 9)
	Messages.BackgroundTransparency = 1
	Messages.BorderColor3 = Color3.fromRGB(0, 0, 0)
	Messages.BorderSizePixel = 1
	Messages.Position = UDim2.new(0.5, 0, 0.5, 0)
	Messages.Size = UDim2.new(1, -30, 1, -30)

	local MessagesUIPadding = Instance.new("UIPadding", Messages)
	MessagesUIPadding.PaddingLeft = UDim.new(0, 6)
	MessagesUIPadding.PaddingTop = UDim.new(0, 3)

	local MessagesUIListLayout = Instance.new("UIListLayout", Messages)
	MessagesUIListLayout.Parent = Messages
	MessagesUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	MessagesUIListLayout.FillDirection = Enum.FillDirection.Vertical
	MessagesUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	MessagesUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	LogExample.Parent = Messages
	LogExample.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	LogExample.BackgroundTransparency = 1.000
	LogExample.BorderColor3 = Color3.fromRGB(0, 0, 0)
	LogExample.BorderSizePixel = 0
	LogExample.Size = UDim2.new(1, 0, 0, 18)
	LogExample.Visible = false
	LogExample.Font = Library.Font
	LogExample.TextColor3 = Color3.fromRGB(255, 255, 255)
	LogExample.TextSize = 18.000
	LogExample.TextTransparency = 1
	LogExample.TextWrapped = true
	LogExample.TextXAlignment = Enum.TextXAlignment.Left
	LogExample.TextYAlignment = Enum.TextYAlignment.Top

	BackgroundGradient3.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(171, 171, 171))}
	BackgroundGradient3.Rotation = 90
	BackgroundGradient3.Parent = LogExample

	PageLayout.Parent = Introduction
	PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	PageLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	TweenWrapper:CreateStyle("Introduction",0.175)
	TweenWrapper:CreateStyle("Introduction end",0.5)

	local function ShowLogoImage(Asset)
		LogoImage.Size = Library.LogoImageSize
		LogoImage.ImageTransparency = 1
		LogoText.Size = UDim2.new(0, 448, 0, 150)
		LogoText.TextSize = 100
		LogoText.TextTransparency = 1

		if type(Asset) == "string" and Asset ~= "" then
			LogoImage.Image = Asset
			LogoImage.Visible = true
			LogoText.Visible = false
			return true
		end

		LogoImage.Image = ""
		LogoImage.Visible = false
		LogoText.Visible = true
		return false
	end

	function Library:BeginIntroduction()
		local LogoAsset = Library:ResolveLogoImageAsset()
		local IsUsingImageLogo = ShowLogoImage(LogoAsset)
		if not IsUsingImageLogo then
			LogoText.Text = Library.Company:sub(1, 1):upper()
		end

		TweenService:Create(Background, TweenWrapper.Styles["Introduction"], {BackgroundTransparency = 0}):Play()
		wait(.2)
		TweenService:Create(IntroStroke, TweenWrapper.Styles["Introduction end"], {Transparency = 0.55}):Play()
		TweenService:Create(Bar, TweenWrapper.Styles["Introduction"], {BackgroundTransparency = 0.2}):Play()
		wait(.3)
		if IsUsingImageLogo then
			TweenService:Create(LogoImage, TweenWrapper.Styles["Introduction"], {ImageTransparency = 0}):Play()
		else
			TweenService:Create(LogoText, TweenWrapper.Styles["Introduction"], {TextTransparency = 0}):Play()
		end

		wait(2)

		if IsUsingImageLogo then
			local LogoTween = TweenService:Create(LogoImage, TweenWrapper.Styles["Introduction"], {ImageTransparency = 1})
			TweenService:Create(LogoImage, TweenInfo.new(1), {Size = UDim2.new(0, 0, 0, 0)}):Play()
			LogoTween:Play()
			LogoTween.Completed:Wait()
		else
			local LogoTween = TweenService:Create(LogoText, TweenWrapper.Styles["Introduction"], {TextTransparency = 1})
			TweenService:Create(LogoText, TweenInfo.new(1), {TextSize = 0}):Play()
			LogoTween:Play()
			LogoTween.Completed:Wait()
		end
	end

	function Library:AddIntroductionMessage(Message)
		if Messages.BackgroundTransparency >= 1 then
			TweenService:Create(Messages, TweenInfo.new(.2), {BackgroundTransparency = 0.55}):Play()
		end

		local Log = LogExample:Clone()
		local OrginalSize = Log.TextSize
		Log.Parent = Messages
		Log.Text = Message
		Log.TextTransparency = 1
		Log.TextSize = OrginalSize*0.9
		Log.Visible = true
		TweenService:Create(Log, TweenInfo.new(1), {TextTransparency = 0}):Play()
		TweenService:Create(Log, TweenInfo.new(.7), {TextSize = OrginalSize}):Play()
		wait(.1)
		return Log
	end

	function Library:EndIntroduction(Message)
		for _, Message in next, Messages:GetChildren() do
			pcall(function()
				TweenService:Create(Message, TweenWrapper.Styles["Introduction end"], {TextTransparency = 1}):Play()
			end)
		end
		wait(0.2)

		TweenService:Create(Messages, TweenWrapper.Styles["Introduction end"], {BackgroundTransparency = 1}):Play()

		TweenService:Create(Background, TweenWrapper.Styles["Introduction end"], {BackgroundTransparency = 1}):Play()
		TweenService:Create(Bar, TweenWrapper.Styles["Introduction end"], {BackgroundTransparency = 1}):Play()
		if LogoImage.Visible then
			TweenService:Create(LogoImage, TweenWrapper.Styles["Introduction end"], {ImageTransparency = 1}):Play()
		else
			TweenService:Create(LogoText, TweenWrapper.Styles["Introduction end"], {TextTransparency = 1}):Play()
		end
		TweenService:Create(IntroStroke, TweenWrapper.Styles["Introduction end"], {Transparency = 1}):Play()
	end

		local Screen = Instance.new("ScreenGui", HiddenUIParent)
		Screen.DisplayOrder = ScreenDisplayOrder
		Screen.IgnoreGuiInset = true
		Screen.ResetOnSpawn = false
		Screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		TrackTask(InitMaid, Screen)

	local MainBackground = Instance.new("Frame", Screen)
	MainBackground.Visible = false
	MainBackground.BorderSizePixel = 0
	MainBackground.AnchorPoint = Vector2.new(0.5, 0.5)
	MainBackground.BackgroundTransparency = Library.Transparency
	MainBackground.BackgroundColor3 = Library.BackgroundColor
	MainBackground.Position = UDim2.new(0.5, 0, 0.5, 0)

	MainBackground.Size = UDim2.fromOffset(594, 406)
	MainBackground.ClipsDescendants = true
	local DragMaid = CreateCleanupMaid()
	TrackTask(InitMaid, DragMaid)
	EnableDrag(MainBackground, 0.1, DragMaid)

	local SizeConstraint = Instance.new("UISizeConstraint")
	SizeConstraint.Parent = MainBackground
	SizeConstraint.MaxSize = Vector2.new(594, 406)
	SizeConstraint.MinSize = Vector2.new(450, 300)

	local BGStroke = Instance.new("UIStroke", MainBackground)
	BGStroke.Color = Color3.fromRGB(26, 26, 26)
	BGStroke.Thickness = 2
	BGStroke.Transparency = 0.55

	local BGGradient = Instance.new("UIGradient", MainBackground)
	BGGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 230, 230))}
	BGGradient.Rotation = 90

	local TabButtons = Instance.new("Frame", MainBackground)
	TabButtons.BackgroundTransparency = 1
	TabButtons.ClipsDescendants = true
	TabButtons.Position = UDim2.new(0, 10, 0, 35)
	TabButtons.Size = UDim2.new(0, 152, 0, 330)

	local TabButtonLayout = Instance.new("UIListLayout", TabButtons)
	TabButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	TabButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local TabButtonPadding = Instance.new("UIPadding", TabButtons)
	TabButtonPadding.PaddingBottom = UDim.new(0, 4)
	TabButtonPadding.PaddingLeft = UDim.new(0, 4)
	TabButtonPadding.PaddingRight = UDim.new(0, 4)
	TabButtonPadding.PaddingTop = UDim.new(0, 4)

	local TabButtonCorner2 = Instance.new("UICorner", TabButtons)
	TabButtonCorner2.CornerRadius = UDim.new(0, 2)

	local Container = Instance.new("Frame", MainBackground)
	Container.AnchorPoint = Vector2.new(1, 0)
	Container.BackgroundTransparency = 1
	Container.Position = UDim2.new(1, -10, 0, 35)
	Container.Size = UDim2.new(0, 414, 0, 360)

	local Header = Instance.new("Frame", MainBackground)
	Header.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Header.BackgroundTransparency = 1.000
	Header.BorderColor3 = Color3.fromRGB(0, 0, 0)
	Header.BorderSizePixel = 0
	Header.Size = UDim2.new(1, 0, 0, 32)

	local Company = Instance.new("TextLabel", Header)
	Company.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Company.BackgroundTransparency = 1.000
	Company.LayoutOrder = 1
	Company.AutomaticSize = Enum.AutomaticSize.X
	Company.Size = UDim2.new(0, 0, 1, 0)
	Company.Font = Library.Font
	Company.TextColor3 = Library.CompanyColor
	Company.TextSize = 16.000
	Company.TextTransparency = 0.300
	Company.RichText = true
	Company.TextXAlignment = Enum.TextXAlignment.Left

	function Library:SetCompany(Text)
		Text = Text or ""
		Library.Company = Text
		Company.Text = Text ~= "" and ("%s: "):format(Text) or ""
		return self
	end
	Library:SetCompany(Library.Company)

	local HeaderLabel = Instance.new("TextLabel", Header)
	HeaderLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	HeaderLabel.BackgroundTransparency = 1.000
	HeaderLabel.LayoutOrder = 2
	HeaderLabel.Size = UDim2.new(1, 0, 1, 0)
	HeaderLabel.Font = Library.Font
	HeaderLabel.Text = Library.Title
	HeaderLabel.RichText = true
	HeaderLabel.TextColor3 = Color3.fromRGB(198, 198, 198)
	HeaderLabel.TextSize = 16.000
	HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left

	function Library:SetTitle(Text)
		Text = Text or ""
		Library.Title = Text
		HeaderLabel.Text = Text
		return self
	end

	local UIListLayout = Instance.new("UIListLayout", Header)
	UIListLayout.FillDirection = Enum.FillDirection.Horizontal
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Padding = UDim.new(0, 5)

	local UIPadding = Instance.new("UIPadding", Header)
	UIPadding.PaddingLeft = UDim.new(0, 10)

	local BarFolder = Instance.new("Folder", MainBackground)

	local TopBar = Instance.new("Frame", BarFolder)
	TopBar.BackgroundColor3 = Library.BarColor or Library.AcientColor
	TopBar.BackgroundTransparency = 0.200
	TopBar.Size = UDim2.new(1, 0, 0, 2)
	TopBar.BorderSizePixel = 0
	Library:ApplyRainbow(TopBar, true)

	local TopBarCorner = Instance.new("UICorner", TopBar)
	TopBarCorner.CornerRadius = UDim.new(0, 2)

	local BarLayout = Instance.new("UIListLayout", BarFolder)
	BarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	BarLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local TabButtonsOutline = Instance.new("UIStroke", TabButtons)
	TabButtonsOutline.Thickness = 1
	TabButtonsOutline.Color = Library.LightGray

	local TabButtonsGradient = Instance.new("UIGradient", TabButtons)
	TabButtonsGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
	TabButtonsGradient.Rotation = 90

	local ContainerCorner = Instance.new("UICorner")
	ContainerCorner.CornerRadius = UDim.new(0, 2)
	ContainerCorner.Parent = Container

	local ContainerOutline = Instance.new("UIStroke", Container)
	ContainerOutline.Thickness = 1
	ContainerOutline.Color = Library.LightGray

	local Panic = Instance.new("TextButton", MainBackground)
	Panic.Text = Library.PanicText
	Panic.AnchorPoint = Vector2.new(0, 1)
	Panic.BackgroundTransparency = Library.Transparency
	Panic.BackgroundColor3 = Library.DarkGray
	Panic.Position = UDim2.new(0, 10, 1, -10)
	Panic.Size = UDim2.new(0, 152, 0, 24)
	Panic.Font = Library.Font
	Panic.TextColor3 = Color3.fromRGB(190, 190, 190)
	Panic.TextSize = 14.000
	self._PanicButton = Panic
	Panic.Activated:Connect(function()
		local PanicCallback = self._PanicCallback
		if type(PanicCallback) == "function" then
			PanicCallback()
			return
		end
		Library:Panic()
	end)

	local ButtonCorner = Instance.new("UICorner", Panic)
	ButtonCorner.CornerRadius = UDim.new(0, 2)

	local PanicOutline = Instance.new("UIStroke", Panic)
	PanicOutline.Thickness = 1
	PanicOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	PanicOutline.Color = Library.LightGray

	ConnectTracked(InitMaid, UserInputService.InputBegan, function(input)
		if input.KeyCode ~= Library.Key then return end

		local Visible = not MainBackground.Visible
		Library:ShowUI(Visible)
	end)

	function Library:ShowUI(Visible: boolean)
		local FieldOfView = Library.FieldOfView
		local BlurSize = Library.BlurSize
		local BlurEffect = Library.BlurEffect

		local Tweeninfo = TweenInfo.new(Visible and 0.5 or 0.3)

		MainBackground.Visible = Visible

		if BlurEffect then
			TweenService:Create(Blur, Tweeninfo, {
				Size = Visible and BlurSize or 0
			}):Play()
			TweenService:Create(CurrentCam, Tweeninfo, {
				FieldOfView = Visible and FieldOfView-12 or FieldOfView
			}):Play()
		end

		return self
	end

		TweenWrapper:CreateStyle("tab_text_colour", 0.16)
	function Library:NewTab(Title)
		Title = Title or "tab"
		local TabMaid = CreateCleanupMaid()
		TrackTask(InitMaid, TabMaid)

		local TabButton = Instance.new("TextButton")
		local Page = Instance.new("ScrollingFrame")
		local PageLayout = Instance.new("UIListLayout")
		local PagePadding = Instance.new("UIPadding")

		TabButton.Parent = TabButtons
		TabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TabButton.BackgroundTransparency = 1.000
		TabButton.ClipsDescendants = true
		TabButton.Position = UDim2.new(-0.0281690136, 0, 0, 0)
		TabButton.Size = UDim2.new(0, 150, 0, 22)
		TabButton.AutoButtonColor = false
		TabButton.Font = Library.Font
		TabButton.Text = Title
		TabButton.TextColor3 = Color3.fromRGB(170, 170, 170)
		TabButton.TextSize = 15.000
		TabButton.RichText = true

		Page.Parent = Container
		Page.Active = true
		Page.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Page.BackgroundTransparency = 1.000
		Page.BorderSizePixel = 0
		Page.Size = UDim2.new(0, 412, 0, 358)
		Page.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		Page.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		Page.ScrollBarThickness = 1
		Page.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
		Page.ScrollBarImageColor3 = Library.AcientColor
		Page.Visible = false
		Page.CanvasSize = UDim2.new(0,0,0,0)
		Page.AutomaticCanvasSize = Enum.AutomaticSize.Y

		PageLayout.Parent = Page
		PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		PageLayout.Padding = UDim.new(0, 4)

		PagePadding.Parent = Page
		PagePadding.PaddingBottom = UDim.new(0, 6)
		PagePadding.PaddingLeft = UDim.new(0, 6)
		PagePadding.PaddingRight = UDim.new(0, 6)
		PagePadding.PaddingTop = UDim.new(0, 6)

		TrackTask(TabMaid, TabButton)
		TrackTask(TabMaid, Page)

		if self.IsFirst then
			Page.Visible = true
			TabButton.TextColor3 = Library.AcientColor
			self.CurrentTab = Title
		end

		ConnectTracked(TabMaid, TabButton.MouseButton1Click, function()
			self.CurrentTab = Title
			for i,v in pairs(Container:GetChildren()) do
				if v:IsA("ScrollingFrame") then
					v.Visible = false
				end
			end
			Page.Visible = true

			for i,v in pairs(TabButtons:GetChildren()) do
				if v:IsA("TextButton") then
					TweenService:Create(v, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
				end
			end
			TweenService:Create(TabButton, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Library.AcientColor}):Play()
		end)

		self.IsFirst = false

		TweenWrapper:CreateStyle("hover", 0.16)
		local Components = {}
		function Components:NewLabel(Text, Alignment)
			Text = Text or "Label"
			Alignment = Alignment or "left"

			local Label = Instance.new("TextLabel")
			local LabelPadding = Instance.new("UIPadding")

			Label.Parent = Page
			Label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Label.BackgroundTransparency = 1.000
			Label.Position = UDim2.new(0.00499999989, 0, 0, 0)
			Label.Size = UDim2.new(0, 396, 0, 24)
			Label.Font = Library.Font
			Label.Text = Text
			Label.TextColor3 = Color3.fromRGB(190, 190, 190)
			Label.TextSize = 14.000
			Label.TextWrapped = true
			Label.TextXAlignment = Enum.TextXAlignment.Left
			Label.RichText = true

			LabelPadding.Parent = Page
			LabelPadding.PaddingBottom = UDim.new(0, 6)
			LabelPadding.PaddingLeft = UDim.new(0, 12)
			LabelPadding.PaddingRight = UDim.new(0, 6)
			LabelPadding.PaddingTop = UDim.new(0, 6)

			if Alignment:lower():find("le") then
				Label.TextXAlignment = Enum.TextXAlignment.Left
			elseif Alignment:lower():find("cent") then
				Label.TextXAlignment = Enum.TextXAlignment.Center
			elseif Alignment:lower():find("ri") then
				Label.TextXAlignment = Enum.TextXAlignment.Right
			end

			local LabelFunctions = {}
			function LabelFunctions:SetText(Text)
				Text = Text or "new Label text"
				Label.Text = Text
				return self
			end

			function LabelFunctions:Remove()
				Label:Destroy()
				return self
			end

			function LabelFunctions:Hide()
				Label.Visible = false

				return self
			end

			function LabelFunctions:Show()
				Label.Visible = true

				return self
			end

			function LabelFunctions:Align(NewAlignment)
				NewAlignment = NewAlignment or "le"
				if NewAlignment:lower():find("le") then
					Label.TextXAlignment = Enum.TextXAlignment.Left
				elseif NewAlignment:lower():find("cent") then
					Label.TextXAlignment = Enum.TextXAlignment.Center
				elseif NewAlignment:lower():find("ri") then
					Label.TextXAlignment = Enum.TextXAlignment.Right
				end
			end
			return LabelFunctions
		end

		function Components:NewButton(Text, Callback)
			Text = Text or "Button"
			Callback = Callback or function() end

			local ButtonFunctions = {}
			local Button = Instance.new("TextButton")
			local ButtonCorner = Instance.new("UICorner", Button)
			local ButtonStroke = Instance.new("UIStroke", Button)

			local Color = Library.DarkGray
			local Hover = Color3.fromRGB(40, 40, 40)

			Button.Text = Text
			Button.Parent = Page
			Button.BackgroundColor3 = Color
			Button.BackgroundTransparency = Library.Transparency
			Button.Size = UDim2.new(0, 396, 0, 24)
			Button.AutoButtonColor = false
			Button.Font = Library.Font
			Button.TextColor3 = Color3.fromRGB(190, 190, 190)
			Button.TextSize = 14

			ButtonStroke.Thickness = 1
			ButtonStroke.Color = Library.LightGray
			ButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			ButtonCorner.CornerRadius = UDim.new(0, 2)

			Button.MouseEnter:Connect(function()
				TweenService:Create(Button, TweenWrapper.Styles["hover"], {BackgroundColor3 = Hover}):Play()
			end)
			Button.MouseLeave:Connect(function()
				TweenService:Create(Button, TweenWrapper.Styles["hover"], {BackgroundColor3 = Color}):Play()
			end)

			Button.MouseButton1Down:Connect(function()
				TweenService:Create(Button, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(169, 107, 255)}):Play()
			end)
			Button.MouseButton1Up:Connect(function()
				TweenService:Create(Button, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(125, 125, 125)}):Play()
			end)

			Button.MouseButton1Click:Connect(function()
				Callback()
			end)

			function ButtonFunctions:Fire()
				Callback()
			end

			function ButtonFunctions:Hide()
				Button.Visible = false
				return self
			end

			function ButtonFunctions:Show()
				Button.Visible = true
				return self
			end

			function ButtonFunctions:SetText(Text)
				Text = Text or ""
				Button.Text = Text

				return self
			end

			function ButtonFunctions:Remove()
				Button:Destroy()
				return self
			end

			function ButtonFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or function() end
				Callback = NewCallback
				return self
			end
			return ButtonFunctions
		end

		function Components:NewSection(Text)
			Text = Text or "section"

			local SectionFrame = Instance.new("Frame", Page)
			local SectionLayout = Instance.new("UIListLayout")
			local SectionLabel = Instance.new("TextLabel")
			local SectionPadding = Instance.new("UIPadding", SectionFrame)

			local UICorner = Instance.new("UICorner", SectionFrame)
			UICorner.CornerRadius = UDim.new(0, 3)

			SectionFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
			SectionFrame.BackgroundTransparency = 0.500
			SectionFrame.BorderSizePixel = 0
			SectionFrame.ClipsDescendants = true
			SectionFrame.Size = UDim2.new(0, 396, 0, 19)

			SectionPadding.PaddingBottom = UDim.new(0, 6)
			SectionPadding.PaddingLeft = UDim.new(0, 3)
			SectionPadding.PaddingRight = UDim.new(0, 3)
			SectionPadding.PaddingTop = UDim.new(0, 6)

			SectionLayout.Parent = SectionFrame
			SectionLayout.FillDirection = Enum.FillDirection.Horizontal
			SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			SectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			SectionLayout.Padding = UDim.new(0, 4)

			SectionLabel.Parent = SectionFrame
			SectionLabel.BackgroundColor3 = Library.HeaderColor
			SectionLabel.BackgroundTransparency = 1.000
			SectionLabel.ClipsDescendants = true
			SectionLabel.Position = UDim2.new(0.0252525248, 0, 0.020833334, 0)
			SectionLabel.Size = UDim2.new(1, 0, 1, 0)
			SectionLabel.Font = Library.Font
			SectionLabel.LineHeight = 1
			SectionLabel.Text = Text
			SectionLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			SectionLabel.TextSize = 14.000
			SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
			SectionLabel.RichText = true

			local NewSectionSize = TextService:GetTextSize(SectionLabel.Text, SectionLabel.TextSize, SectionLabel.Font, Vector2.new(math.huge,math.huge))
			SectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

			local SectionFunctions = {}
			function SectionFunctions:SetText(NewText)
				NewText = NewText or Text
				SectionLabel.Text = NewText

				local NewSectionSize = TextService:GetTextSize(SectionLabel.Text, SectionLabel.TextSize, SectionLabel.Font, Vector2.new(math.huge,math.huge))
				SectionLabel.Size = UDim2.new(0, NewSectionSize.X, 0, 18)

				return self
			end
			function SectionFunctions:Hide()
				SectionFrame.Visible = false
				return self
			end
			function SectionFunctions:Show()
				SectionFrame.Visible = true
				return self
			end
			function SectionFunctions:Remove()
				SectionFrame:Destroy()
				return self
			end

			return SectionFunctions
		end

		function Components:NewToggle(Text, Default, Callback, Loop, IgnorePanic)
			Text = Text or "Toggle"
			Default = Default or false
			Callback = Callback or function() end
			local ToggleMaid = CreateCleanupMaid()
			TrackTask(TabMaid, ToggleMaid)

			local ToggleButton = Instance.new("TextButton", Page)
			local ToggleLayout = Instance.new("UIListLayout")

			local Toggle = Instance.new("Frame")
			local ToggleCorner = Instance.new("UICorner")
			local ToggleDesign = Instance.new("Frame")
			local ToggleDesignCorner = Instance.new("UICorner")
			local ToggleStroke = Instance.new("UIStroke", Toggle)
			local ToggleLabel = Instance.new("TextLabel")
			local ToggleLabelPadding = Instance.new("UIPadding")
			local Extras = Instance.new("Folder")
			local ExtrasLayout = Instance.new("UIListLayout")

			ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			ToggleButton.BackgroundTransparency = 1.000
			ToggleButton.ClipsDescendants = false
			ToggleButton.Size = UDim2.new(0, 396, 0, 22)
			ToggleButton.Font = Library.Font
			ToggleButton.Text = ""
			ToggleButton.TextColor3 = Color3.fromRGB(190, 190, 190)
			ToggleButton.TextSize = 14.000
			ToggleButton.TextXAlignment = Enum.TextXAlignment.Left

			ToggleLayout.Parent = ToggleButton
			ToggleLayout.FillDirection = Enum.FillDirection.Horizontal
			ToggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ToggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			Toggle.Parent = ToggleButton
			Toggle.BackgroundColor3 = Library.DarkGray
			Toggle.BackgroundTransparency = Library.Transparency
			Toggle.Size = UDim2.new(0, 18, 0, 18)

			ToggleStroke.Thickness = 1
			ToggleStroke.Color = Library.LightGray

			ToggleCorner.CornerRadius = UDim.new(0, 2)
			ToggleCorner.Parent = Toggle

			ToggleDesign.Parent = Toggle
			ToggleDesign.AnchorPoint = Vector2.new(0.5, 0.5)
			ToggleDesign.BackgroundColor3 = Library.AcientColor
			ToggleDesign.BackgroundTransparency = 1.000
			ToggleDesign.Position = UDim2.new(0.5, 0, 0.5, 0)

			ToggleDesignCorner.CornerRadius = UDim.new(0, 2)
			ToggleDesignCorner.Parent = ToggleDesign

			ToggleLabel.Parent = ToggleButton
			ToggleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			ToggleLabel.BackgroundTransparency = 1.000
			ToggleLabel.Position = UDim2.new(0.0454545468, 0, 0, 0)
			ToggleLabel.Size = UDim2.new(0, 377, 0, 22)
			ToggleLabel.Font = Library.Font
			ToggleLabel.LineHeight = 1.150
			ToggleLabel.Text = Text
			ToggleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			ToggleLabel.TextSize = 14.000
			ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left
			ToggleLabel.RichText = true

			ToggleLabelPadding.Parent = ToggleLabel
			ToggleLabelPadding.PaddingLeft = UDim.new(0, 6)

			Extras.Parent = ToggleButton

			ExtrasLayout.Parent = Extras
			ExtrasLayout.FillDirection = Enum.FillDirection.Horizontal
			ExtrasLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			ExtrasLayout.SortOrder = Enum.SortOrder.LayoutOrder
			ExtrasLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			ExtrasLayout.Padding = UDim.new(0, 2)

			local NewToggleLabelSize = TextService:GetTextSize(ToggleLabel.Text, ToggleLabel.TextSize, ToggleLabel.Font, Vector2.new(math.huge,math.huge))
			ToggleLabel.Size = UDim2.new(0, NewToggleLabelSize.X + 6, 0, 22)
			TrackTask(ToggleMaid, ToggleButton)

			ConnectTracked(ToggleMaid, ToggleButton.MouseEnter, function()
				TweenService:Create(ToggleLabel, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(210, 210, 210)}):Play()
			end)
			ConnectTracked(ToggleMaid, ToggleButton.MouseLeave, function()
				TweenService:Create(ToggleLabel, TweenWrapper.Styles["hover"], {TextColor3 = Color3.fromRGB(190, 190, 190)}):Play()
			end)

			TweenWrapper:CreateStyle("toggle_form", 0.13)
			local On = Default
			if Default then
				On = true
			else
				On = false
			end

			if Loop ~= nil then
				ConnectTracked(ToggleMaid, RunService.RenderStepped, function()
					if On == true then
						Callback(On)
					end
				end)
			end

			ConnectTracked(ToggleMaid, ToggleButton.MouseButton1Click, function()
				On = not On
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				Callback(On)
			end)

			local ToggleFunctions = {}

			if not IgnorePanic then
				RegisterOptionState(ToggleButton, false, ToggleFunctions, ToggleMaid)
			end

			function ToggleFunctions:SetText(NewText)
				NewText = NewText or Text
				ToggleLabel.Text = NewText
				return self
			end

			function ToggleFunctions:Hide()
				ToggleButton.Visible = false
				return self
			end

			function ToggleFunctions:Show()
				ToggleButton.Visible = true
				return self
			end

			function ToggleFunctions:Change()
				On = not On
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				Callback(On)
				return self
			end

			function ToggleFunctions:Remove()
				DoCleaning(ToggleMaid)
				return self
			end

			function ToggleFunctions:Set(State)
				On = State
				local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
				local Transparency = On and 0 or 1
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
				TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
				Callback(On)
				return ToggleFunctions
			end

			function ToggleFunctions:GetValue()
				return On
			end

			local CallbackFunction
			function ToggleFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or function() end
				Callback = NewCallback
				CallbackFunction = NewCallback
				return ToggleFunctions
			end

			function ToggleFunctions:AddKeybind(DefaultKey)
				CallbackFunction = Callback
				if DefaultKey == Enum.KeyCode.Backspace then
					DefaultKey = nil
				end

				local Keybind = Instance.new("TextButton")
				local KeybindOutline = Instance.new("UIStroke")
				local KeybindCorner = Instance.new("UICorner")
				local KeybindBackground = Instance.new("Frame")
				local KeybindBackCorner = Instance.new("UICorner")
				local KeybindButtonLabel = Instance.new("TextLabel")
				local KeybindLabelConstraint = Instance.new("UISizeConstraint")
				local KeybindBackgroundConstraint = Instance.new("UISizeConstraint")
				local KeybindConstraint = Instance.new("UISizeConstraint")

				KeybindOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				KeybindOutline.Thickness = 1
				KeybindOutline.Parent = Keybind
				KeybindOutline.Color = Library.LightGray

				KeybindCorner.CornerRadius = UDim.new(0, 2)
				KeybindCorner.Parent = Keybind

				Keybind.Parent = Extras
				Keybind.BackgroundTransparency = Library.Transparency
				Keybind.BackgroundColor3 = Library.DarkGray
				Keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
				Keybind.Size = UDim2.new(0, 87, 0, 22)
				Keybind.AutoButtonColor = false
				Keybind.Font = Library.Font
				Keybind.Text = ""
				Keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
				Keybind.TextSize = 14.000
				Keybind.Active = false

				KeybindBackground.Parent = Keybind
				KeybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
				KeybindBackground.BackgroundTransparency = 1
				KeybindBackground.BackgroundColor3 = Library.DarkGray
				KeybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
				KeybindBackground.Size = UDim2.new(0, 85, 0, 20)

				KeybindBackCorner.CornerRadius = UDim.new(0, 2)
				KeybindBackCorner.Parent = KeybindBackground

				KeybindButtonLabel.Parent = KeybindBackground
				KeybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				KeybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				KeybindButtonLabel.BackgroundTransparency = 1.000
				KeybindButtonLabel.ClipsDescendants = true
				KeybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
				KeybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
				KeybindButtonLabel.Font = Library.Font
				KeybindButtonLabel.Text = ". . ."
				KeybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
				KeybindButtonLabel.TextSize = 14.000
				KeybindButtonLabel.RichText = true

				KeybindLabelConstraint.Parent = KeybindButtonLabel
				KeybindLabelConstraint.MinSize = Vector2.new(28, 20)

				KeybindBackgroundConstraint.Parent = KeybindBackground
				KeybindBackgroundConstraint.MinSize = Vector2.new(28, 20)

				KeybindConstraint.Parent = Keybind
				KeybindConstraint.MinSize = Vector2.new(30, 22)

				local Shortcuts = {
					Return = "enter"
				}

				KeybindButtonLabel.Text = DefaultKey and (Shortcuts[DefaultKey.Name] or DefaultKey.Name) or "None"
				TweenWrapper:CreateStyle("Keybind", 0.08)

				local NewKeybindSize = TextService:GetTextSize(KeybindButtonLabel.Text, KeybindButtonLabel.TextSize, KeybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
				KeybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
				KeybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
				Keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)

				local function ResizeKeybind()
					NewKeybindSize = TextService:GetTextSize(KeybindButtonLabel.Text, KeybindButtonLabel.TextSize, KeybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
					TweenService:Create(KeybindButtonLabel, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
					TweenService:Create(KeybindBackground, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
					TweenService:Create(Keybind, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
				end
				ConnectTracked(ToggleMaid, KeybindButtonLabel:GetPropertyChangedSignal("Text"), ResizeKeybind)
				ResizeKeybind()

				local ChosenKey = DefaultKey and DefaultKey.Name

				Keybind.MouseButton1Click:Connect(function()
					KeybindButtonLabel.Text = ". . ."
					local InputWait = UserInputService.InputBegan:wait()
					if not UserInputService.WindowFocused then return end

					if InputWait == Enum.KeyCode.Backspace then
						DefaultKey = nil
						ChosenKey = nil
						KeybindButtonLabel.Text = "None"
						return
					end

					if InputWait.KeyCode.Name ~= "Unknown" then
						local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
						KeybindButtonLabel.Text = Result
						ChosenKey = InputWait.KeyCode.Name
					end
				end)

				if UserInputService.WindowFocused then
					ConnectTracked(ToggleMaid, UserInputService.InputBegan, function(c, p)
						if not p and DefaultKey and ChosenKey then
							if c.KeyCode.Name == ChosenKey then
								On = not On
								local SizeOn = On and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 0, 0, 0)
								local Transparency = On and 0 or 1
								TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {Size = SizeOn}):Play()
								TweenService:Create(ToggleDesign, TweenWrapper.Styles["toggle_form"], {BackgroundTransparency = Transparency}):Play()
								CallbackFunction(On)
								return
							end
						end
					end)
				end

				local ExtraKeybindFunctions = {}
				function ExtraKeybindFunctions:SetKey(NewKey)
					NewKey = NewKey or ChosenKey.Name
					ChosenKey = NewKey.Name
					KeybindButtonLabel.Text = NewKey.Name
					return self
				end

				function ExtraKeybindFunctions:Fire()
					CallbackFunction(ChosenKey)
					return self
				end

				function ExtraKeybindFunctions:SetFunction(NewCallback)
					NewCallback = NewCallback or function() end
					CallbackFunction = NewCallback
					return self
				end

				function ExtraKeybindFunctions:Hide()
					Keybind.Visible = false
					return self
				end

				function ExtraKeybindFunctions:Show()
					Keybind.Visible = true
					return self
				end
				return ExtraKeybindFunctions and ToggleFunctions
			end

			if Default then
				ToggleDesign.Size = UDim2.new(0, 12, 0, 12)
				ToggleDesign.BackgroundTransparency = 0
				Callback(true)
			end
			return ToggleFunctions
		end

		function Components:NewKeybind(Text, Default, Callback)
			Text = Text or "Keybind"
			Default = Default or Enum.KeyCode.P
			Callback = Callback or function() end
			local KeybindMaid = CreateCleanupMaid()
			TrackTask(TabMaid, KeybindMaid)

			local KeybindFrame = Instance.new("Frame")
			local KeybindButton = Instance.new("TextButton")
			local KeybindLayout = Instance.new("UIListLayout")
			local KeybindLabel = Instance.new("TextLabel")
			local KeybindPadding = Instance.new("UIPadding")
			local KeybindFolder = Instance.new("Folder")
			local KeybindFolderLayout = Instance.new("UIListLayout")
			local Keybind = Instance.new("TextButton")
			local KeybindCorner = Instance.new("UICorner")
			local KeybindBackground = Instance.new("Frame")
			local KeybindGradient = Instance.new("UIGradient")
			local KeybindBackCorner = Instance.new("UICorner")
			local KeybindButtonLabel = Instance.new("TextLabel")
			local KeybindLabelConstraint = Instance.new("UISizeConstraint")
			local KeybindBackgroundConstraint = Instance.new("UISizeConstraint")
			local KeybindConstraint = Instance.new("UISizeConstraint")

			KeybindFrame.Parent = Page
			KeybindFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			KeybindFrame.BackgroundTransparency = 1.000
			KeybindFrame.ClipsDescendants = true
			KeybindFrame.Size = UDim2.new(0, 396, 0, 24)

			KeybindButton.Parent = KeybindFrame
			KeybindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			KeybindButton.BackgroundTransparency = 1.000
			KeybindButton.Size = UDim2.new(0, 396, 0, 24)
			KeybindButton.AutoButtonColor = false
			KeybindButton.Font = Library.Font
			KeybindButton.Text = ""
			KeybindButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			KeybindButton.TextSize = 14.000

			KeybindLayout.Parent = KeybindButton
			KeybindLayout.FillDirection = Enum.FillDirection.Horizontal
			KeybindLayout.SortOrder = Enum.SortOrder.LayoutOrder
			KeybindLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			KeybindLayout.Padding = UDim.new(0, 4)

			KeybindLabel.Parent = KeybindButton
			KeybindLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			KeybindLabel.BackgroundTransparency = 1.000
			KeybindLabel.Size = UDim2.new(0, 396, 0, 24)
			KeybindLabel.Font = Library.Font
			KeybindLabel.Text = Text
			KeybindLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			KeybindLabel.TextSize = 14.000
			KeybindLabel.TextWrapped = true
			KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left
			KeybindLabel.RichText = true

			KeybindPadding.Parent = KeybindLabel
			KeybindPadding.PaddingBottom = UDim.new(0, 6)
			KeybindPadding.PaddingLeft = UDim.new(0, 2)
			KeybindPadding.PaddingRight = UDim.new(0, 6)
			KeybindPadding.PaddingTop = UDim.new(0, 6)

			KeybindFolder.Parent = KeybindFrame

			KeybindFolderLayout.Parent = KeybindFolder
			KeybindFolderLayout.FillDirection = Enum.FillDirection.Horizontal
			KeybindFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			KeybindFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
			KeybindFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			KeybindFolderLayout.Padding = UDim.new(0, 4)

			Keybind.Parent = KeybindFolder
			Keybind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			Keybind.Position = UDim2.new(0.780303001, 0, 0, 0)
			Keybind.Size = UDim2.new(0, 87, 0, 22)
			Keybind.AutoButtonColor = false
			Keybind.Font = Library.Font
			Keybind.Text = ""
			Keybind.TextColor3 = Color3.fromRGB(0, 0, 0)
			Keybind.TextSize = 14.000
			Keybind.Active = false

			KeybindCorner.CornerRadius = UDim.new(0, 2)
			KeybindCorner.Parent = Keybind

			KeybindBackground.Parent = Keybind
			KeybindBackground.AnchorPoint = Vector2.new(0.5, 0.5)
			KeybindBackground.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			KeybindBackground.Position = UDim2.new(0.5, 0, 0.5, 0)
			KeybindBackground.Size = UDim2.new(0, 85, 0, 20)

			KeybindGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(34, 34, 34)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 28, 28))}
			KeybindGradient.Rotation = 90
			KeybindGradient.Parent = KeybindBackground

			KeybindBackCorner.CornerRadius = UDim.new(0, 2)
			KeybindBackCorner.Parent = KeybindBackground

			KeybindButtonLabel.Parent = KeybindBackground
			KeybindButtonLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			KeybindButtonLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			KeybindButtonLabel.BackgroundTransparency = 1.000
			KeybindButtonLabel.ClipsDescendants = true
			KeybindButtonLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
			KeybindButtonLabel.Size = UDim2.new(0, 85, 0, 20)
			KeybindButtonLabel.Font = Library.Font
			KeybindButtonLabel.Text = ". . ."
			KeybindButtonLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			KeybindButtonLabel.TextSize = 14.000
			KeybindButtonLabel.RichText = true

			KeybindLabelConstraint.Parent = KeybindButtonLabel
			KeybindLabelConstraint.MinSize = Vector2.new(28, 20)

			KeybindBackgroundConstraint.Parent = KeybindBackground
			KeybindBackgroundConstraint.MinSize = Vector2.new(28, 20)

			KeybindConstraint.Parent = Keybind
			KeybindConstraint.MinSize = Vector2.new(30, 22)
			TrackTask(KeybindMaid, KeybindFrame)

			local Shortcuts = {
				Return = "enter"
			}

			KeybindButtonLabel.Text = Shortcuts[Default.Name] or Default.Name
			TweenWrapper:CreateStyle("Keybind", 0.08)

			local NewKeybindSize = TextService:GetTextSize(KeybindButtonLabel.Text, KeybindButtonLabel.TextSize, KeybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
			KeybindButtonLabel.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
			KeybindBackground.Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)
			Keybind.Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)

			local function ResizeKeybind()
				NewKeybindSize = TextService:GetTextSize(KeybindButtonLabel.Text, KeybindButtonLabel.TextSize, KeybindButtonLabel.Font, Vector2.new(math.huge,math.huge))
				TweenService:Create(KeybindButtonLabel, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
				TweenService:Create(KeybindBackground, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 6, 0, 20)}):Play()
				TweenService:Create(Keybind, TweenWrapper.Styles["Keybind"], {Size = UDim2.new(0, NewKeybindSize.X + 8, 0, 22)}):Play()
			end
			ConnectTracked(KeybindMaid, KeybindButtonLabel:GetPropertyChangedSignal("Text"), ResizeKeybind)
			ResizeKeybind()

			local ChosenKey = Default
			KeybindButton.MouseButton1Click:Connect(function()
				KeybindButtonLabel.Text = "..."
				local InputWait = UserInputService.InputBegan:wait()
				if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
					local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
					KeybindButtonLabel.Text = Result
					ChosenKey = InputWait.KeyCode.Name
				end
			end)

			Keybind.MouseButton1Click:Connect(function()
				KeybindButtonLabel.Text = ". . ."
				local InputWait = UserInputService.InputBegan:wait()
				if UserInputService.WindowFocused and InputWait.KeyCode.Name ~= "Unknown" then
					local Result = Shortcuts[InputWait.KeyCode.Name] or InputWait.KeyCode.Name
					KeybindButtonLabel.Text = Result
					ChosenKey = InputWait.KeyCode.Name
				end
			end)

			if UserInputService.WindowFocused then
				ConnectTracked(KeybindMaid, UserInputService.InputBegan, function(c, GameProcessed)
					if GameProcessed then
						return
					end
					if c.KeyCode.Name == ChosenKey then
						Callback(ChosenKey)
						return
					end
				end)
			end

			local KeybindFunctions = {}
			function KeybindFunctions:Fire()
				Callback(ChosenKey)
				return KeybindFunctions
			end

			function KeybindFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or function() end
				Callback = NewCallback
				return self
			end

			function KeybindFunctions:SetKey(NewKey)
				NewKey = NewKey or ChosenKey.Name
				ChosenKey = NewKey.Name
				KeybindButtonLabel.Text = NewKey.Name
				return self
			end

			function KeybindFunctions:SetText(NewText)
				NewText = NewText or KeybindLabel.Text
				KeybindLabel.Text = NewText
				return self
			end

			function KeybindFunctions:Hide()
				KeybindFrame.Visible = false
				return self
			end

			function KeybindFunctions:Show()
				KeybindFrame.Visible = true
				return self
			end

			function KeybindFunctions:Remove()
				DoCleaning(KeybindMaid)
				return self
			end
			return KeybindFunctions
		end

		function Components:NewTextbox(Text, Default, PlaceHolder, TextboxType, AutoExecute, AutoClear, Callback)
			Text = Text or "text box"
			Default = Default or ""
			PlaceHolder = PlaceHolder or ""
			TextboxType = TextboxType or "small"
			AutoExecute = AutoExecute or true
			AutoClear = AutoClear or false
			Callback = Callback or function() end

			local TextboxFrame = Instance.new("Frame")
			local TextboxLabel = Instance.new("TextLabel")
			local TextboxPadding = Instance.new("UIPadding")
			local Textbox = Instance.new("Frame")
			local TextBoxValues = Instance.new("TextBox")
			local TextBoxValuesPadding = Instance.new("UIPadding")

			TextboxFrame.Parent = Page
			TextboxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextboxFrame.BackgroundTransparency = 1.000
			TextboxFrame.BorderSizePixel = 0
			TextboxFrame.Position = UDim2.new(0.00499999989, 0, 0.268786132, 0)

			TextBoxValues.MultiLine = true
			if TextboxType == "small" then
				TextBoxValues.MultiLine = false
				TextboxFrame.Size = UDim2.new(0, 393, 0, 46)
			elseif TextboxType == "medium" then
				TextboxFrame.Size = UDim2.new(0, 393, 0, 60)
			elseif TextboxType == "large" then
				TextboxFrame.Size = UDim2.new(0, 393, 0, 118)
			end

			TextboxLabel.Parent = TextboxFrame
			TextboxLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			TextboxLabel.BackgroundTransparency = 1.000
			TextboxLabel.Size = UDim2.new(1, 0, 0, 24)
			TextboxLabel.Font = Library.Font
			TextboxLabel.Text = Text
			TextboxLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			TextboxLabel.TextSize = 14.000
			TextboxLabel.TextWrapped = true
			TextboxLabel.TextXAlignment = Enum.TextXAlignment.Left

			TextboxPadding.Parent = TextboxLabel
			TextboxPadding.PaddingBottom = UDim.new(0, 6)
			TextboxPadding.PaddingRight = UDim.new(0, 6)
			TextboxPadding.PaddingTop = UDim.new(0, 6)

			Textbox.Parent = TextboxFrame
			Textbox.BackgroundColor3 = Library.DarkGray
			Textbox.BackgroundTransparency = Library.Transparency
			Textbox.BorderSizePixel = 0
			Textbox.Position = UDim2.new(0, 0, 0, 24)
			Textbox.Size = UDim2.new(1, 0, 1, -24)

			local TextboxOutline = Instance.new("UIStroke", Textbox)
			TextboxOutline.Thickness = 1
			TextboxOutline.Color = Library.LightGray

			local UICorner = Instance.new("UICorner", Textbox)
			UICorner.CornerRadius = UDim.new(0, 2)

			TextBoxValues.Parent = Textbox
			TextBoxValues.BackgroundTransparency = 1
			TextBoxValues.BorderSizePixel = 0
			TextBoxValues.ClipsDescendants = true
			TextBoxValues.Size = UDim2.new(1, 0, 1, 0)
			TextBoxValues.Font = Library.Font
			TextBoxValues.PlaceholderColor3 = Color3.fromRGB(140, 140, 140)
			TextBoxValues.PlaceholderText = PlaceHolder
			TextBoxValues.Text = Default
			TextBoxValues.TextColor3 = Color3.fromRGB(190, 190, 190)
			TextBoxValues.TextSize = 14.000
			TextBoxValues.TextWrapped = true
			TextBoxValues.TextXAlignment = Enum.TextXAlignment.Left
			TextBoxValues.TextYAlignment = Enum.TextYAlignment.Top

			TextBoxValuesPadding.Parent = TextBoxValues
			TextBoxValuesPadding.PaddingBottom = UDim.new(0, 4)
			TextBoxValuesPadding.PaddingLeft = UDim.new(0, 4)
			TextBoxValuesPadding.PaddingRight = UDim.new(0, 4)
			TextBoxValuesPadding.PaddingTop = UDim.new(0, 4)

			TweenWrapper:CreateStyle("TextBox", 0.07)

			TextBoxValues.FocusLost:Connect(function(enterPressed)
				if AutoExecute or enterPressed then
					Callback(TextBoxValues.Text)
				end
			end)

			local TextboxFunctions = {}
			function TextboxFunctions:Input(NewText)
				NewText = NewText or TextBoxValues.Text
				TextBoxValues.Text = NewText
				return self
			end

			function TextboxFunctions:Fire()
				Callback(TextBoxValues.Text)
				return self
			end

			function TextboxFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or Callback
				Callback = NewCallback
				return self
			end

			function TextboxFunctions:SetText(NewText)
				NewText = NewText or TextboxLabel.Text
				TextboxLabel.Text = NewText
				return self
			end

			function TextboxFunctions:Hide()
				TextboxFrame.Visible = false
				return self
			end

			function TextboxFunctions:Show()
				TextboxFrame.Visible = true
				return self
			end

			function TextboxFunctions:Remove()
				TextboxFrame:Destroy()
				return self
			end

			function TextboxFunctions:SetPlaceHolder(NewPlaceHolder)
				NewPlaceHolder = NewPlaceHolder or TextBoxValues.PlaceholderText
				TextBoxValues.PlaceholderText = NewPlaceHolder
				return self
			end
			return TextboxFunctions
		end

		function Components:NewSelector(Text, Default, List, Callback)
			Text = Text or "Selector"
			Default = Default or ". . ."
			List = List or {}
			Callback = Callback or function() end

			local SelectorFrame = Instance.new("Frame")
			local SelectorLabel = Instance.new("TextLabel")
			local SelectorLabelPadding = Instance.new("UIPadding")
			local SelectorFrameLayout = Instance.new("UIListLayout")
			local Selector = Instance.new("TextButton")
			local SelectorCorner = Instance.new("UICorner")
			local SelectorLayout = Instance.new("UIListLayout")
			local SelectorPadding = Instance.new("UIPadding")
			local SelectorTwo = Instance.new("Frame")
			local SelectorText = Instance.new("TextLabel")
			local TextBoxValuesPadding = Instance.new("UIPadding")
			local Frame = Instance.new("Frame")
			local SelectorTwoLayout = Instance.new("UIListLayout")
			local SelectorTwoCorner = Instance.new("UICorner")
			local SelectorPadding2 = Instance.new("UIPadding")
			local SelectorContainer = Instance.new("Frame")
			local SelectorTwoLayout2 = Instance.new("UIListLayout")

			SelectorFrame.Parent = Page
			SelectorFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SelectorFrame.BackgroundTransparency = 1.000
			SelectorFrame.ClipsDescendants = true
			SelectorFrame.Position = UDim2.new(0.00499999989, 0, 0.0895953774, 0)
			SelectorFrame.Size = UDim2.new(0, 394, 0, 48)

			SelectorLabel.Parent = SelectorFrame
			SelectorLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SelectorLabel.BackgroundTransparency = 1.000
			SelectorLabel.Size = UDim2.new(0, 396, 0, 24)
			SelectorLabel.Font = Library.Font
			SelectorLabel.Text = Text
			SelectorLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			SelectorLabel.TextSize = 14.000
			SelectorLabel.TextWrapped = true
			SelectorLabel.TextXAlignment = Enum.TextXAlignment.Left
			SelectorLabel.RichText = true

			SelectorLabelPadding.Parent = SelectorLabel
			SelectorLabelPadding.PaddingBottom = UDim.new(0, 6)
			SelectorLabelPadding.PaddingLeft = UDim.new(0, 2)
			SelectorLabelPadding.PaddingRight = UDim.new(0, 6)
			SelectorLabelPadding.PaddingTop = UDim.new(0, 6)

			SelectorFrameLayout.Parent = SelectorFrame
			SelectorFrameLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SelectorFrameLayout.SortOrder = Enum.SortOrder.LayoutOrder

			Selector.Parent = SelectorFrame
			Selector.BackgroundColor3 = Library.DarkGray
			Selector.BackgroundTransparency = Library.Transparency
			Selector.ClipsDescendants = true
			Selector.Position = UDim2.new(0, 0, 0.0926640928, 0)
			Selector.Size = UDim2.new(1, 0, 0, 23)
			Selector.AutoButtonColor = false
			Selector.Font = Library.Font
			Selector.Text = ""
			Selector.TextColor3 = Color3.fromRGB(0, 0, 0)
			Selector.TextSize = 14.000

			SelectorCorner.CornerRadius = UDim.new(0, 2)
			SelectorCorner.Parent = Selector

			SelectorLayout.Parent = Selector
			SelectorLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SelectorLayout.SortOrder = Enum.SortOrder.LayoutOrder

			SelectorPadding.Parent = Selector
			SelectorPadding.PaddingTop = UDim.new(0, 1)

			SelectorTwo.Parent = Selector
			SelectorTwo.BackgroundColor3 = Library.DarkGray
			SelectorTwo.BackgroundTransparency = Library.Transparency
			SelectorTwo.ClipsDescendants = true
			SelectorTwo.Position = UDim2.new(0.00252525252, 0, 0, 0)
			SelectorTwo.Size = UDim2.new(1, -2, 1, -1)

			SelectorText.Parent = SelectorTwo
			SelectorText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SelectorText.BackgroundTransparency = 1.000
			SelectorText.Size = UDim2.new(0, 394, 0, 20)
			SelectorText.Font = Library.Font
			SelectorText.LineHeight = 1.150
			SelectorText.TextColor3 = Color3.fromRGB(160, 160, 160)
			SelectorText.TextSize = 14.000
			SelectorText.TextXAlignment = Enum.TextXAlignment.Left
			SelectorText.Text = Default

			local Toggle = Instance.new("TextButton", SelectorText)
			Toggle.AnchorPoint = Vector2.new(1, 0.5)
			Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Toggle.BackgroundTransparency = 1.000
			Toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
			Toggle.BorderSizePixel = 0
			Toggle.Position = UDim2.new(1, 0, 0.5, 0)
			Toggle.Rotation = 90
			Toggle.Size = UDim2.new(0, 20, 1, 5)
			Toggle.Font = Library.Font
			Toggle.Text = ">"
			Toggle.TextColor3 = Color3.fromRGB(160, 160, 160)
			Toggle.TextSize = 14.000

			TextBoxValuesPadding.Parent = SelectorText
			TextBoxValuesPadding.PaddingBottom = UDim.new(0, 6)
			TextBoxValuesPadding.PaddingLeft = UDim.new(0, 6)
			TextBoxValuesPadding.PaddingRight = UDim.new(0, 6)
			TextBoxValuesPadding.PaddingTop = UDim.new(0, 6)

			Frame.Parent = SelectorText
			Frame.AnchorPoint = Vector2.new(0.5, 1)
			Frame.BackgroundColor3 = Color3.fromRGB(39, 39, 39)
			Frame.BorderSizePixel = 0
			Frame.Position = UDim2.new(0.5, 0, 1, 7)
			Frame.Size = UDim2.new(1, -6, 0, 1)

			SelectorTwoLayout.Parent = SelectorTwo
			SelectorTwoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SelectorTwoLayout.SortOrder = Enum.SortOrder.LayoutOrder

			SelectorTwoCorner.CornerRadius = UDim.new(0, 2)
			SelectorTwoCorner.Parent = SelectorTwo

			SelectorPadding2.Parent = SelectorTwo
			SelectorPadding2.PaddingTop = UDim.new(0, 1)

			SelectorContainer.Parent = SelectorTwo
			SelectorContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SelectorContainer.BackgroundTransparency = 1.000
			SelectorContainer.Size = UDim2.new(1, 0, 0, 20)

			SelectorTwoLayout2.Parent = SelectorContainer
			SelectorTwoLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SelectorTwoLayout2.SortOrder = Enum.SortOrder.LayoutOrder

			TweenWrapper:CreateStyle("Selector", 0.08)

			local Amount = #List
			local Val = (Amount * 20)
			local Size= 0

			local function CheckSizes()
				Amount = #List
				Val = (Amount * 20) + 20
			end

			for i,v in next, List do
				local OptionButton = Instance.new("TextButton")

				OptionButton.Name = "OptionButton"
				OptionButton.Parent = SelectorContainer
				OptionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				OptionButton.BackgroundTransparency = 1.000
				OptionButton.Size = UDim2.new(0, 394, 0, 20)
				OptionButton.AutoButtonColor = false
				OptionButton.Font = Library.Font
				OptionButton.Text = v
				OptionButton.TextColor3 = Color3.fromRGB(160, 160, 160)
				OptionButton.TextSize = 14.000
				if OptionButton.Text == Default then
					OptionButton.TextColor3 = Library.AcientColor
					Callback(SelectorText.Text)
				end

				OptionButton.MouseButton1Click:Connect(function()
					for z,x in next, SelectorContainer:GetChildren() do
						if x:IsA("TextButton") then
							TweenService:Create(x, TweenWrapper.Styles["Selector"], {TextColor3 = Color3.fromRGB(160, 160, 160)}):Play()
						end
					end
					TweenService:Create(OptionButton, TweenWrapper.Styles["Selector"], {TextColor3 = Library.AcientColor}):Play()
					SelectorText.Text = OptionButton.Text
					Callback(OptionButton.Text)
				end)

				Size = Val + 2

				CheckSizes()
			end

			local SelectorFunctions = {}
			local AddAmount = 0

			local IsOpen = false
			local function HandleToggle()
				local Speed = 0.2
				IsOpen = not IsOpen

				TweenService:Create(Selector, TweenInfo.new(Speed), {
					Size = UDim2.new(1, 0, 0, IsOpen and Size or 23)
				}):Play()
				TweenService:Create(SelectorFrame, TweenInfo.new(Speed), {
					Size = UDim2.new(0, 394, 0, IsOpen and Size+24 or 48)
				}):Play()
				TweenService:Create(Toggle, TweenInfo.new(Speed), {
					Rotation = IsOpen and -90 or 90
				}):Play()
			end

			Selector.Activated:Connect(HandleToggle)
			Toggle.Activated:Connect(HandleToggle)

			function SelectorFunctions:AddOption(NewOption, CallbackFunction)
				NewOption = NewOption or "option"
				List[NewOption] = NewOption

				local OptionButton = Instance.new("TextButton")

				AddAmount = AddAmount + 20

				OptionButton.Name = "OptionButton"
				OptionButton.Parent = SelectorContainer
				OptionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				OptionButton.BackgroundTransparency = 1.000
				OptionButton.Size = UDim2.new(0, 394, 0, 20)
				OptionButton.AutoButtonColor = false
				OptionButton.Font = Library.Font
				OptionButton.Text = NewOption
				OptionButton.TextColor3 = Color3.fromRGB(140, 140, 140)
				OptionButton.TextSize = 14.000
				if OptionButton.Text == Default then
					OptionButton.TextColor3 = Library.AcientColor
					Callback(SelectorText.Text)
				end

				OptionButton.MouseButton1Click:Connect(function()
					for z,x in next, SelectorContainer:GetChildren() do
						if x:IsA("TextButton") then
							TweenService:Create(x, TweenWrapper.Styles["Selector"], {TextColor3 = Color3.fromRGB(140, 140, 140)}):Play()
						end
					end
					TweenService:Create(OptionButton, TweenWrapper.Styles["Selector"], {TextColor3 = Library.AcientColor}):Play()
					SelectorText.Text = OptionButton.Text
					Callback(OptionButton.Text)
				end)

				CheckSizes()
				Size = (Val + AddAmount) + 2

				CheckSizes()
				return self
			end

			local RemoveAmount = 0
			function SelectorFunctions:RemoveOption(Option)
				List[Option] = nil

				RemoveAmount = RemoveAmount + 20
				AddAmount = AddAmount - 20

				for i,v in next, SelectorContainer:GetDescendants() do
					if v:IsA("TextButton") then
						if v.Text == Option then
							v:Destroy()
							Size = (Val - RemoveAmount) + 2
						end
					end
				end

				if SelectorText.Text == Option then
					SelectorText.Text = ". . ."
				end

				CheckSizes()
				return self
			end

			function SelectorFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or Callback
				Callback = NewCallback
				return self
			end

			function SelectorFunctions:Text(NewText)
				NewText = NewText or SelectorLabel.Text
				SelectorLabel.Text = NewText
				return self
			end

			function SelectorFunctions:Hide()
				SelectorFrame.Visible = false
				return self
			end

			function SelectorFunctions:Show()
				SelectorFrame.Visible = true
				return self
			end

			function SelectorFunctions:Remove()
				SelectorFrame:Destroy()
				return self
			end
			return SelectorFunctions
		end

		function Components:NewSlider(Text, Suffix, Compare, CompareSign, Values, Callback)
			Text = Text or "slider"
			Suffix = Suffix or ""
			Compare = Compare or false
			CompareSign = CompareSign or "/"
			Values = Values or {}
			Values = {
				Min = Values.Min or 0,
				Max = Values.Max or 100,
				Default = Values.Default or 0
			}
			Callback = Callback or function() end
			local SliderMaid = CreateCleanupMaid()
			TrackTask(TabMaid, SliderMaid)

			Values.Max = Values.Max + 1

			local SliderFrame = Instance.new("Frame")
			local SliderFolder = Instance.new("Folder")
			local TextboxFolderLayout = Instance.new("UIListLayout")
			local SliderButton = Instance.new("TextButton")
			local SliderButtonCorner = Instance.new("UICorner")
			local SliderBackground = Instance.new("Frame")
			local SliderButtonCorner2 = Instance.new("UICorner")
			local SliderBackgroundLayout = Instance.new("UIListLayout")
			local SliderIndicator = Instance.new("Frame")
			local SliderIndicatorConstraint = Instance.new("UISizeConstraint")
			local SliderIndicatorGradient = Instance.new("UIGradient")
			local SliderIndicatorCorner = Instance.new("UICorner")
			local SliderBackgroundPadding = Instance.new("UIPadding")
			local SliderButtonLayout = Instance.new("UIListLayout")
			local SliderLabel = Instance.new("TextLabel")
			local SliderPadding = Instance.new("UIPadding")
			local SliderValue = Instance.new("TextLabel")

			SliderFrame.Parent = Page
			SliderFrame.BackgroundColor3 = Color3.fromRGB(25,25,25)
			SliderFrame.BackgroundTransparency = 1.000
			SliderFrame.ClipsDescendants = true
			SliderFrame.Position = UDim2.new(0.00499999989, 0, 0.667630076, 0)
			SliderFrame.Size = UDim2.new(0, 394, 0, 40)

			SliderFolder.Parent = SliderFrame

			TextboxFolderLayout.Parent = SliderFolder
			TextboxFolderLayout.FillDirection = Enum.FillDirection.Horizontal
			TextboxFolderLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			TextboxFolderLayout.SortOrder = Enum.SortOrder.LayoutOrder
			TextboxFolderLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
			TextboxFolderLayout.Padding = UDim.new(0, 4)

			SliderButton.Parent = SliderFolder
			SliderButton.BackgroundColor3 = Library.DarkGray
			SliderButton.BackgroundTransparency = Library.Transparency
			SliderButton.Position = UDim2.new(0.348484844, 0, 0.600000024, 0)
			SliderButton.Size = UDim2.new(0, 394, 0, 16)
			SliderButton.AutoButtonColor = false
			SliderButton.Font = Library.Font
			SliderButton.Text = ""
			SliderButton.TextColor3 = Color3.fromRGB(0, 0, 0)
			SliderButton.TextSize = 14.000

			SliderButtonCorner.CornerRadius = UDim.new(0, 2)
			SliderButtonCorner.Parent = SliderButton

			SliderBackground.Parent = SliderButton
			SliderBackground.BackgroundColor3 = Library.DarkGray
			SliderBackground.BackgroundTransparency = Library.Transparency
			SliderBackground.Size = UDim2.new(0, 392, 0, 14)
			SliderBackground.Position = UDim2.new(0, 2, 0, 0)
			SliderBackground.ClipsDescendants = true

			SliderButtonCorner2.CornerRadius = UDim.new(0, 2)
			SliderButtonCorner2.Parent = SliderBackground

			SliderBackgroundLayout.Parent = SliderBackground
			SliderBackgroundLayout.SortOrder = Enum.SortOrder.LayoutOrder
			SliderBackgroundLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			SliderIndicator.Parent = SliderBackground
			SliderIndicator.BorderSizePixel = 0
			SliderIndicator.Position = UDim2.new(0, 0, -0.1, 0)
			SliderIndicator.Size = UDim2.new(0, 0, 0, 12)
			SliderIndicator.BackgroundColor3 = Library.AcientColor

			SliderIndicatorConstraint.Parent = SliderIndicator
			SliderIndicatorConstraint.MaxSize = Vector2.new(392, 12)

			SliderIndicatorGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,255,255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(181, 181, 181))}
			SliderIndicatorGradient.Rotation = 90
			SliderIndicatorGradient.Parent = SliderIndicator

			SliderIndicatorCorner.CornerRadius = UDim.new(0, 2)
			SliderIndicatorCorner.Parent = SliderIndicator

			SliderBackgroundPadding.Parent = SliderBackground
			SliderBackgroundPadding.PaddingBottom = UDim.new(0, 2)
			SliderBackgroundPadding.PaddingLeft = UDim.new(0, 1)
			SliderBackgroundPadding.PaddingRight = UDim.new(0, 1)
			SliderBackgroundPadding.PaddingTop = UDim.new(0, 2)

			SliderButtonLayout.Parent = SliderButton
			SliderButtonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			SliderButtonLayout.SortOrder = Enum.SortOrder.LayoutOrder
			SliderButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			SliderLabel.Parent = SliderFrame
			SliderLabel.BackgroundTransparency = 1.000
			SliderLabel.Size = UDim2.new(0, 396, 0, 24)
			SliderLabel.Font = Library.Font
			SliderLabel.Text = Text
			SliderLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
			SliderLabel.TextSize = 14.000
			SliderLabel.TextWrapped = true
			SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
			SliderLabel.RichText = true

			SliderPadding.Parent = SliderLabel
			SliderPadding.PaddingBottom = UDim.new(0, 6)
			SliderPadding.PaddingLeft = UDim.new(0, 2)
			SliderPadding.PaddingRight = UDim.new(0, 6)
			SliderPadding.PaddingTop = UDim.new(0, 6)

			SliderValue.Parent = SliderLabel
			SliderValue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SliderValue.BackgroundTransparency = 1.000
			SliderValue.Position = UDim2.new(0.577319562, 0, 0, 0)
			SliderValue.Size = UDim2.new(0, 169, 0, 15)
			SliderValue.Font = Library.Font
			SliderValue.Text = Values.Default or ""
			SliderValue.TextColor3 = Color3.fromRGB(140, 140, 140)
			SliderValue.TextSize = 14.000
			SliderValue.TextXAlignment = Enum.TextXAlignment.Right
			TrackTask(SliderMaid, SliderFrame)

			local Calc1 = Values.Max - Values.Min
			local Calc2 = Values.Default - Values.Min
			local Calc3 = Calc2 / Calc1
			local Calc4 = Calc3 * SliderBackground.AbsoluteSize.X
			SliderIndicator.Size = UDim2.new(0, Calc4, 0, 12)
			SliderValue.Text = Values.Default

			TweenWrapper:CreateStyle("slider_drag", 0.05, Enum.EasingStyle.Linear)

			local ValueNum = Values.Default
			local SlideText = Compare and ValueNum .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix
			SliderValue.Text = SlideText
			local MoveConnection = nil
			local ReleaseConnection = nil

			local function DisconnectSliderDrag()
				if MoveConnection then
					MoveConnection:Disconnect()
					MoveConnection = nil
				end

				if ReleaseConnection then
					ReleaseConnection:Disconnect()
					ReleaseConnection = nil
				end
			end

			TrackTask(SliderMaid, DisconnectSliderDrag)

			local function UpdateSliderVisual()
				local SliderWidth = SliderBackground.AbsoluteSize.X
				local RelativeX = math.clamp(Mouse.X - SliderBackground.AbsolutePosition.X, 0, SliderWidth)
				SliderIndicator.Size = UDim2.new(0, RelativeX, 0, 12)
			end

			local function UpdateSlider()
				DisconnectSliderDrag()
				UpdateSliderVisual()

				ValueNum = math.floor((((tonumber(Values.Max) - tonumber(Values.Min)) / SliderBackground.AbsoluteSize.X) * SliderIndicator.AbsoluteSize.X) + tonumber(Values.Min)) or 0.00

				local SlideText = Compare and ValueNum .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix

				SliderValue.Text = SlideText

				pcall(function()
					Callback(ValueNum)
				end)

				SliderValue.Text = SlideText

				MoveConnection = Mouse.Move:Connect(function()
					UpdateSliderVisual()
					ValueNum = math.floor((((tonumber(Values.Max) - tonumber(Values.Min)) / SliderBackground.AbsoluteSize.X) * SliderIndicator.AbsoluteSize.X) + tonumber(Values.Min))

					SlideText = Compare and ValueNum .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix
					SliderValue.Text = SlideText

					pcall(function()
						Callback(ValueNum)
					end)

					if not UserInputService.WindowFocused then
						DisconnectSliderDrag()
					end
				end)

				ReleaseConnection = UserInputService.InputEnded:Connect(function(Mouse_2)
					if Mouse_2.UserInputType == Enum.UserInputType.MouseButton1 then
						UpdateSliderVisual()
						ValueNum = math.floor((((tonumber(Values.Max) - tonumber(Values.Min)) / SliderBackground.AbsoluteSize.X) * SliderIndicator.AbsoluteSize.X) + tonumber(Values.Min))

						SlideText = Compare and ValueNum .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix
						SliderValue.Text = SlideText

						pcall(function()
							Callback(ValueNum)
						end)

						DisconnectSliderDrag()
					end
				end)
			end

			ConnectTracked(SliderMaid, SliderButton.MouseButton1Down, function()
				UpdateSlider()
			end)

			local SliderFunctions = {}
			RegisterOptionState(SliderButton, Values.Default, SliderFunctions, SliderMaid)

			function SliderFunctions:Set(NewValue, NoCallback)
				local NCalc1 = NewValue - Values.Min
				local NCalc2 = NCalc1 / Calc1
				local NCalc3 = NCalc2 * SliderBackground.AbsoluteSize.X
				local NCalculation = NCalc3
				SliderIndicator.Size = UDim2.new(0, NCalculation, 0, 12)
				SlideText = Compare and NewValue .. CompareSign .. tostring(Values.Max - 1) .. Suffix or NewValue .. Suffix
				SliderValue.Text = SlideText
				if not NoCallback then
					Callback(NewValue)
				end
				return self
			end
			SliderFunctions:Set(Values.Default, true)

			function SliderFunctions:Max(NewMax)
				NewMax = NewMax or Values.Max
				Values.Max = NewMax + 1
				SlideText = Compare and ValueNum .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix
				return self
			end

			function SliderFunctions:Min(NewMin)
				NewMin = NewMin or Values.Min
				Values.Min = NewMin
				SlideText = Compare and NewMin .. CompareSign .. tostring(Values.Max - 1) .. Suffix or ValueNum .. Suffix
				UpdateSliderVisual()
				return self
			end

			function SliderFunctions:SetFunction(NewCallback)
				NewCallback = NewCallback or Callback
				Callback = NewCallback
				return self
			end

			function SliderFunctions:GetValue()
				return ValueNum
			end

			function SliderFunctions:SetText(NewText)
				NewText = NewText or SliderLabel.Text
				SliderLabel.Text = NewText
				return self
			end

			function SliderFunctions:Hide()
				SliderFrame.Visible = false
				return self
			end

			function SliderFunctions:Show()
				SliderFrame.Visible = true
				return self
			end

			function SliderFunctions:Remove()
				DoCleaning(SliderMaid)
				return self
			end
			return SliderFunctions
		end

		function Components:NewSeperator()
			local SectionFrame = Instance.new("Frame")
			local SectionLayout = Instance.new("UIListLayout")
			local RightBar = Instance.new("Frame")

			SectionFrame.Name = "SectionFrame"
			SectionFrame.Parent = Page
			SectionFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			SectionFrame.BackgroundTransparency = 1.000
			SectionFrame.ClipsDescendants = true
			SectionFrame.Position = UDim2.new(0.00499999989, 0, 0.361271679, 0)
			SectionFrame.Size = UDim2.new(0, 396, 0, 12)

			SectionLayout.Name = "SectionLayout"
			SectionLayout.Parent = SectionFrame
			SectionLayout.FillDirection = Enum.FillDirection.Horizontal
			SectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
			SectionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			SectionLayout.Padding = UDim.new(0, 4)

			RightBar.Name = "RightBar"
			RightBar.Parent = SectionFrame
			RightBar.BackgroundColor3 = Library.DarkGray
			RightBar.BackgroundTransparency = Library.Transparency
			RightBar.BorderSizePixel = 0
			RightBar.Position = UDim2.new(0.308080822, 0, 0.479166657, 0)
			RightBar.Size = UDim2.new(0, 403, 0, 1)

			local SeperatorFunctions = {}
			function SeperatorFunctions:Hide()
				SectionFrame.Visible = false
				return SeperatorFunctions
			end

			function SeperatorFunctions:Show()
				SectionFrame.Visible = true
				return SeperatorFunctions
			end

			function SeperatorFunctions:Remove()
				SectionFrame:Destroy()
				return SeperatorFunctions
			end
			return SeperatorFunctions
		end

			function Components:Open()
				Library.CurrentTab = Title
			for i,v in next, Container:GetChildren() do
				if v:IsA("ScrollingFrame") then
					v.Visible = false
				end
			end
			Page.Visible = true

			for i,v in next, TabButtons:GetChildren() do
				if v:IsA("TextButton") then
					TweenService:Create(v, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Color3.fromRGB(170, 170, 170)}):Play()
				end
			end
			TweenService:Create(TabButton, TweenWrapper.Styles["tab_text_colour"], {TextColor3 = Library.AcientColor}):Play()

			return Components
		end

		function Components:Remove()
			DoCleaning(TabMaid)

			return Components
		end

		function Components:Hide()
			TabButton.Visible = false
			Page.Visible = false

			return Components
		end

		function Components:Show()
			TabButton.Visible = true

			return Components
		end

		function Components:Text(Text)
			Text = Text or "new text"
			TabButton.Text = Text

			return Components
		end
		return Components
	end

	function Library:Remove()
		if self._IsRemoving then
			return self
		end

		self._IsRemoving = true
		FireSignal(self.Removing, self)

		pcall(function()
			Library:Panic()
		end)

		pcall(function()
			self:ShowUI(false)
		end)

		DoCleaning(self._CleanupMaid)
		FireSignal(self.Removed, self)
		DoCleaning(self._SignalMaid)

		return self
	end

	return Library
end

return Library

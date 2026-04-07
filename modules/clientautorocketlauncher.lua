if not getmetatable or not setmetatable or not type or not select or type(select(2, pcall(getmetatable, setmetatable({}, {__index = function(self, ...) while true do end end})))['__index']) ~= 'function' or not pcall or not debug or not rawget or not rawset or not pcall(rawset,{}," "," ") or getmetatable(require) or getmetatable(print) or getmetatable(error) or ({debug.info(print,'a')})[1]~=0 or ({debug.info(tostring,'a')})[1]~=0 or ({debug.info(print,'a')})[2]~=true or not select or not getfenv or select(1, pcall(getfenv, 69)) == true or not select(2, pcall(rawget, debug, "info")) or #(((select(2, pcall(rawget, debug, "info")))(getfenv, "n")))<=1 or #(((select(2, pcall(rawget, debug, "info")))(print, "n")))<=1 or not (select(2, pcall(rawget, debug, "info")))(print, "s") == "[C]" or not (select(2, pcall(rawget, debug, "info")))(require, "s") == "[C]" or (select(2, pcall(rawget, debug, "info")))((function()end), "s") == "[C]" or not select(1, pcall(debug.info, coroutine.wrap(function() end)(), 's')) == false then return false and tostring([[]]) or nil end
if not LPH_OBFUSCATED then function LPH_JIT(Function) return Function end function LPH_JIT_MAX(Function) return Function end function LPH_NO_VIRTUALIZE(Function) return Function end function LPH_ENCSTR(Value) return Value end end

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AutoFireDelay = 0.25
local CombatServiceScanInterval = 1
local DefaultLookVector = Vector3.new(0, 0, -1)
local ExplosionRadius = 6
local FlatLookVectorMask = Vector3.new(1, 0, 1)
local GlobalKey = LPH_ENCSTR("__ClientAutoRocketLauncher")
local HittableTagName = "Hittable"
local RocketBrightness = 1
local RocketImpulse = Vector3.zero
local RocketLifetime = 6
local RocketMoveId = LPH_ENCSTR("RocketLauncher")
local RocketSize = 5
local RocketVelocity = 1000
local RootPartName = LPH_ENCSTR("HumanoidRootPart")

local GlobalEnv = getgenv and getgenv() or _G
local LocalPlayer = Players.LocalPlayer

local WaitForPath = LPH_NO_VIRTUALIZE(function(Root, PathSegments)
	local Current = Root

	for Index = 1, #PathSegments do
		Current = Current:WaitForChild(PathSegments[Index])
	end

	return Current
end)

local AllStarsFolder = ReplicatedStorage:WaitForChild(LPH_ENCSTR("AllStars"))

local AllStarsNoobClientModule = WaitForPath(AllStarsFolder, {
	"game",
	"Client",
	"Characters",
	"AllStarsNoobClient",
})
local BulletInterruptionTypesModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"bullet",
	"Shared",
	"Model",
	"BulletInterruptionTypes",
})
local CombatSoundEffectUtilsModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"combat",
	"Shared",
	"Effects",
	"CombatSoundEffectUtils",
})
local CombatStateHelperModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quentystudios",
	"combat",
	"Shared",
	"System",
	"CombatStateHelper",
})
local ParticleEmitterUtilsModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quenty",
	"particles",
	"Shared",
	"ParticleEmitterUtils",
})
local SoundUtilsModule = WaitForPath(AllStarsFolder, {
	"node_modules",
	"@quenty",
	"soundplayer",
	"node_modules",
	"@quenty",
	"sounds",
	"Shared",
	"SoundUtils",
})

local AllStarsNoobBinder = require(AllStarsNoobClientModule)
local BulletInterruptionTypes = require(BulletInterruptionTypesModule)
local CombatSoundEffectUtils = require(CombatSoundEffectUtilsModule)
local CombatStateHelperType = require(CombatStateHelperModule)
local NoobClientClass = assert(AllStarsNoobBinder:GetConstructor(), "Missing AllStarsNoob constructor")
local ParticleEmitterUtils = require(ParticleEmitterUtilsModule)
local SoundUtils = require(SoundUtilsModule)

local ClientAutoRocketLauncher = {}
local State = {
	ActiveRocketMaids = {},
	CachedCombatServiceClient = nil,
	CachedCombatStateHelper = nil,
	CachedCombatStateHelperOwner = nil,
	IsStarted = false,
	IsStarting = false,
	IsStopping = false,
	LastCombatServiceSearchTime = 0,
	LastError = nil,
	OriginalCanUseMove = nil,
	OriginalRocketActivated = nil,
	OriginalSpecialCooldown = nil,
	RuntimeMaid = nil,
}

local function CreateMaid()
	local Maid = rawget(GlobalEnv, "Maid")
	if type(Maid) ~= "table" then
		return nil, "ClientAutoRocketLauncher requires global Maid"
	end

	local Constructor = Maid.New or Maid.new
	if type(Constructor) ~= "function" then
		return nil, "ClientAutoRocketLauncher requires global Maid.New()"
	end

	local Success, MaidObject = pcall(Constructor)
	if not Success or type(MaidObject) ~= "table" then
		return nil, Success and "ClientAutoRocketLauncher failed to create a Maid" or MaidObject
	end

	return MaidObject
end

local function DestroyMaid(MaidObject)
	if MaidObject and type(MaidObject.Destroy) == "function" then
		pcall(MaidObject.Destroy, MaidObject)
	end
end

local function ResetCachedCombatObjects()
	State.CachedCombatServiceClient = nil
	State.CachedCombatStateHelper = nil
	State.CachedCombatStateHelperOwner = nil
	State.LastCombatServiceSearchTime = 0
end

local function ClearActiveRocketMaids()
	local ActiveRocketMaids = State.ActiveRocketMaids
	State.ActiveRocketMaids = {}

	for RocketMaid in pairs(ActiveRocketMaids) do
		DestroyMaid(RocketMaid)
	end
end

local function RegisterRocketMaid(NoobClient, RocketMaid)
	State.ActiveRocketMaids[RocketMaid] = true

	RocketMaid:GiveTask(function()
		State.ActiveRocketMaids[RocketMaid] = nil

		local NoobMaid = NoobClient and NoobClient._maid
		if type(NoobMaid) == "table" and NoobMaid[RocketMaid] == RocketMaid then
			NoobMaid[RocketMaid] = nil
		end
	end)

	local NoobMaid = NoobClient and NoobClient._maid
	if type(NoobMaid) == "table" then
		NoobMaid[RocketMaid] = RocketMaid
	end
end

local function IsCombatServiceClientCandidate(GcObject)
	if type(GcObject) ~= "table" then
		return false
	end

	return rawget(GcObject, "_serviceBag") ~= nil
		and rawget(GcObject, "_maid") ~= nil
		and rawget(GcObject, "_combatStateHelperValue") ~= nil
		and rawget(GcObject, "_controlsDisabled") ~= nil
		and rawget(GcObject, "_remoting") ~= nil
end

local GetCombatServiceClient = LPH_NO_VIRTUALIZE(function()
	local CombatServiceClient = State.CachedCombatServiceClient
	if IsCombatServiceClientCandidate(CombatServiceClient) then
		return CombatServiceClient
	end

	local Now = os.clock()
	if Now - State.LastCombatServiceSearchTime < CombatServiceScanInterval then
		return nil
	end

	State.LastCombatServiceSearchTime = Now

	local Success, GcObjects = pcall(getgc, true)
	if not Success or type(GcObjects) ~= "table" then
		Success, GcObjects = pcall(getgc)
		if not Success or type(GcObjects) ~= "table" then
			return nil
		end
	end

	for Index = 1, #GcObjects do
		local GcObject = GcObjects[Index]
		if IsCombatServiceClientCandidate(GcObject) then
			State.CachedCombatServiceClient = GcObject
			State.CachedCombatStateHelper = nil
			State.CachedCombatStateHelperOwner = nil
			return GcObject
		end
	end

	return nil
end)

local function GetCombatStateHelper(CombatServiceClient)
	if not CombatServiceClient then
		return nil
	end

	if State.CachedCombatStateHelper and State.CachedCombatStateHelperOwner == CombatServiceClient then
		return State.CachedCombatStateHelper
	end

	local Success, CombatStateHelper = pcall(CombatServiceClient.GetStateHelper, CombatServiceClient)
	if not Success then
		State.CachedCombatStateHelper = nil
		State.CachedCombatStateHelperOwner = nil
		return nil
	end

	State.CachedCombatStateHelper = CombatStateHelper
	State.CachedCombatStateHelperOwner = CombatServiceClient
	return CombatStateHelper
end

local function HasRocketMove(Character)
	if not Character then
		return false
	end

	local MoveProperties = Character:FindFirstChild("MoveProperties")
	if not MoveProperties then
		return false
	end

	return MoveProperties:FindFirstChild(RocketMoveId, true) ~= nil
end

local function PrepareRocket(CombatStateHelper)
	local CombatProperties = CombatStateHelper and CombatStateHelper:GetCombatProperties()
	if not CombatProperties or not CombatStateHelper:GetSyncedClock() then
		return
	end

	local CombatState = CombatProperties.State
	CombatState.InCombatMode.Value = true
	CombatState.NextPunchTime.Value = 0
	CombatState.NextStaminaRegenTime.Value = 0

	if CombatState.Stamina and CombatProperties.StaminaMax then
		CombatState.Stamina.Value = CombatProperties.StaminaMax.Value
	end

	local SpecialCooldownsObject = rawget(CombatStateHelper, "_specialCooldowns")
	local SpecialCooldownsValue = SpecialCooldownsObject and SpecialCooldownsObject.Value
	if type(SpecialCooldownsValue) ~= "table" then
		return
	end

	local SpecialCooldowns = table.clone(SpecialCooldownsValue)
	SpecialCooldowns[RocketMoveId] = {
		startTime = os.clock(),
		duration = 0,
	}
	SpecialCooldownsObject.Value = SpecialCooldowns
end

local function FireRocketSpecial(CombatServiceClient)
	if not CombatServiceClient then
		return false
	end

	pcall(CombatServiceClient.SetInCombatMode, CombatServiceClient, true)

	local Success = pcall(CombatServiceClient.Attack, CombatServiceClient, RocketMoveId)
	return Success
end

local function GetRocketSpawnCFrame(RootPart)
	local TargetPosition = RootPart.Position
	local FlatLookVector = RootPart.CFrame.LookVector * FlatLookVectorMask

	if FlatLookVector.Magnitude <= 0 then
		FlatLookVector = DefaultLookVector
	else
		FlatLookVector = FlatLookVector.Unit
	end

	return CFrame.lookAt(TargetPosition, TargetPosition + FlatLookVector)
end

local function GetRocketDirection(SpawnPosition, TargetPosition, FallbackDirection)
	local AimOffset = TargetPosition - SpawnPosition
	if AimOffset.Magnitude > 0 then
		return AimOffset.Unit
	end

	if FallbackDirection and FallbackDirection.Magnitude > 0 then
		return FallbackDirection.Unit
	end

	return DefaultLookVector
end

local function RocketInterruptionMatches(InterruptionType)
	return InterruptionType == BulletInterruptionTypes.PENETRATION
		or InterruptionType == BulletInterruptionTypes.RICOCHET
		or InterruptionType == BulletInterruptionTypes.RICOCHET_DEATH
		or InterruptionType == BulletInterruptionTypes.PENETRATION_DEATH
end

local function PlayRocketFromRootPart(NoobClient, AttackData, RootPart)
	local Character = NoobClient and NoobClient._obj
	if not Character or not RootPart then
		return
	end

	local RocketMaid, MaidError = CreateMaid()
	if not RocketMaid then
		State.LastError = MaidError
		return
	end

	RegisterRocketMaid(NoobClient, RocketMaid)

	local SpawnCFrame = GetRocketSpawnCFrame(RootPart)
	local TargetPosition = RootPart.Position
	local RocketDirection = GetRocketDirection(SpawnCFrame.Position, TargetPosition, RootPart.CFrame.LookVector)
	local Rocket = RocketMaid:Add(NoobClient._templates:Clone("NoobRocket"))
	local RocketParent = Workspace.CurrentCamera or Workspace

	Rocket.Archivable = false
	Rocket:PivotTo(SpawnCFrame)
	Rocket.Parent = RocketParent

	local SmokeAttachment = RocketMaid:Add(Instance.new("Attachment"))
	SmokeAttachment.Name = "RocketSpawnAttachment"
	SmokeAttachment.Parent = RootPart
	SmokeAttachment.WorldCFrame = SpawnCFrame

	local LaunchSmoke = RocketMaid:Add(NoobClient._templates:Clone("NoobRocketLaunchSmoke"))
	LaunchSmoke.Parent = SmokeAttachment

	local LaunchSmokeTask = ParticleEmitterUtils.playAllEmitters(LaunchSmoke)
	if LaunchSmokeTask then
		RocketMaid:GiveTask(LaunchSmokeTask)
	end

	local LaunchTrail = RocketMaid:Add(NoobClient._templates:Clone("NoobRocketLaunchTrail"))
	LaunchTrail.Parent = Rocket

	local BulletHandle = RocketMaid:Add(NoobClient._helper:FireBullet(AttackData, {
		sourceAdornee = Rocket,
		position = SpawnCFrame.Position,
		velocity = RocketDirection * RocketVelocity,
		brightness = RocketBrightness,
		size = RocketSize,
		bloom = 0,
		color = ColorSequence.new(Rocket.Color),
	}, function()
	end))
	local Bullet = BulletHandle and BulletHandle._bullet
	if not Bullet then
		DestroyMaid(RocketMaid)
		return
	end

	NoobClient._helper:ImpulseLocalCamera(RocketImpulse)

	local WhooshSound = SoundUtils.playFromIdInParent("rbxasset://sounds/Rocket whoosh 01.wav", Rocket)
	if WhooshSound then
		CombatSoundEffectUtils.adjustSoundRolloff(WhooshSound)
		NoobClient._soundEffectService:RegisterSFX(WhooshSound)
	end

	RocketMaid:GiveTask(RunService.Heartbeat:Connect(function()
		if not Bullet:IsDead() then
			local BulletPosition = Bullet:GetPosition()
			local BulletVelocity = Bullet:GetVelocity()

			if BulletVelocity.Magnitude > 0 then
				Rocket.CFrame = CFrame.lookAt(BulletPosition, BulletPosition + BulletVelocity)
			else
				Rocket.Position = BulletPosition
			end
		end
	end))

	local Trail = LaunchTrail:FindFirstChildOfClass("Trail")
	if Trail then
		Trail.Enabled = true
	end

	local CanApplyExplosionDamage = true
	RocketMaid:GiveTask(Bullet.BulletInterruption:Connect(function(InterruptionData)
		if not State.ActiveRocketMaids[RocketMaid] then
			return
		end

		if not RocketInterruptionMatches(InterruptionData.interruptionType) or not InterruptionData.hitInstance then
			return
		end

		pcall(function()
			Rocket.Transparency = 1
			Rocket.Anchored = true

			if WhooshSound then
				WhooshSound:Destroy()
			end

			local ExplosionEffect = RocketMaid:Add(NoobClient._templates:Clone("NoobRocketExplosion"))
			ExplosionEffect.WorldCFrame = CFrame.new(InterruptionData.p)
			ExplosionEffect.Parent = Workspace

			local SurfaceHit = Workspace:Raycast(InterruptionData.p - RocketDirection * 0.01, RocketDirection * 4)
			if SurfaceHit then
				local ExplosionVfxTask = NoobClient._vfxHelper:NoobRocketExplosionVFX(InterruptionData.p, SurfaceHit.Normal)
				if ExplosionVfxTask then
					RocketMaid:GiveTask(ExplosionVfxTask)
				end
			end

			local CollideSound = SoundUtils.playFromIdInParent("rbxasset://sounds/collide.wav", ExplosionEffect)
			if CollideSound then
				CombatSoundEffectUtils.adjustSoundRolloff(CollideSound)
				NoobClient._soundEffectService:RegisterSFX(CollideSound)
			end

			for _, ParticleEmitter in ParticleEmitterUtils.getParticleEmitters(LaunchTrail) do
				ParticleEmitter.Enabled = false
			end

			local ExplosionEmitterTask = ParticleEmitterUtils.playAllEmitters(ExplosionEffect)
			if ExplosionEmitterTask then
				RocketMaid:GiveTask(ExplosionEmitterTask)
			end

			if NoobClient._player == LocalPlayer and CanApplyExplosionDamage then
				CanApplyExplosionDamage = false
				NoobClient._overlapParams.FilterDescendantsInstances = CollectionService:GetTagged(HittableTagName)

				local HitParts = Workspace:GetPartBoundsInRadius(InterruptionData.p, ExplosionRadius, NoobClient._overlapParams)
				Rocket.Position = InterruptionData.p
				NoobClient._helper:AttackFromPartList(HitParts, Rocket, AttackData, true)
			end
		end)
	end))

	RocketMaid:GiveTask(task.delay(RocketLifetime, function()
		DestroyMaid(RocketMaid)
	end))
end

local function PatchedCanUseMove(Self, MoveId)
	if not State.IsStarted or MoveId ~= RocketMoveId then
		return State.OriginalCanUseMove(Self, MoveId)
	end

	if not Self:CanDoAnyStaminaAction() then
		return false
	end

	local CombatProperties = Self:GetCombatProperties()
	local CombatState = CombatProperties and CombatProperties.State
	if not CombatState then
		return false
	end

	if CombatState.IsGrabbed and CombatState.IsGrabbed.Value then
		return false
	end

	return true
end

local function PatchedSpecialCooldown(Self, MoveId, CooldownTimeSeconds)
	if not State.IsStarted or MoveId ~= RocketMoveId then
		return State.OriginalSpecialCooldown(Self, MoveId, CooldownTimeSeconds)
	end

	return State.OriginalSpecialCooldown(Self, MoveId, 0)
end

local function PatchedRocketActivated(NoobClient, AttackData)
	if not State.IsStarted or NoobClient._player ~= LocalPlayer then
		return State.OriginalRocketActivated(NoobClient, AttackData)
	end

	local TargetRootParts = {}

	local PlayerList = Players:GetPlayers()
	for Index = 1, #PlayerList do
		local Player = PlayerList[Index]
		if Player ~= LocalPlayer then
			local Character = Player.Character
			local RootPart = Character and Character:FindFirstChild(RootPartName)
			if RootPart then
				TargetRootParts[#TargetRootParts + 1] = RootPart
			end
		end
	end

	local NpcList = CollectionService:GetTagged("CombatNPC")
	for Index = 1, #NpcList do
		local NpcModel = NpcList[Index]
		local RootPart = NpcModel:IsA("Model") and NpcModel:FindFirstChild(RootPartName)
		if RootPart then
			TargetRootParts[#TargetRootParts + 1] = RootPart
		end
	end

	for Index = 1, #TargetRootParts do
		local Success, ErrorMessage = pcall(PlayRocketFromRootPart, NoobClient, AttackData, TargetRootParts[Index])
		if not Success then
			State.LastError = ErrorMessage
		end
	end
end

local RunAutoFireLoop = LPH_JIT_MAX(function()
	while State.IsStarted do
		local Character = LocalPlayer.Character
		if Character and HasRocketMove(Character) then
			local CombatServiceClient = GetCombatServiceClient()
			if CombatServiceClient then
				local CombatStateHelper = GetCombatStateHelper(CombatServiceClient)
				if CombatStateHelper then
					PrepareRocket(CombatStateHelper)
					FireRocketSpecial(CombatServiceClient)
				end
			end
		end

		task.wait(AutoFireDelay)
	end
end)

local function RestorePatchedValues()
	if NoobClientClass._rocketActivated == PatchedRocketActivated and State.OriginalRocketActivated then
		NoobClientClass._rocketActivated = State.OriginalRocketActivated
	end

	if CombatStateHelperType.CanUseMove == PatchedCanUseMove and State.OriginalCanUseMove then
		CombatStateHelperType.CanUseMove = State.OriginalCanUseMove
	end

	if CombatStateHelperType.SpecialCooldown == PatchedSpecialCooldown and State.OriginalSpecialCooldown then
		CombatStateHelperType.SpecialCooldown = State.OriginalSpecialCooldown
	end

	State.OriginalRocketActivated = nil
	State.OriginalCanUseMove = nil
	State.OriginalSpecialCooldown = nil
end

local function ApplyClientAutoRocketLauncher()
	if type(getgc) ~= "function" then
		return false, "ClientAutoRocketLauncher requires getgc()"
	end

	local ExistingModule = rawget(GlobalEnv, GlobalKey)
	if ExistingModule and ExistingModule ~= ClientAutoRocketLauncher and type(ExistingModule.Stop) == "function" then
		local DidStop, StopResult, StopError = pcall(ExistingModule.Stop, ExistingModule)
		if not DidStop or not StopResult then
			return false, DidStop and (StopError or "ClientAutoRocketLauncher failed to stop the previous module") or StopResult
		end
	end

	local RuntimeMaid, MaidError = CreateMaid()
	if not RuntimeMaid then
		return false, MaidError
	end

	State.RuntimeMaid = RuntimeMaid
	State.ActiveRocketMaids = {}
	ResetCachedCombatObjects()

	local OriginalRocketActivated = NoobClientClass._rocketActivated
	local OriginalCanUseMove = CombatStateHelperType.CanUseMove
	local OriginalSpecialCooldown = CombatStateHelperType.SpecialCooldown
	if type(OriginalRocketActivated) ~= "function" then
		return false, "Missing AllStarsNoobClient._rocketActivated"
	end

	if type(OriginalCanUseMove) ~= "function" then
		return false, "Missing CombatStateHelper.CanUseMove"
	end

	if type(OriginalSpecialCooldown) ~= "function" then
		return false, "Missing CombatStateHelper.SpecialCooldown"
	end

	State.OriginalRocketActivated = OriginalRocketActivated
	State.OriginalCanUseMove = OriginalCanUseMove
	State.OriginalSpecialCooldown = OriginalSpecialCooldown

	NoobClientClass._rocketActivated = PatchedRocketActivated
	CombatStateHelperType.CanUseMove = PatchedCanUseMove
	CombatStateHelperType.SpecialCooldown = PatchedSpecialCooldown

	State.IsStarted = true
	GlobalEnv[GlobalKey] = ClientAutoRocketLauncher

	RuntimeMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
		ResetCachedCombatObjects()
		ClearActiveRocketMaids()
	end))
	RuntimeMaid:GiveTask(task.spawn(RunAutoFireLoop))

	return true
end

local function CleanupClientAutoRocketLauncher()
	State.IsStarted = false

	local RuntimeMaid = State.RuntimeMaid
	State.RuntimeMaid = nil

	DestroyMaid(RuntimeMaid)
	ClearActiveRocketMaids()
	RestorePatchedValues()
	ResetCachedCombatObjects()

	if rawget(GlobalEnv, GlobalKey) == ClientAutoRocketLauncher then
		GlobalEnv[GlobalKey] = nil
	end

	return true
end

local function FinalizeClientAutoRocketLauncherUnload()
	State.IsStarted = false
	State.IsStarting = false
	State.IsStopping = false
end

local function Start()
	if State.IsStarting then
		return false, "ClientAutoRocketLauncher is already starting"
	end

	if State.IsStopping then
		return false, "ClientAutoRocketLauncher is still stopping"
	end

	if State.IsStarted then
		return true
	end

	State.IsStarting = true

	local DidApply, ApplyResult, ApplyError = pcall(ApplyClientAutoRocketLauncher)
	State.IsStarting = false

	if DidApply and ApplyResult then
		State.LastError = nil
		return true
	end

	local StartError = DidApply and (ApplyError or "Failed to start ClientAutoRocketLauncher") or ApplyResult
	State.LastError = StartError

	local DidCleanup, CleanupError = pcall(CleanupClientAutoRocketLauncher)
	if not DidCleanup then
		State.LastError = CleanupError
		return false, CleanupError
	end

	FinalizeClientAutoRocketLauncherUnload()
	return false, StartError
end

local function Stop()
	if State.IsStarting then
		return false, "ClientAutoRocketLauncher is still starting"
	end

	if State.IsStopping then
		return false, "ClientAutoRocketLauncher is already stopping"
	end

	if not State.IsStarted and not State.RuntimeMaid then
		return true
	end

	State.IsStopping = true

	local DidCleanup, CleanupError = pcall(CleanupClientAutoRocketLauncher)
	if not DidCleanup then
		State.LastError = CleanupError
		State.IsStopping = false
		return false, CleanupError
	end

	State.LastError = nil
	FinalizeClientAutoRocketLauncherUnload()
	return true
end

ClientAutoRocketLauncher.Start = Start
ClientAutoRocketLauncher.Stop = Stop
ClientAutoRocketLauncher.Destroy = Stop

function ClientAutoRocketLauncher.IsStarted()
	return State.IsStarted
end

function ClientAutoRocketLauncher.GetLastError()
	return State.LastError
end

return ClientAutoRocketLauncher

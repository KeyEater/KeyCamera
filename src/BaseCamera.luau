--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local Inputs = require(script.Parent:WaitForChild("Inputs"))
local ZoomController = require(script.Parent:WaitForChild("ZoomController"))

local function DisconnectAll(Connections: { RBXScriptConnection })
	for _, c in ipairs(Connections) do
		c:Disconnect()
	end
	table.clear(Connections)
end

-- Variables
local savedRotationType, savedMouseBehavior
local lastRotationTypeOverride: Enum.RotationType?
local lastMouseBehaviorOverride: Enum.MouseBehavior?

-- Constants
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

local ZERO_VECTOR3 = Vector3.new(0, 0, 0)

local HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)

local ZOOM_SENSITIVITY_CURVATURE = 0.5
local FIRST_PERSON_DISTANCE_MIN = 0.5

local DEFAULT_CAMERA_MIN_ZOOM_DISTANCE = 0.5
local DEFAULT_CAMERA_MAX_ZOOM_DISTANCE = 400

local FIRST_PERSON_DISTANCE_THRESHOLD = 0.5

type BaseCameraClass = {
	__index: BaseCameraClass,
	new: (DefaultSettings: CameraSettings) -> BaseCamera,

	CheckSettings: (self: BaseCamera) -> (),
	GetSettings: (self: BaseCamera) -> CameraSettings,
	UpdateSettings: (self: BaseCamera, preset: CameraSettings) -> (),
	UpdateMouseBehavior: (self: BaseCamera) -> (),
	ApplyRecoil: (self: BaseCamera, recoil: Vector2) -> (),
	GetSubjectPosition: (self: BaseCamera) -> Vector3,
	EnterFirstPerson: (self: BaseCamera) -> (),
	LeaveFirstPerson: (self: BaseCamera) -> (),
	SetCameraToSubjectDistance: (self: BaseCamera, desiredDistance: number) -> (),
	CalculateNewLookCFrameFromArg: (self: BaseCamera, suppliedLookVector: Vector3, rotateInput: Vector2) -> CFrame,
	CalculateNewLookVectorFromArg: (self: BaseCamera, suppliedLookVector: Vector3, rotateInput: Vector2) -> Vector3,

	StepZoom: (self: BaseCamera) -> (),
	Update: (self: BaseCamera, dt: number) -> (CFrame, CFrame),

	SetupConfigurations: (self: BaseCamera) -> (),
	Enable: (self: BaseCamera) -> (),
	Disable: (self: BaseCamera) -> (),
}

export type BaseCamera = typeof(setmetatable(
	{} :: {
		enabled: boolean,
		lastCameraMode: Enum.CameraMode?,
		currentSubjectDistance: number,
		lastSubjectPosition: Vector3,
		connections: { RBXScriptConnection },
		settings: CameraSettings,

		recoil: Vector2?,

		inFirstPerson: boolean,
		lastUpdate: number,
	},
	{} :: BaseCameraClass
))

export type CameraSettings = {
	FieldOfView: number,
	Offset: Vector3,
	MouseLock: boolean,
	CanZoom: boolean,
	MinZoom: number,
	MaxZoom: number,
}

local BaseCamera = {}
BaseCamera.__index = BaseCamera

function BaseCamera.new(DefaultSettings: CameraSettings)
	local self: BaseCamera = setmetatable({
		enabled = false,
		lastCameraMode = nil,
		currentSubjectDistance = 10,
		lastSubjectPosition = Vector3.new(),
		connections = {},
		settings = DefaultSettings,

		recoil = Vector2.new(0, 0),

		inFirstPerson = false,
		lastUpdate = 0,
	}, BaseCamera)
	self:CheckSettings()
	return self
end

function BaseCamera:CheckSettings()
	assert(typeof(self.settings.FieldOfView) == "number")
	assert(typeof(self.settings.Offset) == "Vector3")
	assert(typeof(self.settings.MouseLock) == "boolean")
	assert(typeof(self.settings.CanZoom) == "boolean")
	if not self.settings.MinZoom or typeof(self.settings.MinZoom) ~= "number" then
		self.settings.MinZoom = DEFAULT_CAMERA_MIN_ZOOM_DISTANCE
	end
	if not self.settings.MaxZoom or typeof(self.settings.MaxZoom) ~= "number" then
		self.settings.MaxZoom = DEFAULT_CAMERA_MAX_ZOOM_DISTANCE
	end
end

function BaseCamera:GetSettings()
	return self.settings
end

function BaseCamera:UpdateSettings(preset: CameraSettings)
	self.settings = preset
	self:CheckSettings()
end

function BaseCamera:UpdateMouseBehavior()
	if self.inFirstPerson or self.settings.MouseLock then
		if UserGameSettings.RotationType ~= lastRotationTypeOverride then
			savedRotationType = UserGameSettings.RotationType
		end
		UserGameSettings.RotationType = Enum.RotationType.CameraRelative
		lastRotationTypeOverride = Enum.RotationType.CameraRelative
		if UserInputService.MouseBehavior ~= lastMouseBehaviorOverride then
			savedMouseBehavior = UserInputService.MouseBehavior
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		lastMouseBehaviorOverride = Enum.MouseBehavior.LockCenter
	else
		if UserGameSettings.RotationType == lastRotationTypeOverride then
			UserGameSettings.RotationType = savedRotationType
		end
		lastRotationTypeOverride = nil
		if UserInputService.MouseBehavior == lastMouseBehaviorOverride then
			UserInputService.MouseBehavior = savedMouseBehavior
		end
		lastMouseBehaviorOverride = nil
	end
end

function BaseCamera:ApplyRecoil(recoil: Vector2)
	self.recoil += recoil
end

function BaseCamera:GetSubjectPosition(): Vector3
	local result = self.lastSubjectPosition
	local camera = workspace.CurrentCamera
	local subject = camera.CameraSubject

	if not subject then
		return Vector3.new()
	end

	if subject:IsA("Humanoid") then
		local isDead = subject:GetState() == Enum.HumanoidStateType.Dead

		local bodyPartToFollow = subject.RootPart
		if isDead then
			if subject.Parent and subject.Parent:IsA("Model") then
				bodyPartToFollow = subject.Parent:FindFirstChild("Head") or bodyPartToFollow
			end
		end

		if bodyPartToFollow and bodyPartToFollow:IsA("BasePart") then
			local heightOffset
			if subject.RigType == Enum.HumanoidRigType.R15 then
				if subject.AutomaticScalingEnabled then
					heightOffset = R15_HEAD_OFFSET
					if bodyPartToFollow == subject.RootPart then
						local rootPartSizeOffset = (subject.RootPart.Size.Y / 2) - (HUMANOID_ROOT_PART_SIZE.Y / 2)
						heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
					end
				else
					heightOffset = R15_HEAD_OFFSET_NO_SCALING
				end
			else
				heightOffset = HEAD_OFFSET
			end
			if isDead then
				heightOffset = ZERO_VECTOR3
			end
			result = bodyPartToFollow.CFrame.Position + bodyPartToFollow.CFrame:vectorToWorldSpace(heightOffset)
		end
	elseif subject:IsA("BasePart") then
		result = subject.CFrame.Position
	elseif subject:IsA("Model") then
		if subject.PrimaryPart then
			result = subject:GetPrimaryPartCFrame().Position
		else
			result = subject:GetModelCFrame().Position
		end
	end
	return result
end

function BaseCamera:EnterFirstPerson()
	-- TODO: Implement logic to transition the camera into first-person mode.
	-- This may involve setting camera properties, updating UI, and locking controls.
	print("WIP")
end

function BaseCamera:LeaveFirstPerson()
	-- TODO: Implement logic to transition the camera out of first-person mode.
	-- This may involve restoring camera properties, updating UI, and unlocking controls.
	print("wip")
end

function BaseCamera:SetCameraToSubjectDistance(desiredDistance: number)
	local lastDistance = self.currentSubjectDistance

	local newSubjectDistance = math.clamp(desiredDistance, self.settings.MinZoom, self.settings.MaxZoom)
	if newSubjectDistance < FIRST_PERSON_DISTANCE_THRESHOLD then
		self.currentSubjectDistance = 0.5
		if not self.inFirstPerson then
			self:EnterFirstPerson()
		end
	else
		self.currentSubjectDistance = newSubjectDistance
		if self.inFirstPerson then
			self:LeaveFirstPerson()
		end
	end
	-- Pass target distance and zoom direction to the zoom controller
	ZoomController.SetZoomGoal(self.currentSubjectDistance)
end

function BaseCamera:StepZoom()
	local zoom: number = self.currentSubjectDistance
	local zoomDelta = Inputs.getZoomDelta()

	if math.abs(zoomDelta) > 0 then
		local newZoom
		if zoomDelta > 0 then
			newZoom = zoom + zoomDelta * (1 + zoom * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, FIRST_PERSON_DISTANCE_THRESHOLD)
		else
			newZoom = (zoom + zoomDelta) / (1 - zoomDelta * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, FIRST_PERSON_DISTANCE_MIN)
		end

		if newZoom < FIRST_PERSON_DISTANCE_THRESHOLD then
			newZoom = FIRST_PERSON_DISTANCE_MIN
		end

		self:SetCameraToSubjectDistance(newZoom)
	end

	return ZoomController.GetZoomRadius()
end

function BaseCamera:CalculateNewLookCFrameFromArg(suppliedLookVector: Vector3, rotateInput: Vector2): CFrame
	local currLookVector: Vector3 = suppliedLookVector
	local currPitchAngle = math.asin(currLookVector.Y)
	local yTheta = math.clamp(rotateInput.Y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput = Vector2.new(rotateInput.X, yTheta)
	local startCFrame = CFrame.new(ZERO_VECTOR3, currLookVector)
	local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.X, 0)
		* startCFrame
		* CFrame.Angles(-constrainedRotateInput.Y, 0, 0)
	return newLookCFrame
end

function BaseCamera:CalculateNewLookVectorFromArg(suppliedLookVector: Vector3, rotateInput: Vector2): Vector3
	local newLookCFrame = self:CalculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)
	return newLookCFrame.LookVector
end



function BaseCamera:Update(dt: number)
	local now = os.clock()

	local camera = workspace.CurrentCamera
	local newCameraCFrame = camera.CFrame
	local newCameraFocus = camera.Focus

	local cameraLookVector = camera.CFrame.LookVector

	local player = Players.LocalPlayer
	local subjectPosition = self:GetSubjectPosition()

	local rotateInput = Inputs.getRotation() + self.recoil * dt
	-- Clamp rotateInput to prevent floating-point drift
	rotateInput = Vector2.new(
		math.clamp(rotateInput.X, -math.pi, math.pi),
		math.clamp(rotateInput.Y, -math.pi, math.pi)
	)
	self.recoil = self.recoil:Lerp(Vector2.zero, math.min(dt * 10, 1))

	self.recoil = self.recoil:Lerp(Vector2.new(0, 0), math.min(dt * 10, 1))

	self:StepZoom()

	if player and camera and self.settings.MouseLock then
		local zoom = self.currentSubjectDistance
		if not self.inFirstPerson then
			local newLookCFrame: CFrame = self:CalculateNewLookCFrameFromArg(cameraLookVector, rotateInput)
			local offset: Vector3 = self.settings.Offset
			local cameraRelativeOffset: Vector3 = offset.X * newLookCFrame.RightVector
				+ offset.Y * newLookCFrame.UpVector
				+ offset.Z * newLookCFrame.LookVector
			subjectPosition = subjectPosition + cameraRelativeOffset
		end
		newCameraFocus = CFrame.new(subjectPosition)
		local cameraFocusP = newCameraFocus.Position
		local newLookVector = self:CalculateNewLookVectorFromArg(cameraLookVector, rotateInput)

		--newCameraCFrame = CFrame.lookAlong(cameraFocusP - (zoom * newLookVector), newLookVector)
		newCameraCFrame = CFrame.new(cameraFocusP - (zoom * newLookVector), cameraFocusP)
	end

	self.lastUpdate = now
	return newCameraCFrame, newCameraFocus
end

function BaseCamera:SetupConfigurations()
	local camera = workspace.CurrentCamera
	camera.FieldOfView = self.settings.FieldOfView
end

function BaseCamera:Enable()
	if not self.enabled then
		self.enabled = true

		self:SetupConfigurations()
		Inputs.Enable()
		if self.lastCameraMode and self.lastCameraMode == Enum.CameraMode.LockFirstPerson then
			self.currentSubjectDistance = 0.5
			self:EnterFirstPerson()
		end
	end
end

function BaseCamera:Disable()
	if self.enabled then
		self.enabled = false
		DisconnectAll(self.connections)
		Inputs.Disable()
	end
end

function BaseCamera:Destroy()
	self:Disable()
	if lastRotationTypeOverride then
		UserGameSettings.RotationType = savedRotationType
	end
	if lastMouseBehaviorOverride then
		UserInputService.MouseBehavior = savedMouseBehavior
	end
	if self.inFirstPerson then
		self:LeaveFirstPerson()
	end
	DisconnectAll(self.connections)
end

return BaseCamera

--!nonstrict
--[[
	Obstructcam Module
	This module checks whats behind the camera and makes sure it does not clip inside objects or gets obstructed by something passing between the camera and subject.
]]
-- Core Roblox services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

-- Modules
local ZoomController = require(script.Parent:WaitForChild("ZoomController"))

-- Constants
local BYPASS_TAG = "CameraBypass"
local Y_AXIS_INVERSION = CFrame.new(0, 0, 0, -1, 0, 0, 0, 1, 0, 0, 0, -1)
local ZERO_VECTOR3 = Vector3.new(0,0,0)

local HEAD_OFFSET = Vector3.new(0,1.5,0)
local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)

local MIN_FOCUS_DIST = 0.5

local excludeParams = RaycastParams.new()
excludeParams.IgnoreWater = true
excludeParams.FilterType = Enum.RaycastFilterType.Exclude

-- Variables
local camera = workspace.CurrentCamera
local nearPlaneZ, projX, projY
do -- Sets up connections that update the previously declared variables
	local function updateProjection()
    	local fov = math.rad(camera.FieldOfView)
	    local view = camera.ViewportSize
    	local ar = view.X / view.Y
	    projY = 2 * math.tan(fov / 2)
	    projX = ar * projY
	end

	camera:GetPropertyChangedSignal("FieldOfView"):Connect(updateProjection)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateProjection)

	updateProjection()

	nearPlaneZ = camera.NearPlaneZ
	camera:GetPropertyChangedSignal("NearPlaneZ"):Connect(function()
		nearPlaneZ = camera.NearPlaneZ
	end)
end
-- Local functions --
local function GetSubjectPosition(): Vector3
	local subject = camera.CameraSubject
	local result = Vector3.new()

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
						local rootPartSizeOffset = (subject.RootPart.Size.Y/2) - (HUMANOID_ROOT_PART_SIZE.Y/2)
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

-- Class --
local Obstructcam = {}
Obstructcam.__index = Obstructcam

-- Obstructcam constructor
function Obstructcam.new(excldueList, exPlayers)
	local self = setmetatable({
		customExclude = excldueList or {},
		excludePlayer = exPlayers ~= nil and exPlayers or true,
	}, Obstructcam)
	return self
end

function Obstructcam:getExcludeList()
	local list = {}

	for _, obj in ipairs(self.customExclude) do
		table.insert(list, obj)
	end

	if self.excludePlayer then
		for _, player in ipairs(Players:GetChildren()) do
			if player.Character then
				table.insert(list, player.Character)
			end
		end
	end
	local Tagged = CollectionService:GetTagged(BYPASS_TAG)
	for _, obj in ipairs(Tagged) do
		table.insert(list, obj)
	end

	return list
end

-- RenderStep Function -- 
function Obstructcam:Update(dt, desiredCameraCFrame, desiredCameraFocus)
	local rotatedFocus = CFrame.new(desiredCameraFocus.Position, desiredCameraCFrame.Position) * Y_AXIS_INVERSION

	local targetDist = ZoomController.GetGoal()

	local excludeList = self:getExcludeList()
	excludeParams.FilterDescendantsInstances = excludeList

	local obstructZoom = math.huge

	local Focus = rotatedFocus * CFrame.new(0, 0, MIN_FOCUS_DIST)
	local radius = (projX + projY) / 2
	local origin = Focus.Position
	local FocusRaycast = workspace:Spherecast(origin, radius, -Focus.LookVector * (targetDist + nearPlaneZ), excludeParams)
	if FocusRaycast then
		local zoomiest = (FocusRaycast.Position - origin).Magnitude - math.abs(nearPlaneZ)
		if zoomiest < obstructZoom then
			obstructZoom = zoomiest
		end
	end

	local Subject = GetSubjectPosition()
	local SubjectRaycast = workspace:Spherecast(Subject, radius, -Focus.LookVector * (targetDist + nearPlaneZ), excludeParams)
	if SubjectRaycast then
		local zoomiest = (SubjectRaycast.Position - Subject).Magnitude - math.abs(nearPlaneZ)
		if zoomiest < obstructZoom then
			obstructZoom = zoomiest
		end
	end
	obstructZoom -= 0.5

	local zoom = ZoomController.Update(dt, obstructZoom)
	return rotatedFocus * CFrame.new(0, 0, zoom), desiredCameraFocus
end

function Obstructcam:Destroy() 
	self.customExclude = {}
	self.excludePlayer = true
end

return Obstructcam

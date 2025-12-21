--!strict

--[[
    KeyCamera Module
    Handles custom camera control, presets, input bindings, and occlusion for Roblox games.
--]]

local KeyCamera = {}
KeyCamera.__index = KeyCamera

-- Roblox Services
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Static Inputs
local Inputs = require(script:WaitForChild("Inputs"))

-- Camera Controller Module
local BaseCamera = require(script:WaitForChild("BaseCamera"))
-- Occlusion Module
local Obstructcam = require(script:WaitForChild("Obstructcam"))
-- First Person Transparency Module
local TransparencyController = require(script:WaitForChild("TransparencyController"))

-- Ensure LocalPlayer exists before continuing
if not Players.LocalPlayer then
    return ({} :: any)
    
end
assert(Players.LocalPlayer, "Strict type check")
local Player = Players.LocalPlayer

-- Default camera preset settings
local DEFAULT_PRESET: BaseCamera.CameraSettings = {
    FieldOfView = 80,
    Offset = Vector3.new(1, 1, -1),
    MouseLock = true,
    CanZoom = true,
    MinZoom = 0.5,
    MaxZoom = 60
}

type GenericFunction = (any?, any?) -> any?

export type KeyCamera = {
    activeCameraController: BaseCamera.BaseCamera?,
    activeOcclusionModule: any?,
    activeTransparencyController: any,
    connections: { RBXScriptConnection },
    boundActions: { string },
    enabled: boolean,
    presets: { [string]: BaseCamera.CameraSettings },
    previousCameraType: Enum.CameraType?,

    new: () -> KeyCamera,
    SetPerspectiveEventFunction: (self: KeyCamera, PerspecticveEventFunction: GenericFunction, EventFunctionObject: any?) -> (),
    BindTogglePerspectiveToInput: (self: KeyCamera, input: Enum.KeyCode | Enum.UserInputType) -> (),
    AddPreset: (self: KeyCamera, PresetName: string, Preset: BaseCamera.CameraSettings) -> (),
    UsePreset: (self: KeyCamera, PresetName: string) -> (),
    SetPresetToDefault: (self: KeyCamera, PresetName: string) -> (),
    BindPresetToInput: (self: KeyCamera, PresetName: string, input: Enum.KeyCode | Enum.UserInputType, HoldToUse: boolean) -> (),
    UnbindPresetToInput: (self: KeyCamera, PresetName: string) -> (),
    SetCanZoom: (self: KeyCamera, canZoom: boolean) -> (),
    ApplyRecoil: (self: KeyCamera, recoil: Vector2) -> (),
    Update: (self: KeyCamera, dt: number) -> (),
    IsEnabled: (self: KeyCamera) -> boolean,
    Enable: (self: KeyCamera) -> (),
    Disable: (self: KeyCamera) -> (),
    Destroy: (self: KeyCamera) -> (),
}


--Key Camera Constructor
function KeyCamera.new(): KeyCamera

    local self: KeyCamera = setmetatable({
        activeCameraController = BaseCamera.new(DEFAULT_PRESET),
        activeOcclusionModule = Obstructcam.new(),
        activeTransparencyController = TransparencyController.new(),
        connections = {},
		boundActions = {},
        enabled = false,
        presets = {Default = DEFAULT_PRESET},
        previousCameraType = nil,
        previousMouseLock = nil,
    }, KeyCamera) :: any
	-- Initialize camera controller
    RunService:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, function(dt) self:Update(dt) end)

    -- Destroy camera when character is removed
    table.insert(self.connections, Player.CharacterRemoving:Connect(function() self:Destroy() end))

    return self
end

-- Change Perspective --
function KeyCamera:SetPerspectiveEventFunction(PerspecticveEventFunction: GenericFunction, EventFunctionObject: any?)
    self.activeCameraController:SetPerspectiveEvent(PerspecticveEventFunction, EventFunctionObject)
end

function KeyCamera:BindTogglePerspectiveToInput(input: Enum.KeyCode | Enum.UserInputType)
    ContextActionService:UnbindAction(`KeyCamera_TogglePerspective`)
	table.remove(self.boundActions, table.find(self.boundActions, `KeyCamera_TogglePerspective`))

    local function TogglePerspective(_action, state, _input)
        if state == Enum.UserInputState.Begin then
            self.activeCameraController:SwitchPerspective()
        end
    end

    ContextActionService:BindAction(`KeyCamera_TogglePerspective`,TogglePerspective, false, input)
	table.insert(self.boundActions, `KeyCamera_TogglePerspective`)
end

-- Presets Section --

function KeyCamera:AddPreset(PresetName: string, Preset: BaseCamera.CameraSettings)
    self.presets[PresetName] = Preset
end

function KeyCamera:UsePreset(PresetName: string)
    if self.presets[PresetName] then
        self.activeCameraController:UpdateSettings(self.presets[PresetName])
    end
end

function KeyCamera:SetPresetToDefault(PresetName: string)
    local newDefault = self.presets[PresetName]
    if newDefault then
        self.presets["Default"] = newDefault
    end
end

-- Input Binding Section --
--[[
	Binds a preset to an input action.
	If HoldToUse is true, the preset will be applied on input begin and reset on input end.
]]
function KeyCamera:BindPresetToInput(PresetName: string, input: Enum.KeyCode | Enum.UserInputType, HoldToUse: boolean)
    if not self.presets[PresetName] then
        return
    end
    local lastSettings = self.activeCameraController:GetSettings()
    local function CAfunction(action, state, input)
        if state == Enum.UserInputState.Begin then
            lastSettings = self.activeCameraController:GetSettings()
            self.activeCameraController:UpdateSettings(self.presets[PresetName])
        elseif HoldToUse and state == Enum.UserInputState.End then
            self.activeCameraController:UpdateSettings(lastSettings)
        end
    end
    ContextActionService:BindAction(`KeyCamera_{PresetName}`,CAfunction, false, input)
	table.insert(self.boundActions, `KeyCamera_{PresetName}`)
end

function KeyCamera:UnbindPresetToInput(PresetName: string)
    ContextActionService:UnbindAction(`KeyCamera_{PresetName}`)
	table.remove(self.boundActions, table.find(self.boundActions, `KeyCamera_{PresetName}`))
end


-- Camera Control Section --
function KeyCamera:SetCanZoom(canZoom: boolean)
    local settings = self.activeCameraController:GetSettings()
    settings.CanZoom = canZoom
    self.activeCameraController:UpdateSettings(settings)
end

function KeyCamera:ApplyRecoil(recoil: Vector2)
    self.activeCameraController:ApplyRecoil(recoil)
end

-- RenderStep --
function KeyCamera:Update(dt: number)
    if self.enabled then
        self.activeCameraController:UpdateMouseBehavior()

        local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)

        newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)

        local currentCamera = game.Workspace.CurrentCamera :: Camera
        currentCamera.CFrame = newCameraCFrame
        currentCamera.Focus = newCameraFocus

        self.activeTransparencyController:Update(dt)

        if Inputs.GetInputsEnabled() then
            Inputs.resetInputsForFrameEnd()
        end
        return
    end

end

-- Activation Section --
function KeyCamera:IsEnabled()
    return self.enabled
end

function KeyCamera:Enable()
    if not self.enabled then
        self.enabled = true
        local camera = workspace.CurrentCamera
        self.previousCameraType = camera.CameraType
        camera.CameraType = Enum.CameraType.Scriptable
        self.activeCameraController:Enable()
        self.activeTransparencyController:SetSubject(workspace.CurrentCamera.CameraSubject or Players.LocalPlayer.Character)
    end
end

function KeyCamera:Disable()
    if self.enabled then
        self.enabled = false
        self.activeCameraController:Disable()
        local camera = workspace.CurrentCamera
        camera.CameraType = self.previousCameraType
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
end

-- Destroys the KeyCamera instance and cleans up connections
function KeyCamera:Destroy()
	self:Disable()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	for i = 1, #self.boundActions do
		ContextActionService:UnbindAction(self.boundActions[i])
	end
	self.boundActions = {}
	self.activeCameraController:Destroy()
	self.activeOcclusionModule:Destroy()
end

return KeyCamera
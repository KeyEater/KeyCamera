--!nonstrict
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local CAMERA_INPUT_PRIORITY = Enum.ContextActionPriority.Medium.Value

local ROTATION_SPEED_MOUSE = Vector2.new(1, 0.77)*math.rad(0.5) -- (rad/inputdelta)
local ZOOM_SPEED_MOUSE = 1 -- (scaled studs/wheel click)
local ZOOM_SPEED_KEYS = 0.1 -- (studs/s)

local keyboardState = {
    I = 0,
    O = 0
}

local mouseState = {
    Movement = Vector2.new(),
    Wheel = 0
}


local Inputs = {}

function Inputs.getRotation(): Vector2
    local kMouse = mouseState.Movement
    return kMouse*ROTATION_SPEED_MOUSE
end

function Inputs.getZoomDelta(): number
    local kKeyboard = keyboardState.O - keyboardState.I
	local kMouse = -mouseState.Wheel
   	return kKeyboard*ZOOM_SPEED_KEYS + kMouse*ZOOM_SPEED_MOUSE
end

do
    local function mouseMovement(action, state, input)
        local delta = input.delta
        mouseState.Movement = Vector2.new(delta.X, delta.Y)
        return Enum.ContextActionResult.Pass
    end

    local function mouseWheel(action, state, input)
        mouseState.Wheel = input.Position.Z
        return Enum.ContextActionResult.Pass
    end

    local function keypress(action, state, input)
        keyboardState[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
    end

    local function resetInputDevices()
        for _, device in pairs({keyboardState, mouseState }) do
			for k, v in pairs(device) do
				device[k] *= 0 -- Mult by zero to preserve vector types
			end
		end
    end

    local inputsEnabled = false
    function Inputs.Enable()
        if inputsEnabled then
            return
        end
        inputsEnabled = true

        resetInputDevices()

        ContextActionService:BindActionAtPriority("KeyCameraMouseMovement",mouseMovement,false,CAMERA_INPUT_PRIORITY,Enum.UserInputType.MouseMovement)
        ContextActionService:BindActionAtPriority("KeyCameraMouseWheel",mouseWheel,false,CAMERA_INPUT_PRIORITY,Enum.UserInputType.MouseWheel)
        ContextActionService:BindActionAtPriority("KeyCameraKeypress", keypress, false, CAMERA_INPUT_PRIORITY, Enum.KeyCode.I, Enum.KeyCode.O)
    end

    function Inputs.Disable()
        if not inputsEnabled then
            return
        end
        inputsEnabled = false
        
        resetInputDevices()

        ContextActionService:UnbindAction("KeyCameraMouseMovement")
        ContextActionService:UnbindAction("KeyCameraMouseWheel")
        ContextActionService:UnbindAction("KeyCameraKeypress")
    end

    function Inputs.GetInputsEnabled()
        return inputsEnabled
    end

    function Inputs.resetInputsForFrameEnd()
        mouseState.Movement = Vector2.new()
        mouseState.Wheel = 0
    end

    UserInputService.WindowFocused:Connect(resetInputDevices)
	UserInputService.WindowFocusReleased:Connect(resetInputDevices)
end

return Inputs


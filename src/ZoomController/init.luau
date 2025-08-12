--!nonstrict
local ZOOM_STIFFNESS = 4.5
local ZOOM_DEFAULT = 12.5
--local ZOOM_ACCELERATION = 0.0375

local MIN_FOCUS_DIST = 0.5
--local DIST_OPAQUE = 1

--local DEFAULT_CAMERA_MIN_ZOOM_DISTANCE = 0.5
local DEFAULT_CAMERA_MAX_ZOOM_DISTANCE = 400

local ConstrainedSpring = require(script:WaitForChild("ConstrainedSpring"))

--local cameraMinZoomDistance = DEFAULT_CAMERA_MIN_ZOOM_DISTANCE
local cameraMaxZoomDistance = DEFAULT_CAMERA_MAX_ZOOM_DISTANCE



local zoomSpring = ConstrainedSpring.new(ZOOM_STIFFNESS, ZOOM_DEFAULT, MIN_FOCUS_DIST, cameraMaxZoomDistance)
--local zoomDelta = 0

local ZoomController = {}

function ZoomController.UpdateZoomDistances(minDistance, maxDistance)
	cameraMinZoomDistance = minDistance
	cameraMaxZoomDistance = maxDistance
end

function ZoomController.GetZoomRadius()
	return zoomSpring.x
end

function ZoomController.GetGoal()
	return zoomSpring.goal
end

function ZoomController.SetZoomParameters(targetZoom, newZoomDelta)
	zoomSpring.goal = targetZoom
	zoomDelta = newZoomDelta
end

function ZoomController.Update(dt: number, customZoom: number)
	if customZoom < 0.5 then
		customZoom = 0.5
	end
	zoomSpring:SetMinValue(MIN_FOCUS_DIST)
	zoomSpring:SetMaxValue(math.min(cameraMaxZoomDistance, customZoom))

	return zoomSpring:Step(dt)
end

return ZoomController

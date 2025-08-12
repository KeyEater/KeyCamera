--!nonstrict

-- Constants
local ZOOM_STIFFNESS = 4.5
local ZOOM_DEFAULT = 12.5
local MIN_FOCUS_DIST = 0.5
local DEFAULT_CAMERA_MAX_ZOOM_DISTANCE = 400

-- Spring Module
local ConstrainedSpring = require(script:WaitForChild("ConstrainedSpring"))
-- Variable to hold the maximum zoom distance for the camera
local cameraMaxZoomDistance = DEFAULT_CAMERA_MAX_ZOOM_DISTANCE
-- Spring Object for zoom functionality
local zoomSpring = ConstrainedSpring.new(ZOOM_STIFFNESS, ZOOM_DEFAULT, MIN_FOCUS_DIST, cameraMaxZoomDistance)

-- ZoomController Module
local ZoomController = {}

function ZoomController.GetZoomRadius()
	return zoomSpring.x
end

function ZoomController.GetGoal()
	return zoomSpring.goal
end

function ZoomController.SetZoomGoal(targetZoom)
	zoomSpring.goal = targetZoom
end

-- RenderStep function to update the zoom spring
function ZoomController.Update(dt: number, customZoom: number)
	if customZoom < 0.5 then
		customZoom = 0.5
	end
	zoomSpring:SetMinValue(MIN_FOCUS_DIST)
	zoomSpring:SetMaxValue(math.min(cameraMaxZoomDistance, customZoom))

	return zoomSpring:Step(dt)
end

return ZoomController

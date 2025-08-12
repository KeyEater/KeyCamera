local ConstrainedSpring = {}
ConstrainedSpring.__index = ConstrainedSpring

function ConstrainedSpring.new(freq: number, x: number, minValue: number, maxValue: number)
	x = math.clamp(x, minValue, maxValue)
	return setmetatable({
		freq = freq, -- Undamped frequency (Hz)
		x = x, -- Current position
		v = 0, -- Current velocity
		minValue = minValue, -- Minimum bound
		maxValue = maxValue, -- Maximum bound
		goal = x, -- Goal position
	}, ConstrainedSpring)
end

function ConstrainedSpring:SetMaxValue(maxValue: number)
    self.maxValue = maxValue
end

function ConstrainedSpring:SetMinValue(minValue: number)
    self.minValue = minValue
end

function ConstrainedSpring:Step(dt: number)
	local freq = self.freq :: number * 2 * math.pi -- Convert from Hz to rad/s
	local x: number = self.x
	local v: number = self.v
	local minValue: number = self.minValue
	local maxValue: number = self.maxValue
	local goal: number = self.goal


	local offset = goal - x
	local step = freq * dt
	local decay = math.exp(-step)

	local x1 = goal + (v * dt - offset * (step + 1)) * decay
	local v1 = ((offset * freq - v) * step + v) * decay

	-- Constrain
	if x1 < minValue then
		x1 = minValue
		v1 = 0
	elseif x1 > maxValue then
		x1 = maxValue
		v1 = 0
	end

	self.x = x1
	self.v = v1

	return x1
end

return ConstrainedSpring

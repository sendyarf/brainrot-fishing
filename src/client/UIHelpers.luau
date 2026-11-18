-- UIHelpers: the shared look of Brainrot Fishing's UI. Dark navy panels with
-- rounded corners, gold accents, bold white text — one style everywhere so the
-- HUD stays neat and readable at 768x480. Also money formatting and toasts.

local Players = game:GetService("Players")

local UIHelpers = {}

UIHelpers.PanelColor = Color3.fromRGB(18, 24, 46)
UIHelpers.PanelTransparency = 0.15
UIHelpers.AccentGold = Color3.fromRGB(255, 210, 60)
UIHelpers.AccentGreen = Color3.fromRGB(120, 255, 140)
UIHelpers.AccentRed = Color3.fromRGB(255, 90, 90)
UIHelpers.TextWhite = Color3.fromRGB(255, 255, 255)
UIHelpers.TextDim = Color3.fromRGB(200, 210, 230)
UIHelpers.Font = Enum.Font.GothamBold

-- Formats 1234567 as "$1,234,567".
function UIHelpers.FormatMoney(amount)
	local n = math.floor(amount or 0)
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. s:sub(-3) .. out
		s = s:sub(1, -4)
	end
	return "$" .. s .. out
end

-- A rounded, slightly transparent panel frame.
function UIHelpers.NewPanel(parent, name, size, position, anchorPoint)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	if anchorPoint then
		frame.AnchorPoint = anchorPoint
	end
	frame.BackgroundColor3 = UIHelpers.PanelColor
	frame.BackgroundTransparency = UIHelpers.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 210, 60)
	stroke.Transparency = 0.7
	stroke.Thickness = 1.5
	stroke.Parent = frame
	return frame
end

-- A bold text label (transparent background).
function UIHelpers.NewLabel(parent, name, text, size, position, textSize, textColor, anchorPoint)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = position
	if anchorPoint then
		label.AnchorPoint = anchorPoint
	end
	label.BackgroundTransparency = 1
	label.TextColor3 = textColor or UIHelpers.TextWhite
	label.TextSize = textSize or 18
	label.Font = UIHelpers.Font
	label.TextStrokeTransparency = 0.6
	label.Parent = parent
	return label
end

-- A rounded button with bold text.
function UIHelpers.NewButton(parent, name, text, size, position, bgColor, textSize, anchorPoint)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Size = size
	button.Position = position
	if anchorPoint then
		button.AnchorPoint = anchorPoint
	end
	button.BackgroundColor3 = bgColor or Color3.fromRGB(50, 90, 200)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = textSize or 18
	button.Font = UIHelpers.Font
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- A small toast message at the top-center of the screen (shared by all panels).
local toastLabel = nil
local toastConnection = nil
function UIHelpers.ShowToast(text, color, duration)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("BrainrotFishingGui")
	if not gui then
		return
	end
	if not toastLabel then
		toastLabel = Instance.new("TextLabel")
		toastLabel.Name = "Toast"
		toastLabel.AnchorPoint = Vector2.new(0.5, 0)
		toastLabel.Position = UDim2.new(0.5, 0, 0.14, 0)
		toastLabel.Size = UDim2.new(0, 520, 0, 40)
		toastLabel.BackgroundColor3 = Color3.fromRGB(18, 24, 46)
		toastLabel.BackgroundTransparency = 0.15
		toastLabel.TextColor3 = UIHelpers.TextWhite
		toastLabel.TextSize = 18
		toastLabel.Font = UIHelpers.Font
		toastLabel.TextStrokeTransparency = 0.5
		toastLabel.Visible = false
		toastLabel.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = toastLabel
	end
	if toastConnection then
		toastConnection:Disconnect()
		toastConnection = nil
	end
	toastLabel.Text = text
	toastLabel.TextColor3 = color or UIHelpers.TextWhite
	toastLabel.Visible = true
	local shownAt = os.clock()
	toastConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if os.clock() - shownAt > (duration or 3) then
			toastLabel.Visible = false
			if toastConnection then
				toastConnection:Disconnect()
				toastConnection = nil
			end
		end
	end)
end

return UIHelpers

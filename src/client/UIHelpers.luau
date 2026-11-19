-- UIHelpers — small shared builders for the client UI: rounded frames,
-- bold labels and buttons with a consistent look (dark panels, warm
-- sunset accent, thick readable text). Every client module builds its
-- panels through these so the HUD stays coherent.

local UIHelpers = {}

UIHelpers.ACCENT = Color3.fromRGB(255, 170, 60)
UIHelpers.PANEL = Color3.fromRGB(25, 30, 45)
UIHelpers.PANEL_TRANSPARENCY = 0.15
UIHelpers.TEXT = Color3.fromRGB(255, 255, 255)
UIHelpers.MUTED = Color3.fromRGB(180, 190, 210)
UIHelpers.GREEN = Color3.fromRGB(120, 255, 140)
UIHelpers.RED = Color3.fromRGB(255, 90, 90)

function UIHelpers.MakeFrame(parent, size, position, color, transparency)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color or UIHelpers.PANEL
	frame.BackgroundTransparency = transparency == nil and UIHelpers.PANEL_TRANSPARENCY or transparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	return frame
end

function UIHelpers.MakeLabel(parent, size, position, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamBold
	label.TextSize = textSize or 18
	label.TextColor3 = color or UIHelpers.TEXT
	label.Text = text
	label.TextWrapped = true
	label.Parent = parent
	return label
end

function UIHelpers.MakeButton(parent, size, position, text, textSize)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = UIHelpers.ACCENT
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = textSize or 18
	button.TextColor3 = Color3.fromRGB(40, 25, 5)
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

-- Formats a dollar amount with commas: 1234567 -> $1,234,567.
function UIHelpers.FormatCash(amount)
	local rounded = math.floor(amount + 0.5)
	local text = tostring(rounded)
	local formatted = ""
	while #text > 3 do
		formatted = "," .. string.sub(text, -3) .. formatted
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. formatted
end

return UIHelpers

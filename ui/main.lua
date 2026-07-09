local CoreGui = game:GetService("CoreGui")
local UserInput = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera

local Interface = import("rbxassetid://11389137937")

if oh.Cache["ui/main"] then
	return Interface
end

import("ui/controls/TabSelector")
local MessageBox, MessageType = import("ui/controls/MessageBox")

local RemoteSpy
local ClosureSpy
local ScriptScanner
local ModuleScanner
local UpvalueScanner
local ConstantScanner

xpcall(function()
	RemoteSpy = import("ui/modules/RemoteSpy")
	ClosureSpy = import("ui/modules/ClosureSpy")
	ScriptScanner = import("ui/modules/ScriptScanner")
	ModuleScanner = import("ui/modules/ModuleScanner")
	UpvalueScanner = import("ui/modules/UpvalueScanner")
	ConstantScanner = import("ui/modules/ConstantScanner")
end, function(err)
	local message
	if err:find("valid member") then
		message = "The UI has updated, please rejoin and restart. If you get this message more than once, screenshot this message and report it in the Hydroxide server.\n\n" .. err
	else
		message = "Report this error in Hydroxide's server:\n\n" .. err
	end

	MessageBox.Show("An error has occurred", message, MessageType.OK, function()
		Interface:Destroy() 
	end)
end)

local Open = Interface.Open
local Base = Interface.Base
local Drag = Base.Drag
local Status = Base.Status
local Collapse = Drag.Collapse

local BASE_WIDTH = 650
local BASE_HEIGHT = 350
local MIN_SCALE = 0.38
local MAX_SCALE = 1

local isTouch = UserInput.TouchEnabled
local isMobile = isTouch and not UserInput.MouseEnabled

local UIScale = Instance.new("UIScale")
UIScale.Name = "MobileScale"
UIScale.Scale = 1
UIScale.Parent = Base

local currentScale = 1
local constants

local function buildConstants(scale)
	local halfWidth = (BASE_WIDTH * scale) / 2
	local halfHeight = (BASE_HEIGHT * scale) / 2

	return {
		opened = UDim2.new(0.5, -halfWidth, 0.5, -halfHeight),
		closed = UDim2.new(0.5, -halfWidth, 0, -(BASE_HEIGHT * scale) - 50),
		reveal = UDim2.new(0.5, -15, 0, 20),
		conceal = UDim2.new(0.5, -15, 0, -75)
	}
end

local function clampToViewport()
	local viewport = Camera.ViewportSize
	local halfHeight = (BASE_HEIGHT * currentScale) / 2

	local pos = Base.Position
	local targetX = math.clamp(pos.X.Offset, -viewport.X * 0.5 + 20, viewport.X * 0.5 - 20)
	local targetY = math.clamp(pos.Y.Offset, -halfHeight, viewport.Y - halfHeight * 0.6)

	Base.Position = UDim2.new(pos.X.Scale, targetX, pos.Y.Scale, targetY)
end

local function applyScale(scale, tween)
	currentScale = math.clamp(scale, MIN_SCALE, MAX_SCALE)

	if tween then
		game:GetService("TweenService"):Create(UIScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {Scale = currentScale}):Play()
	else
		UIScale.Scale = currentScale
	end

	constants = buildConstants(currentScale)
end

local function computeInitialScale()
	if not isMobile then
		return 1
	end

	local viewport = Camera.ViewportSize
	local shortSide = math.min(viewport.X, viewport.Y)

	return math.clamp((shortSide * 0.94) / BASE_WIDTH, MIN_SCALE, MAX_SCALE)
end

applyScale(computeInitialScale(), false)

function oh.setStatus(text)
	Status.Text = '• Status: ' .. text
end

function oh.getStatus()
	return Status.Text:gsub('• Status: ', '')
end

local dragging
local dragStart
local startPos

local function isDragInput(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

Drag.InputBegan:Connect(function(input)
	if isDragInput(input) then
		local dragEnded 

		dragging = true
		dragStart = input.Position
		startPos = Base.Position

		dragEnded = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
				dragging = false
				clampToViewport()
				dragEnded:Disconnect()
			end
		end)
	end
end)

oh.Events.Drag = UserInput.InputChanged:Connect(function(input)
	if dragging and isDragInput(input) then
		local delta = input.Position - dragStart
		Base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

if isTouch then
	local pinchStartScale

	oh.Events.Pinch = UserInput.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
		if state == Enum.UserInputState.Begin then
			pinchStartScale = currentScale
		elseif state == Enum.UserInputState.Change and pinchStartScale then
			applyScale(pinchStartScale * scale, false)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			pinchStartScale = nil
			clampToViewport()
		end
	end)
end

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	if isMobile then
		applyScale(computeInitialScale(), true)
	end
	clampToViewport()
end)

Open.MouseButton1Click:Connect(function()
	Open:TweenPosition(constants.conceal, "Out", "Quad", 0.15)
	Base:TweenPosition(constants.opened, "Out", "Quad", 0.15)
end)

local closePressStart

Collapse.MouseButton1Down:Connect(function()
	closePressStart = tick()
end)

Collapse.MouseButton1Click:Connect(function()
	local held = closePressStart and (tick() - closePressStart) or 0

	if held >= 0.6 then
		Interface:Destroy()
		return
	end

	Base:TweenPosition(constants.closed, "Out", "Quad", 0.15)
	Open:TweenPosition(constants.reveal, "Out", "Quad", 0.15)
end)

Interface.Name = HttpService:GenerateGUID(false)
if getHui then
	Interface.Parent = getHui()
else
	if syn then
		syn.protect_gui(Interface)
	end

	Interface.Parent = CoreGui
end

Base.Position = constants.opened

return Interface

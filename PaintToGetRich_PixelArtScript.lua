--[[
	Paint to Get Rich - Pixel Art Drawing Script
	Compatible with Paint to Get Rich game mechanics
	Supports pixel-based drawing with grid snapping
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

-- Configuration
local CONFIG = {
	GRID_SIZE = 10, -- Pixel size in studs
	DEFAULT_COLOR = Color3.fromRGB(0, 0, 0), -- Black
	DRAW_LAYER = 0,
	MAX_CANVAS_SIZE = 100, -- Maximum canvas dimensions
}

-- State Management
local DrawingState = {
	isDrawing = false,
	currentColor = CONFIG.DEFAULT_COLOR,
	drawnPixels = {}, -- Table to store drawn pixels
	undoStack = {}, -- For undo functionality
	canvasSize = 50, -- Default canvas size
}

-- Function to create a pixel at world position
local function createPixel(position, color)
	local pixel = Instance.new("Part")
	pixel.Shape = Enum.PartType.Block
	pixel.Size = Vector3.new(CONFIG.GRID_SIZE, CONFIG.GRID_SIZE, CONFIG.GRID_SIZE)
	pixel.CanCollide = false
	pixel.CFrame = CFrame.new(position)
	pixel.Color = color
	pixel.TopSurface = Enum.SurfaceType.Smooth
	pixel.BottomSurface = Enum.SurfaceType.Smooth
	pixel.Parent = workspace
	
	return pixel
end

-- Function to snap mouse position to grid
local function snapToGrid(position)
	local gridSize = CONFIG.GRID_SIZE
	return Vector3.new(
		math.floor(position.X / gridSize + 0.5) * gridSize,
		math.floor(position.Y / gridSize + 0.5) * gridSize,
		math.floor(position.Z / gridSize + 0.5) * gridSize
	)
end

-- Function to draw a pixel
local function drawPixel(worldPos)
	local snappedPos = snapToGrid(worldPos)
	local pixelKey = tostring(snappedPos)
	
	-- Check if pixel already exists
	if DrawingState.drawnPixels[pixelKey] then
		DrawingState.drawnPixels[pixelKey]:Destroy()
	end
	
	-- Store undo action
	table.insert(DrawingState.undoStack, {
		type = "draw",
		position = snappedPos,
		color = DrawingState.currentColor,
		pixelKey = pixelKey
	})
	
	-- Create new pixel
	local pixel = createPixel(snappedPos, DrawingState.currentColor)
	DrawingState.drawnPixels[pixelKey] = pixel
end

-- Function to clear all pixels
local function clearCanvas()
	table.insert(DrawingState.undoStack, {
		type = "clear",
		pixels = DrawingState.drawnPixels
	})
	
	for _, pixel in pairs(DrawingState.drawnPixels) do
		pixel:Destroy()
	end
	DrawingState.drawnPixels = {}
end

-- Function to undo last action
local function undo()
	if #DrawingState.undoStack == 0 then return end
	
	local lastAction = table.remove(DrawingState.undoStack)
	
	if lastAction.type == "draw" then
		if DrawingState.drawnPixels[lastAction.pixelKey] then
			DrawingState.drawnPixels[lastAction.pixelKey]:Destroy()
			DrawingState.drawnPixels[lastAction.pixelKey] = nil
		end
	elseif lastAction.type == "clear" then
		for pos, pixel in pairs(lastAction.pixels) do
			if pixel and pixel.Parent then
				DrawingState.drawnPixels[pos] = pixel
			end
		end
	end
end

-- Function to change color
local function setColor(r, g, b)
	DrawingState.currentColor = Color3.fromRGB(r, g, b)
	print("Color changed to RGB(" .. r .. ", " .. g .. ", " .. b .. ")")
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Left mouse button - Draw
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		DrawingState.isDrawing = true
	end
	
	-- Right mouse button - Erase
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local targetPixel = mouse.Target
		if targetPixel and DrawingState.drawnPixels[tostring(targetPixel.Position)] then
			targetPixel:Destroy()
			DrawingState.drawnPixels[tostring(targetPixel.Position)] = nil
		end
	end
	
	-- Z key - Undo
	if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		undo()
	end
	
	-- C key - Clear canvas
	if input.KeyCode == Enum.KeyCode.C and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		clearCanvas()
	end
	
	-- Number keys for quick color selection
	if input.KeyCode == Enum.KeyCode.One then
		setColor(0, 0, 0) -- Black
	elseif input.KeyCode == Enum.KeyCode.Two then
		setColor(255, 255, 255) -- White
	elseif input.KeyCode == Enum.KeyCode.Three then
		setColor(255, 0, 0) -- Red
	elseif input.KeyCode == Enum.KeyCode.Four then
		setColor(0, 255, 0) -- Green
	elseif input.KeyCode == Enum.KeyCode.Five then
		setColor(0, 0, 255) -- Blue
	elseif input.KeyCode == Enum.KeyCode.Six then
		setColor(255, 255, 0) -- Yellow
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		DrawingState.isDrawing = false
	end
end)

-- Continuous drawing while mouse button is held
RunService.RenderStepped:Connect(function()
	if DrawingState.isDrawing and mouse.Target then
		local hitPosition = mouse.Hit.Position
		drawPixel(hitPosition)
	end
end)

-- Print controls
print("=== Paint to Get Rich - Pixel Art Script ===")
print("LEFT CLICK: Draw pixels")
print("RIGHT CLICK: Erase pixels")
print("1-6 KEYS: Quick color select (Black, White, Red, Green, Blue, Yellow)")
print("CTRL+Z: Undo last action")
print("CTRL+C: Clear canvas")
print("Grid Size:", CONFIG.GRID_SIZE, "studs")
print("===========================================")

-- API for external color selection (for UI integration)
_G.PaintScript = {
	setColor = setColor,
	clearCanvas = clearCanvas,
	undo = undo,
	getDrawnPixels = function() return DrawingState.drawnPixels end,
	setGridSize = function(size) CONFIG.GRID_SIZE = size end,
}

print("Script loaded! Use _G.PaintScript for external control.")

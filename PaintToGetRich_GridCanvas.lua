--[[
	Paint to Get Rich - Advanced Grid-Based Pixel Art Script
	Features:
	- Grid-based canvas system
	- Freehand pixel snapping
	- Paint to Get Rich game compatibility
	- Color palette system
	- Undo/Redo functionality
	- Canvas persistence
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- ===== CONFIGURATION =====
local CANVAS_CONFIG = {
	WIDTH = 64, -- Canvas width in pixels
	HEIGHT = 64, -- Canvas height in pixels
	PIXEL_SIZE = 0.5, -- Visual size of each pixel
	CANVAS_POSITION = Vector3.new(0, 5, 0), -- World position of canvas
	LAYER_HEIGHT = 0.01, -- Height between layers to avoid z-fighting
}

local COLOR_PALETTE = {
	-- Quick color select palette
	[Enum.KeyCode.One] = Color3.fromRGB(0, 0, 0), -- Black
	[Enum.KeyCode.Two] = Color3.fromRGB(255, 255, 255), -- White
	[Enum.KeyCode.Three] = Color3.fromRGB(255, 0, 0), -- Red
	[Enum.KeyCode.Four] = Color3.fromRGB(0, 255, 0), -- Green
	[Enum.KeyCode.Five] = Color3.fromRGB(0, 0, 255), -- Blue
	[Enum.KeyCode.Six] = Color3.fromRGB(255, 255, 0), -- Yellow
	[Enum.KeyCode.Seven] = Color3.fromRGB(255, 0, 255), -- Magenta
	[Enum.KeyCode.Eight] = Color3.fromRGB(0, 255, 255), -- Cyan
	[Enum.KeyCode.Nine] = Color3.fromRGB(255, 165, 0), -- Orange
}

-- ===== CANVAS STATE =====
local Canvas = {
	grid = {}, -- 2D grid storing color data
	pixels = {}, -- Visual pixel parts
	currentColor = Color3.fromRGB(0, 0, 0),
	isDrawing = false,
	lastPixelPos = nil,
	undoStack = {},
	redoStack = {},
	canvasFolder = nil,
}

-- ===== INITIALIZATION =====
local function initializeCanvas()
	-- Create folder to organize canvas
	if Canvas.canvasFolder then
		Canvas.canvasFolder:Destroy()
	end
	
	Canvas.canvasFolder = Instance.new("Folder")
	Canvas.canvasFolder.Name = "PaintCanvas"
	Canvas.canvasFolder.Parent = workspace
	
	-- Initialize 2D grid
	for x = 1, CANVAS_CONFIG.WIDTH do
		Canvas.grid[x] = {}
		for y = 1, CANVAS_CONFIG.HEIGHT do
			Canvas.grid[x][y] = nil -- nil = transparent
		end
	end
	
	Canvas.pixels = {}
	print("Canvas initialized: " .. CANVAS_CONFIG.WIDTH .. "x" .. CANVAS_CONFIG.HEIGHT)
end

-- ===== PIXEL MANAGEMENT =====
local function gridToWorldPos(gridX, gridY)
	local canvasStartX = CANVAS_CONFIG.CANVAS_POSITION.X - (CANVAS_CONFIG.WIDTH * CANVAS_CONFIG.PIXEL_SIZE / 2)
	local canvasStartY = CANVAS_CONFIG.CANVAS_POSITION.Y + (CANVAS_CONFIG.HEIGHT * CANVAS_CONFIG.PIXEL_SIZE / 2)
	
	return Vector3.new(
		canvasStartX + (gridX - 0.5) * CANVAS_CONFIG.PIXEL_SIZE,
		canvasStartY - (gridY - 0.5) * CANVAS_CONFIG.PIXEL_SIZE,
		CANVAS_CONFIG.CANVAS_POSITION.Z
	)
end

local function worldToGridPos(worldPos)
	local canvasStartX = CANVAS_CONFIG.CANVAS_POSITION.X - (CANVAS_CONFIG.WIDTH * CANVAS_CONFIG.PIXEL_SIZE / 2)
	local canvasStartY = CANVAS_CONFIG.CANVAS_POSITION.Y + (CANVAS_CONFIG.HEIGHT * CANVAS_CONFIG.PIXEL_SIZE / 2)
	
	local gridX = math.floor((worldPos.X - canvasStartX) / CANVAS_CONFIG.PIXEL_SIZE + 1)
	local gridY = math.floor((canvasStartY - worldPos.Y) / CANVAS_CONFIG.PIXEL_SIZE + 1)
	
	-- Clamp to canvas bounds
	gridX = math.clamp(gridX, 1, CANVAS_CONFIG.WIDTH)
	gridY = math.clamp(gridY, 1, CANVAS_CONFIG.HEIGHT)
	
	return gridX, gridY
end

local function createPixelPart(gridX, gridY, color)
	local worldPos = gridToWorldPos(gridX, gridY)
	
	local pixel = Instance.new("Part")
	pixel.Shape = Enum.PartType.Block
	pixel.Size = Vector3.new(CANVAS_CONFIG.PIXEL_SIZE, CANVAS_CONFIG.PIXEL_SIZE, 0.1)
	pixel.Color = color
	pixel.CanCollide = false
	pixel.CFrame = CFrame.new(worldPos)
	pixel.TopSurface = Enum.SurfaceType.Smooth
	pixel.BottomSurface = Enum.SurfaceType.Smooth
	pixel.Material = Enum.Material.Flat
	pixel.Name = "Pixel_" .. gridX .. "_" .. gridY
	pixel.Parent = Canvas.canvasFolder
	
	return pixel
end

local function setPixel(gridX, gridY, color)
	-- Bounds check
	if gridX < 1 or gridX > CANVAS_CONFIG.WIDTH or gridY < 1 or gridY > CANVAS_CONFIG.HEIGHT then
		return
	end
	
	local pixelKey = gridX .. "_" .. gridY
	
	-- Remove old pixel if exists
	if Canvas.pixels[pixelKey] then
		Canvas.pixels[pixelKey]:Destroy()
	end
	
	if color then
		Canvas.grid[gridX][gridY] = color
		Canvas.pixels[pixelKey] = createPixelPart(gridX, gridY, color)
	else
		Canvas.grid[gridX][gridY] = nil
		Canvas.pixels[pixelKey] = nil
	end
end

-- ===== DRAWING FUNCTIONS =====
local function drawPixel(gridX, gridY, color)
	-- Add to undo stack
	local oldColor = Canvas.grid[gridX][gridY]
	table.insert(Canvas.undoStack, {
		type = "pixel",
		x = gridX,
		y = gridY,
		oldColor = oldColor,
		newColor = color
	})
	Canvas.redoStack = {} -- Clear redo on new action
	
	setPixel(gridX, gridY, color)
end

local function drawLine(gridX1, gridY1, gridX2, gridY2, color)
	-- Bresenham's line algorithm for pixel-perfect lines
	local dx = math.abs(gridX2 - gridX1)
	local dy = math.abs(gridY2 - gridY1)
	local sx = gridX1 < gridX2 and 1 or -1
	local sy = gridY1 < gridY2 and 1 or -1
	local err = dx - dy
	
	local x, y = gridX1, gridY1
	
	while true do
		drawPixel(x, y, color)
		
		if x == gridX2 and y == gridY2 then break end
		
		local e2 = 2 * err
		if e2 > -dy then
			err = err - dy
			x = x + sx
		end
		if e2 < dx then
			err = err + dx
			y = y + sy
		end
	end
end

-- ===== UNDO/REDO =====
local function undo()
	if #Canvas.undoStack == 0 then return end
	
	local action = table.remove(Canvas.undoStack)
	table.insert(Canvas.redoStack, action)
	
	if action.type == "pixel" then
		setPixel(action.x, action.y, action.oldColor)
	elseif action.type == "clear" then
		for gridX, row in pairs(action.pixels) do
			for gridY, color in pairs(row) do
				if color then
					setPixel(gridX, gridY, color)
				end
			end
		end
	end
end

local function redo()
	if #Canvas.redoStack == 0 then return end
	
	local action = table.remove(Canvas.redoStack)
	table.insert(Canvas.undoStack, action)
	
	if action.type == "pixel" then
		setPixel(action.x, action.y, action.newColor)
	elseif action.type == "clear" then
		for gridX = 1, CANVAS_CONFIG.WIDTH do
			for gridY = 1, CANVAS_CONFIG.HEIGHT do
				setPixel(gridX, gridY, nil)
			end
		end
	end
end

local function clearCanvas()
	-- Store for undo
	local pixelsCopy = {}
	for x = 1, CANVAS_CONFIG.WIDTH do
		pixelsCopy[x] = {}
		for y = 1, CANVAS_CONFIG.HEIGHT do
			pixelsCopy[x][y] = Canvas.grid[x][y]
		end
	end
	
	table.insert(Canvas.undoStack, {
		type = "clear",
		pixels = pixelsCopy
	})
	Canvas.redoStack = {}
	
	-- Clear all pixels
	for x = 1, CANVAS_CONFIG.WIDTH do
		for y = 1, CANVAS_CONFIG.HEIGHT do
			setPixel(x, y, nil)
		end
	end
	
	print("Canvas cleared!")
end

-- ===== COLOR FUNCTIONS =====
local function setColor(color)
	Canvas.currentColor = color
	print("Color changed to:", color)
end

-- ===== INPUT HANDLING =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Left click - Draw
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Canvas.isDrawing = true
		Canvas.lastPixelPos = nil
	end
	
	-- Right click - Erase
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local hit = mouse.Target
		if hit and hit.Parent == Canvas.canvasFolder then
			local gridX, gridY = worldToGridPos(hit.Position)
			drawPixel(gridX, gridY, nil)
		end
	end
	
	-- Color palette shortcuts
	if COLOR_PALETTE[input.KeyCode] then
		setColor(COLOR_PALETTE[input.KeyCode])
	end
	
	-- Ctrl+Z - Undo
	if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		undo()
	end
	
	-- Ctrl+Y - Redo
	if input.KeyCode == Enum.KeyCode.Y and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		redo()
	end
	
	-- Ctrl+Shift+C - Clear canvas
	if input.KeyCode == Enum.KeyCode.C and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		clearCanvas()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Canvas.isDrawing = false
		Canvas.lastPixelPos = nil
	end
end)

-- ===== CONTINUOUS DRAWING =====
RunService.RenderStepped:Connect(function()
	if Canvas.isDrawing then
		local hit = mouse.Target
		
		-- Check if mouse is over canvas
		if hit and hit.Parent == Canvas.canvasFolder or (hit == nil and mouse.Hit.Position.Y > CANVAS_CONFIG.CANVAS_POSITION.Y - 10) then
			local worldPos = mouse.Hit.Position
			local gridX, gridY = worldToGridPos(worldPos)
			
			-- Draw line from last position for smooth strokes
			if Canvas.lastPixelPos then
				local lastX, lastY = Canvas.lastPixelPos.x, Canvas.lastPixelPos.y
				if lastX ~= gridX or lastY ~= gridY then
					drawLine(lastX, lastY, gridX, gridY, Canvas.currentColor)
				end
			else
				drawPixel(gridX, gridY, Canvas.currentColor)
			end
			
			Canvas.lastPixelPos = {x = gridX, y = gridY}
		end
	end
end)

-- ===== INITIALIZATION & GLOBAL API =====
initializeCanvas()

-- Global API for external control
_G.PaintCanvas = {
	setColor = setColor,
	drawPixel = drawPixel,
	drawLine = drawLine,
	clearCanvas = clearCanvas,
	undo = undo,
	redo = redo,
	getGrid = function() return Canvas.grid end,
	setGridSize = function(w, h) 
		CANVAS_CONFIG.WIDTH = w 
		CANVAS_CONFIG.HEIGHT = h 
		initializeCanvas()
	end,
	setPixelSize = function(size)
		CANVAS_CONFIG.PIXEL_SIZE = size
		initializeCanvas()
	end,
}

-- Print help
print("========== Paint to Get Rich - Grid Canvas ==========")
print("LEFT CLICK: Draw")
print("RIGHT CLICK: Erase")
print("KEYS 1-9: Quick color select (Black, White, Red, Green, Blue, Yellow, Magenta, Cyan, Orange)")
print("CTRL+Z: Undo")
print("CTRL+Y: Redo")
print("CTRL+SHIFT+C: Clear canvas")
print("Canvas Size:", CANVAS_CONFIG.WIDTH .. "x" .. CANVAS_CONFIG.HEIGHT)
print("Pixel Size:", CANVAS_CONFIG.PIXEL_SIZE)
print("Access via: _G.PaintCanvas")
print("======================================================")

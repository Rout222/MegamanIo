memory.usememorydomain("PRG ROM")


zzz = 50
-- WAYPOINTS
waypoints = {{10,11}}
lastwp = 1


-- BLOCK TYPES


WALL = 0x40
LADDER = 0x80	-- also water and right conveyor belts
FATAL = 0xC0 -- also ice and left conveyor belts

-- OTHER INFO
TILE_SIZE = 16
NUM_ROWS = 15
NUM_COLS = 16
MACRO_COLS = 8
MACRO_ROWS = 8
TSA_COLS_PER_MACRO = 2
TSA_ROWS_PER_MACRO = 2
NUM_SPRITES = 32
SCREEN_WIDTH = 256
MINI_TILE_SIZE = 3
PLAYING = 178

-- RAM ADDRESSES
SCROLL_X = 0x001F
SCROLL_Y = 0x0022
CURRENT_STAGE = 0x002A -- STAGE SELECT = 1,2,3... clockwise starting at bubble man
GAME_STATE = 0x01FE
MEGAMAN_ID = 0x0400
MEGAMAN_ID2 = 0x0420
CURRENT_SCREEN = 0x0440
MEGAMAN_X = 0x0460
MEGAMAN_Y = 0x04A0

-- ROM ADDRESSES
TSA_PROPERTIES_START = 0x10
TSA_PROPERTIES_SIZE = 0x500
MAP_START = 0x510
MAP_SIZE = 0x4000


--Adicionado por Guilherme
MAP_ARRAY = {}
-- require "libs"


function getBlockAt(stage, screen, x, y)
	local stage_start = stage * MAP_SIZE + MAP_START
	local screen_start = stage_start + MACRO_COLS * MACRO_ROWS * screen
	local address = screen_start + x * MACRO_ROWS + y
	return rom.readbyte(address)
end

function getTSAArrayFromBlock(stage, block)
	local stage_start = stage * MAP_SIZE + TSA_PROPERTIES_START
	local address = stage_start + block * TSA_COLS_PER_MACRO * TSA_ROWS_PER_MACRO
	return {rom.readbyte(address), rom.readbyte(address + 1), rom.readbyte(address + 2), rom.readbyte(address + 3)} 
end

function getTSAFromBlock(stage, block, x, y)
	local TSAArray = getTSAArrayFromBlock(stage, block)
	return TSAArray[x * TSA_ROWS_PER_MACRO + y + 1]
end

function getTSAAt(stage, screen, x, y)
	local block_x = math.floor(x / TSA_COLS_PER_MACRO)
	local block_y = math.floor(y / TSA_ROWS_PER_MACRO)
	local block = getBlockAt(stage, screen, block_x, block_y)
	local TSA = getTSAFromBlock(stage, block, x % TSA_COLS_PER_MACRO, y % TSA_ROWS_PER_MACRO)
	return TSA
end

function isWall(TSA)
	return AND(TSA, 0xC0) == WALL
end

function isFatal(TSA)
	return AND(TSA, 0xC0) == FATAL
end

function isLadder(TSA)
	return AND(TSA, 0xC0) == LADDER
end

function isFree(TSA)
	return AND(TSA, 0xC0) == 0
end

function getScreenMap(stage, screen)
	local map = {}
	local i, j, x, y, TSA
	for i = 1,NUM_ROWS do
		map[i] = {}
		for j = 1,NUM_COLS do
			TSA = getTSAAt(stage, screen, j-1, i-1)
			map[i][j] = TSA
		end
	end
	return map
end

function getMap(stage, screen)
	local map1 = getScreenMap(stage, screen - 1)
	local map2 = getScreenMap(stage, screen)
	local map3 = getScreenMap(stage, screen + 1)
	local mmx = memory.readbyte(MEGAMAN_X)
	local scrollx = memory.readbyte(SCROLL_X)
	local mmtilex = math.floor(mmx / TILE_SIZE)
	local size1 = NUM_COLS/2 - mmtilex
	if scrollx == 0 then
		return map2
	end
	local map = {}
	for i = 1,NUM_ROWS do
		map[i] = {}
		if size1 > 0 then
			for j = 1,size1 do
				map[i][j] = map1[i][(NUM_COLS - size1) + j]
			end
			for j = 1,NUM_COLS-size1 do
				map[i][size1+j] = map2[i][j]
			end
		else
			for j = 1,NUM_COLS+size1 do
				map[i][j] = map2[i][j-size1]
			end
			for j = 1,-size1 do
				map[i][NUM_COLS + size1 + j] = map3[i][j]
			end
		end
		
	end
	return map
end

function minimap()
	if memory.readbyte(GAME_STATE) ~= PLAYING then
		return
	end
	local current_stage = memory.readbyte(CURRENT_STAGE)
	local current_screen = memory.readbyte(CURRENT_SCREEN)
	local map = getMap(current_stage, current_screen)
	local map_left = SCREEN_WIDTH - NUM_COLS * MINI_TILE_SIZE - 2 * MINI_TILE_SIZE
	local map_top = MINI_TILE_SIZE * 2
	local color
	local i, j
	for i = 1,NUM_ROWS do
		MAP_ARRAY[i] = {}
		for j = 1,NUM_COLS do
			color = "#000000CC"
			MAP_ARRAY[i][j] = "9"
			if isWall(map[i][j]) then
				MAP_ARRAY[i][j] = "1"
				color = "#0000FFCC"
			end
			if isFatal(map[i][j]) then
				MAP_ARRAY[i][j] = "2"
				color = "#FF0000CC"
			end
			if isLadder(map[i][j]) then
				MAP_ARRAY[i][j] = "3"
				color = "#00FF00CC"
			end
			
			gui.drawbox(map_left + j * MINI_TILE_SIZE, map_top + i * MINI_TILE_SIZE, map_left + j * MINI_TILE_SIZE + MINI_TILE_SIZE,  map_top + i * MINI_TILE_SIZE + MINI_TILE_SIZE, color, color)
		end
	end
	local sx, sy
	local scroll_x = memory.readbyte(SCROLL_X)	
	for i = 0,NUM_SPRITES-1 do
		if memory.readbyte(MEGAMAN_ID2+i)>=0x80 then
			color = string.format("#%x%x%x", i*7, i*7, i*7)
			sx = memory.readbyte(MEGAMAN_X + i)
			sx = math.ceil(AND(sx+255-scroll_x,255) / TILE_SIZE)
			sy = math.ceil((memory.readbyte(MEGAMAN_Y + i)) / TILE_SIZE)
			if sx <= 15 and sx > 0 then
				if sy <= 16 and sy > 0 then	
					MAP_ARRAY[sy][sx] = i
				end
			end
			gui.drawbox(map_left + sx * MINI_TILE_SIZE, map_top + sy * MINI_TILE_SIZE, map_left + sx * MINI_TILE_SIZE + MINI_TILE_SIZE,  map_top + sy * MINI_TILE_SIZE + MINI_TILE_SIZE, color, "clear")			
		end
	end
	px = memory.readbyte(MEGAMAN_X) + (memory.readbyte(CURRENT_SCREEN) * 255)
	py = memory.readbyte(MEGAMAN_Y)
	
	if(zzz == 0) then
			distMonsters(1,1)
		zzz = 50
	end
	zzz = zzz - 1
end

function heuristic(x, y)
	return ((distMegaman(x, y)/distTarget(x, y))-distMonsters(x, y))
end

function distMegaman(x, y)
	return math.sqrt(math.pow(px - x,2) + math.pow(py-y,2))
end

function distTarget(x, y)
	return math.sqrt(math.pow(waypoints[lastwp][1] - (x + (memory.readbyte(CURRENT_SCREEN) * 255)),2) + math.pow(waypoints[lastwp][2] - y,2))
end

function distMonsters(x, y)
	print(memory.readbyte(0x049F) .. " | " ..memory.readbyte(0x04BF) .. " | " ..memory.readbyte(0x04A0) .. " | " ..memory.readbyte(0x04A2) )
	-- for i = 1,NUM_ROWS do
	-- 		print(MAP_ARRAY[i])
	-- 		if MAP_ARRAY[x][y] == 9 then
	-- 		end
	-- end
	-- 	print('\n')
end

while true do
	minimap()
end

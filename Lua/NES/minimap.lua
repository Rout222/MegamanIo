zzz = 50

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

MAP_ARRAY = {}

function getScreenMap(stage, screen)
	local map = {}
	local i, j, x, y
	for i = 1,NUM_ROWS do
		map[i] = {}
		for j = 1,NUM_COLS do
			map[i][j] = 1
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
			gui.drawBox(
				map_left + j * MINI_TILE_SIZE, 
				map_top + i * MINI_TILE_SIZE, 
				map_left + j * MINI_TILE_SIZE + MINI_TILE_SIZE,  
				map_top + i * MINI_TILE_SIZE + MINI_TILE_SIZE, 
            	0xFFFF00FF, -- ARGB
            	0xFFFF00FF -- ARGB
        	)
		end
	end
	local sx, sy
	local scroll_x = memory.readbyte(SCROLL_X)	
	for i = 0,NUM_SPRITES-1 do
		if memory.readbyte(MEGAMAN_ID2+i)>=0x80 then
			color = 0xFFFFFFFF
			sx = memory.readbyte(MEGAMAN_X + i)
			sx = math.ceil(bit.band(sx+255-scroll_x,255) / TILE_SIZE)
			sy = math.ceil((memory.readbyte(MEGAMAN_Y + i)) / TILE_SIZE)
			if sx <= 15 and sx > 0 then
				if sy <= 16 and sy > 0 then	
					MAP_ARRAY[sy][sx] = i
				end
			end
			gui.drawBox(map_left + sx * MINI_TILE_SIZE, map_top + sy * MINI_TILE_SIZE, map_left + sx * MINI_TILE_SIZE + MINI_TILE_SIZE,  map_top + sy * MINI_TILE_SIZE + MINI_TILE_SIZE, color, color)			
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
	-- print(memory.readbyte(0x049F) .. " | " ..memory.readbyte(0x04BF) .. " | " ..memory.readbyte(0x04A0) .. " | " ..memory.readbyte(0x04A2) )
	-- for i = 1,NUM_ROWS do
	-- 		print(MAP_ARRAY[i])
	-- 		if MAP_ARRAY[x][y] == 9 then
	-- 		end
	-- end
	-- 	print('\n')
end

while true do
	if(memory.read_u8(GAME_STATE) == PLAYING) then
		minimap()
	end
	emu.frameadvance()
end
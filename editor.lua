--i figured i should start using local functions despite 1.6 using like none
local meta_data, trackgenerationid

local firstframe = true
local oldtilex, oldtiley --tilex, tiley
local fastscrolllock, backgroundmode, overlapmode, uniquemode
local brushes, brushnames, brush, brushidx, brushdown, brushstarted --brushlayer, brushtile
local palettewaiting, paletteopen, palettetilex, palettetiley, palettedimx, palettedimy, palettelifetime
local label, labeltimer

local editorcontrols = {
	scrollleft = {"left", "a"},
	scrollright = {"right", "d"},
	scrollup = {"up", "w"},
	scrolldown = {"down", "s"},
	fastscroll = {"lshift", "rshift"},
	fastscrolllock = {"lctrl+lshift", "rctrl+rshift"},

	backgroundmode = {"tab"},
	overlapmode = {"`"},
	uniquemode = {"e"},

	toolscycle = {"c"},
	toolspen = {"t"},
	toolsline = {"g"},
	toolsrect = {"r"},
	toolsfill = {"f"},

	savelevel = {"lctrl+s","rctrl+s"},

	quicktest = {"\\"}
}

--[[
	TODO
	- Remake tile palette (kinda jank and annoying to use)
]]

function editor_getinput(name, key)
	local inputs = editorcontrols[name]
	for i, input in pairs(inputs) do
		local split = input:split("+")
		if #split == 2 then
			if key == split[2] and love.keyboard.isDown(split[1]) then
				return true
			end
		elseif #split == 1 then
			if (key and key == input) or ((not key) and love.keyboard.isDown(input)) then
				return true
			end
		end
	end
	return false
end

function editor_load(player_position) --{x, y, xscroll, yscroll}
	--BLOCKTOGGLE STUFF
	solidblockperma = {false, false, false, false}
	collectables = {} --[marioworld-mariolevel-mariosublevel][x-y]
	collectableslist = {{},{},{},{},{},{},{},{},{},{}}
	collectablescount = {0,0,0,0,0,0,0,0,0,0}
	animationnumbers = {}

	--sublevels in level
	subleveltest = false
	sublevelstable = {}
	if not (mappacklevels[marioworld]) then
		print("PANIC, levels not found!")
		for k = 0, defaultsublevels do
			table.insert(sublevelstable, k)
		end
	else
		if (not mappacklevels[marioworld][mariolevel]) then
			print("PANIC, sublevels not found!")
			mappacklevels[marioworld][mariolevel] = defaultsublevels
		end
		for k = 0, mappacklevels[marioworld][mariolevel] do
			table.insert(sublevelstable, k)
		end
	end

	if player_position then
		--test from position
		objects["player"][1].x = player_position[1]
		objects["player"][1].y = player_position[2]
		camerasnap(player_position[3], player_position[4])
	end

	objects["player"][1].controlsenabled = false
	objects["player"][1].static = true
	objects["player"][1].portalgun = false

	trackgenerationid = 0
	trackpreviews = false

	fastscrolllock = false
	backgroundmode = false
	overlapmode = false
	uniquemode = false

	brushes = require("editorbrushes")
	brushnames = {"pen","line","rect","fill"}
	brush = "pen"
	brushidx = 1
	brushtile = {2, "tile"}
	brushlayer = 1
	brushdown = false
	brushstarted = false

	palettewaiting = false
	paletteopen = false
	palettelifetime = false

	label = ""
	labeltimer = 0
end

function editor_update(dt)
	-- initilise variables
	local x, y = love.mouse.getPosition()
	oldtilex, oldtiley = tilex, tiley
	tilex, tiley = getMouseTile(x, y+8*scale)
	brushlayer = 1
	if brushtile[2] == "entity" then
		brushlayer = 2
	elseif backgroundmode then
		brushlayer = "back"
	end

	-- tools
	editor_tool("update", dt)
	if brushdown and (oldtilex ~= tilex or oldtiley ~= tiley) then
		editor_tool("moved")
	end

	-- move camera
	editor_playermovement(dt)

	-- timers
	if label then
		labeltimer = labeltimer - dt
		if labeltimer <= 0 then label = false end
	end
	if palettelifetime then
		palettelifetime = palettelifetime - dt
		if palettelifetime <= 0 then
			palettelifetime = false
			paletteopen = false
		end
	end

	firstframe = false
end

function editor_draw()
	if firstframe then return end

	love.graphics.setColor(255, 255, 255, 100)
	if paletteopen then
		if paletteopen == "full" then
			-- full palette menu (triggered by holding m and moving mouse)
			local offx, offy = tilex-palettetilex, tiley-palettetiley
			for x = 1, 5 do
				for y = 1, 5 do
					local id = math.min(math.max(1, brushtile[1] + offx+(x-3) + ((offy+(y-3))*22)), 120)
					local dimx, dimy = palettedimx+offx+(x-3), palettedimy+offy+(y-3)
					if dimx > 0 and dimx <= 22 and dimy > 0 and dimy <= 5 then
						editor_drawtile({id, brushtile[2]}, palettetilex+(x-3), palettetiley+(y-3))
					end
				end
			end
			local dimx, dimy = palettedimx+offx, palettedimy+offy
			if dimx > 0 and dimx <= 22 and dimy > 0 and dimy <= 5 then
				love.graphics.rectangle("line", math.floor((palettetilex-xscroll-1)*16*scale), ((palettetiley-yscroll-1)*16-8)*scale, 16*scale, 16*scale)
			end
		elseif paletteopen == "semi" then
			-- simple palette menu (triggered by just scrolling mouse)
			for y = 1, 5 do
				local id = brushtile[1]+(y-3)
				if id > 0 and id <= 120 then
					editor_drawtile({id, brushtile[2]}, tilex, tiley+(y-3))
				end
			end
		end
	else
		editor_tool("preview")	
	end

	-- print label
	if label then
		love.graphics.setColor(255, 255, 255, labeltimer*510)
		properprintbackground(label, 8*scale, 8*scale)
	end

	-- print modes
	local txt = ""
	local txth = 0
	if fastscrolllock then
		txt = txt .. "fast scroll lock\n"
		txth = txth + 1
	end
	if uniquemode then
		txt = txt .. "unique mode\n"
		txth = txth + 1
	end	
	if backgroundmode then
		txt = txt .. "backround mode\n"
		txth = txth + 1
	end
	if overlapmode then
		txt = txt .. "overlap mode\n"
		txth = txth + 1
	end
	if txt ~= "" then
		love.graphics.setColor(255, 255, 255)
		properprintbackground(txt, 8*scale, ((height*16)-8-(10*txth))*scale)
	end
end

function editor_mousepressed(x, y, button)
	if (not inmap(tilex, tiley)) or firstframe then
		return
	end
	-- reset palette lifetime on keypress
	if palettelifetime then
		palettelifetime = false
		paletteopen = false
	end

	if button == "l" then
		brushdown = true
		brushstarted = map[tilex][tiley][brushlayer]
		editor_tool("start")
		return
	end
	if button == "r" then
		editor_moveplayer()
		return
	end

	-- tile palettes
	if button == "m" then
		palettewaiting = true
	end
	if button == "wu" then
		brushtile[1] = math.max(1, brushtile[1]-1)
		paletteopen = "semi"
		palettelifetime = .5
	end
	if button == "wd" then
		brushtile[1] = math.min(brushtile[1]+1, 120)
		paletteopen = "semi"
		palettelifetime = .5
	end
end

function editor_mousereleased(x, y, button)
	if button == "l" and brushdown then
		brushdown = false
		editor_tool("stop")
		return
	end
	if button == "m" then
		palettewaiting = false
		if paletteopen == "full" then
			-- select tile from palette
			local offx, offy = tilex-palettetilex, tiley-palettetiley
			local id = math.min(math.max(1, brushtile[1] + offx + (offy*22)), 120)
			local dimx, dimy = palettedimx+offx, palettedimy+offy
			if dimx > 0 and dimx <= 22 and dimy > 0 and dimy <= 5 then
				brushtile[1] = id
			end
			paletteopen = false
		else
			-- pick tile from map
			if brushlayer ~= 1 and (map[tilex][tiley][brushlayer] == nil or map[tilex][tiley][brushlayer] == 1) then
				brushtile = {map[tilex][tiley][1], brushtile[2]}
			else	
				brushtile = {map[tilex][tiley][brushlayer], brushtile[2]}
			end
		end
	end
end

function editor_mousemoved(x, y, dx, dy)
	-- opens full palette
	if palettewaiting then
		palettewaiting = false
		paletteopen = "full"
		palettetilex, palettetiley = tilex, tiley
		palettedimx, palettedimy = ((brushtile[1]-1)%22)+1, math.floor((brushtile[1]-1)/22)+1
	end
end

function editor_keypressed(key, textinput)
	-- toggles
	if editor_getinput("fastscrolllock", key) then
		fastscrolllock = not fastscrolllock
	end
	if editor_getinput("backgroundmode", key) then
		backgroundmode = not backgroundmode
		overlapmode = false
	end
	if editor_getinput("overlapmode", key) then
		overlapmode = not overlapmode
		backgroundmode = false
	end
	if editor_getinput("uniquemode", key) then
		uniquemode = not uniquemode
	end

	-- tools
	editor_tool("keypress", key)
	if editor_getinput("toolspen", key) then -- switch tools
		editor_switchtool("pen")
	elseif editor_getinput("toolsline", key) then
		editor_switchtool("line")
	elseif editor_getinput("toolsrect", key) then
		editor_switchtool("rect")
	elseif editor_getinput("toolsfill", key) then
		editor_switchtool("fill")
	elseif editor_getinput("toolscycle", key) then
		brushidx = (brushidx%4)+1
		editor_switchtool(brushnames[brushidx])
	end

	-- misc
	if editor_getinput("savelevel", key) then
		savelevel()
	end
	if editor_getinput("quicktest", key) then -- quicktest
		test_level(objects["player"][1].x, objects["player"][1].y)
	end
end

--

-- call this when placing tiles, handles all the modes.
function editor_placetile(brush, layer, x, y)
	if not x then
		x, y = tilex, tiley
	end
	if not inmap(x, y) then
		return
	end

	local id, mode = unpack(brush)
	if id == map[x][y][layer] then
		return
	end
	if layer == "back" and id == 1 then
		id = nil
	end

	if overlapmode and layer == 1 and map[x][y][1] ~= 1 and id ~= 1 then
		map[x][y]["back"] = map[x][y][1]
		bmap_on = true
	end
	if uniquemode then
		if id == 1 then
			if map[x][y][layer] ~= brushstarted then
				return
			end
		else
			if (layer == "back" or layer == 1) and map[x][y][1] ~= 1 then
				return
			end
			if layer == 2 and map[x][y][2] ~= 1 then
				return
			end
		end
	end

	if mode == "tile" then
		if layer == 1 then
			objects["tile"][tilemap(x, y)] = nil
			if tilequads[id].collision then
				objects["tile"][tilemap(x, y)] = tile:new(x-1, y-1, 1, 1, true)
			end
		else
			bmap_on = true
		end
		map[x][y][layer] = id
		updatespritebatch()
	elseif mode == "entity" then
		map[x][y][layer] = id
	end
end
function editor_placetiles(brush, layer, positions)
    for i, v in pairs(positions) do
        editor_placetile(brush, layer, v.x, v.y)
    end
end

-- call this when drawinf tiles, because why the f##k not
function editor_drawtile(brush, x, y)
	if not x then
		x, y = tilex, tiley
	end

	local id, mode = unpack(brush)
	if mode == "tile" then
		love.graphics.draw(tilequads[id].image,   tilequads[id].quad,   math.floor((x-xscroll-1)*16*scale), ((y-yscroll-1)*16-8)*scale, 0, scale, scale)
	elseif mode == "entity" and id ~= nil then
		love.graphics.draw(entityquads[id].image, entityquads[id].quad, math.floor((x-xscroll-1)*16*scale), ((y-yscroll-1)*16-8)*scale, 0, scale, scale)
	end
end
function editor_drawtiles(brush, positions)
    for i, v in pairs(positions) do
        editor_drawtile(brush, v.x, v.y)
    end
end

function editor_playermovement(dt)
	local speed -- calculate speed
	if fastscrolllock then
		speed = 50 * dt
		if editor_getinput("fastscroll") then
			speed = 20 * dt
		end
	else
		speed = 20 * dt
		if editor_getinput("fastscroll") then
			speed = 50 * dt
		end
	end

	if editor_getinput("scrollleft") then -- left/right
		splitxscroll[1] = math.max(0, splitxscroll[1]-speed)
		autoscroll = false
		generatespritebatch()
	elseif editor_getinput("scrollright") then
		splitxscroll[1] = math.min(splitxscroll[1]+speed, mapwidth-width)
		autoscroll = false
		generatespritebatch()
	end
	if editor_getinput("scrollup") then --up/down
		splityscroll[1] = math.max(0, splityscroll[1]-speed)
		autoscroll = false
		generatespritebatch()
	elseif editor_getinput("scrolldown") then
		splityscroll[1] = math.min(splityscroll[1]+speed, mapheight-height-1)
		autoscroll = false
		generatespritebatch()
	end
end

function editor_moveplayer()
	if (not objects["player"][1]) then
		return
	end
	local p = objects["player"][1]
	p.x = tilex-1+2/16
	p.y = tiley-p.height
	if p.animation == "vinestart" then
		p.animation = false
		p.controlsenabled = true
		p.active = true
	end
end

function editor_switchtool(tool)
	brush = tool
	label = brush .. " tool"
	labeltimer = 1
end

function editor_tool(func, arg)
	if not brushes[brush][func] then
		return
	end
	if arg then
		brushes[brush][func](brushes[brush], arg)
	else
		brushes[brush][func](brushes[brush])
	end
end

--

function test_level(x, y)
	local targetxscroll, targetyscroll = xscroll, yscroll
	if levelmodified and onlysaveiflevelmodified then
		savelevel()
	end
	editormode = false
	testlevel = true
	testlevelworld = marioworld
	testlevellevel = mariolevel
	autoscroll = true
	checkpointx = false
	subleveltest = true

	updateplayerproperties("reset")
	updatesizes("reset")
	player_position = {x, y, xscroll, yscroll}
	if mariosublevel ~= 0 then
		startlevel(mariosublevel)
	else
		startlevel(marioworld .. "-" .. mariolevel)
	end
	player_position = nil

	if x and y then
		-- test from position
		local p = objects["player"][1]
		p.x = x
		p.y = y
		p.invincible = true
		p.animationtimer = 2.4
		p.animation = "invincible"
		p.controlsenabled = true
		p.active = true
		camerasnap(targetxscroll, targetyscroll)
		generatespritebatch()
	end
end

-- not just editor stuff

function savesettings()
	local s = ""
	s = s .. "name=" .. guielements["edittitle"].value .. "\n"
	s = s .. "author=" .. guielements["editauthor"].value .. "\n"
	s = s .. "description=" .. guielements["editdescription"].value .. "\n"
	if mariolivecount == false then
		s = s .. "lives=0\n"
	else
		s = s .. "lives=" .. mariolivecount .. "\n"
	end
	if currentphysics and currentphysics ~= 1 then
		s = s .. "physics=" .. currentphysics .. "\n"
	end
	if camerasetting and camerasetting ~= 1 then
		s = s .. "camera=" .. camerasetting .. "\n"
	end
	if dropshadow then
		s = s .. "dropshadow=t\n"
	end
	if realtime then
		s = s .. "realtime=t\n"
	end
	if continuesublevelmusic then
		s = s .. "continuesublevelmusic=t\n"
	end
	if nolowtime then
		s = s .. "nolowtime=t\n"
	end
	
	love.filesystem.createDirectory( mappackfolder )
	love.filesystem.createDirectory( mappackfolder .. "/" .. mappack )
	
	love.filesystem.write(mappackfolder .. "/" .. mappack .. "/settings.txt", s)
	
	notice.new("Settings saved", notice.white, 3)
end

function reversescrollfactor(s)
	return math.sqrt(s or scrollfactor)/3
end

function reversescrollfactor2(s)
	return math.sqrt(s or scrollfactor2)/3
end

function formatscrollnumber(i)
	if string.len(i) == 1 then
		return i .. ".00"
	elseif string.len(i) == 3 then
		if i < 0 then
			return i
		else
			return i .. "0"
		end
	elseif string.len(i) >= 5 then
		return tostring(i):sub(1,4)
	else
		return i
	end
end

function generatetrackpreviews()
	trackgenerationid = trackgenerationid + 1 --how many times tracks have been generated, used to detect old ones
	for mx = 1, mapwidth do
		for my = 1, mapheight do
			if map[mx][my]["track"] and map[mx][my]["track"].id ~= trackgenerationid then --delete old tracks
				map[mx][my]["track"] = nil
			end
			if map[mx][my][2] and (entityquads[map[mx][my][2]].t == "track" or entityquads[map[mx][my][2]].t == "trackswitch") then
				local v
				local pathvars = 1 --how many track paths does the entity have?
				if entityquads[map[mx][my][2]].t == "trackswitch" then 
					v = convertr(map[mx][my][3], {"string", "string", "bool"}, true)
					pathvars = 2
				else
					v = convertr(map[mx][my][3], {"string", "bool"}, true)
				end
				local trackdata
				for pathvar = 1, pathvars do
					trackdata = v[pathvar]
					if trackdata then
						local s = trackdata:gsub("n", "-")
						local s2 = s:split("`")
						
						local s3
						for i = 1, #s2 do
							s3 = s2[i]:split(":")
							local x, y = tonumber(s3[1]), tonumber(s3[2])
							local start, ending, grab = s3[3], s3[4], s3[5]
							
							if x and y then
								local tx, ty = mx+x, my+y
								if ismaptile(tx,ty) then
									map[tx][ty]["track"] = {start=start, ending=ending, grab=grab, id=trackgenerationid, cox=mx, coy=my}
								else
									break
								end
							else
								break
							end
						end
					end
				end
			end
		end
	end
	trackpreviews = true
end

function loadeditormetadata()
	--save background colors for level buttons
	meta_data = {}
	local files = love.filesystem.getDirectoryItems(mappackfolder .. "/" .. mappack .. "/editor")
	for i = 1, #files do
		local v = mappackfolder .. "/" .. mappack .. "/editor/" .. files[i]
		local extension = string.sub(v, -4, -1)
		if extension == ".png" then
			local name = string.sub(files[i], 1, -5)
			meta_data[name] = {}
			meta_data[name].img = love.graphics.newImage(v)
		end
	end
	--[[
	if not love.filesystem.exists(mappackfolder .. "/" .. mappack .. "/editor.txt") then
		return false
	end
	local s = love.filesystem.read(mappackfolder .. "/" .. mappack .. "/editor.txt")
	local s2 = s:split("|")
	local s3
	for leveldatai = 1, #s2 do
		s3 = s2[leveldatai]:split("~")
		meta_data[s3[1] .. "~" .. s3[2] .. "~" .. s3[3] ] = {s3[4], s3[5], s3[6]}
		print("loading metadata " .. s3[1] .. "~" .. s3[2] .. "~" .. s3[3])
	end]]
end

function saveeditormetadata()
	if not meta_data then
		return false
	end
	love.filesystem.createDirectory(mappackfolder .. "/" .. mappack .. "/editor")
	local w, h = 14, 13
	if mariosublevel == 0 then
		w = 70
		h = 15
	end
	w, h = math.min(mapwidth, w), math.min(mapheight, h)
	local imgdata = love.image.newImageData(w, h)
	for x = 1, w do
		for y = 1, h do
			local id = map[x][mapheight-h+y][1]
			if rgblist[id] and id ~= 0 and not tilequads[id].invisible  then
				local r, g, b, a = rgblist[id]
				imgdata:setPixel(x-1, y-1, r, g, b)
			else
				local r, g, b, a = love.graphics.getBackgroundColor()
				imgdata:setPixel(x-1, y-1, r, g, b)
			end
		end
	end
	local levelstring = marioworld .. "~" .. mariolevel .. "~" .. mariosublevel
	imgdata:encode("png", mappackfolder .. "/" .. mappack .. "/editor/" .. levelstring .. ".png")
	if not meta_data[levelstring] then
		meta_data[levelstring] = {}
	end
	meta_data[levelstring].img = love.graphics.newImage(imgdata)
	--[[meta_data[marioworld .. "~" .. mariolevel .. "~" .. mariosublevel] = backgroundcolor[background]
	print("saving metadata " .. marioworld .. "~" .. mariolevel .. "~" .. mariosublevel)
	local s = ""
	for i, t in pairs(meta_data) do
		s = s .. i .. "~" .. t[1] .. "~" .. t[2] .. "~" .. t[3] .. "|"
	end
	s = s:sub(1, -2)
	local success, message = love.filesystem.write(mappackfolder .. "/" .. mappack .. "/editor.txt", s)]]
end

function promptsaveeditormetadata()
	--save if doesn't exist
	local levelstring = marioworld .. "~" .. mariolevel .. "~" .. mariosublevel
	if not meta_data[levelstring] then
		saveeditormetadata()
		promptedmetadatasave = false
		return false
	end
	--save meta data only when switching levels
	promptedmetadatasave = true
end
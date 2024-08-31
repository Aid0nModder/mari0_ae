function fkeypressed(key)
    if key == "f8" then
        f_reloadall()
        notice.new("[ reloaded ]",notice.white)
    elseif key == "f9" then
        f_declutter()
    elseif key == "f10" then
		if android then
			androidHIDE = not androidHIDE
		else
			HITBOXDEBUG = not HITBOXDEBUG
            local text = HITBOXDEBUG and "shown" or "hidden"
            notice.new("[ hitboxes "..text.." ]",notice.white)
		end
	elseif key == "f11" then
		showfps = not showfps
        local text = showfps and "shown" or "hidden"
        notice.new("[ fps "..text.." ]",notice.white)
	elseif key == "f12" then
		love.mouse.setGrabbed(not love.mouse.isGrabbed())
        local text = love.mouse.isGrabbed() and "on" or "off"
        notice.new("[ mouse lock "..text.." ]",notice.white)
	end
end

function f_reloadall()
    -- sprites --
    loadcustomsprites()

    -- default tiles --
    for i = 1, #smbspritebatch do
        smbspritebatch[i]:setTexture(smbtilesimg)
        portalspritebatch[i]:setTexture(portaltilesimg)
    end

    -- custom tiles --
    if love.filesystem.exists(mappackfolder .. "/" .. mappack .. "/tiles.png") then
        --remove custom sprites
        for i = smbtilecount+portaltilecount+1, #tilequads do
            tilequads[i] = nil
        end
        for i = smbtilecount+portaltilecount+1, #rgblist do
            rgblist[i] = nil
        end

        --add custom tiles
        customtiles = true
        loadtiles("custom")
        customspritebatch = {}
        for i = 1, 2 do
            customspritebatch[i] = {}
            for i2 = 1, #customtilesimg do
                customspritebatch[i][i2] = love.graphics.newSpriteBatch( customtilesimg[i2], maxtilespritebatchsprites )
            end
        end
    else
        customtiles = false
        customtilecount = 0
    end
    
    if love.filesystem.exists(mappackfolder .. "/" .. mappack .. "/animated/1.png") then
        loadanimatedtiles()
    end
    
    -- back/foreground --
    loadcustombackgrounds() -- for menu
    loadcustomforeground(customforeground)
    loadcustombackground(custombackground)

    -- other, simple stuff --
    loadcustomtext()
    loadcustomsounds()
    loadcustommusic()
    enemies_load()
    animationsystem_load()

    collectgarbage()
    generatespritebatch()
end

-- Original code by WilliamFrog
local function getmaxprops(x, y, layer)
    if tilequads[map[x][y][layer]].quadlist then
        local outtable = {}
        for i, v in pairs(tilequads[map[x][y][layer]].properties) do
            for j, g in pairs(v) do
                if g and not outtable[j] then
                    outtable[j] = g
                end
            end
        end
        return outtable
    else
        return tilequads[map[x][y][layer]]
    end
end

local function transtable(x, y, layer)
	local v = tilequads[map[x][y][layer]].imagedata

	local outtable = {}
	local quadtable = {}
	if tilequads[map[x][y][layer]].quadlist then
		quadtable = tilequads[map[x][y][layer]].quadlist
	else
		quadtable = {tilequads[map[x][y][layer]].quad}
	end
	for i, g in pairs(quadtable) do
		local fx, fy = g:getViewport()
		local count = 1
		for x1 = fx, fx+15 do
			for y1 = fy, fy+15 do
				local r, g, b, a = v:getPixel(x1, y1)
				local transparent = false
				if (a < 255 and layer == 1) or (a == 0 and layer == "back") then
					transparent = true
				end

				if transparent and ((layer == 1 and (outtable[count] == true or outtable[count] == nil)) or (layer == "back" and (outtable[count] == nil))) then
					outtable[count] = false
				elseif transparent == false and ((layer == 1 and (outtable[count] == nil)) or (layer == "back" and (outtable[count] == false or outtable[count] == nil))) then
					outtable[count] = true
				end
				count = count + 1
			end
		end
	end
	return outtable
end

function f_declutter()
	local tilecount = 0
	local enemycount = 0
	local dtilecount = 0
	local otilecount = 0
	for x = 1, mapwidth do
		for y = 1, mapheight do
			if map[x][y][1] == 1 and map[x][y]["back"] then
				local v = getmaxprops(x,y,"back")
				if (not v.invisible) and (not v.collision) and (not v.lava) and (not v.water) and (not v.vine) and (not v.fence) and (not v.coin) and (not v.forground) then
					local newy = math.min(y+1,mapheight)
					local g = getmaxprops(x,newy,1)
					if not ((g.collision and (g.coinblock or g.breakable or g.noteblock)) and map[x][newy][2]) then
						map[x][y][1] = map[x][y]["back"]
						map[x][y]["back"] = nil
						tilecount = tilecount+1
					end
				end
			end
			if map[x][y][2] == 1 then
				map[x][y][2] = nil
				enemycount = enemycount+1
			end
			if map[x][y][1] == map[x][y]["back"] then
				map[x][y]["back"] = nil
				dtilecount = dtilecount+1
			end
			if tilequads[map[x][y][1]].image and map[x][y]["back"] and tilequads[map[x][y]["back"]].image and not (tilequads[map[x][y][1]].invisible or tilequads[map[x][y][1]].coinblock or tilequads[map[x][y][1]].breakable or tilequads[map[x][y][1]].noteblock) then
				local frontable = transtable(x, y, 1)
				local backtable = transtable(x, y, "back")
				local pass = true
				for i=1, 256 do
					if backtable[i] and not frontable[i] then
						pass = false
						break
					end
				end
				if pass then
					map[x][y]["back"] = nil
					otilecount = otilecount + 1
				end
			end
		end
	end
	local text1 = "no tiles to raise"
	local text2 = "no enemies to clear"
	local text3 = "no double tiles"
	local text4 = "no obscured tiles"
	if tilecount > 0 then text1 = "raised "..tilecount.." tiles!" end
	if enemycount > 0 then text2 = "cleared "..enemycount.." enemies!" end
	if dtilecount > 0 then text3 = "cleared "..dtilecount.." double tiles!" end
	if otilecount > 0 then text4 = "cleared "..otilecount.." obscured tiles!" end
	notice.new("[ decluttered tiles ]\n"..text1.."\n"..text2.."\n"..text3.."\n"..text4)
	generatespritebatch()
end
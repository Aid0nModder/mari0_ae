-- Mostly made by chat GPT (I'm a scum)
function getline(x0, y0, x1, y1)
    local dx = math.abs(x1 - x0)
    local dy = math.abs(y1 - y0)
    local sx = x0 < x1 and 1 or -1
    local sy = y0 < y1 and 1 or -1
    local err = dx - dy
    
    local points = {}
    while x0 ~= x1 or y0 ~= y1 do
        table.insert(points, {x=x0, y=y0})
        local err2 = err * 2
        if err2 > -dy then
            err = err - dy
            x0 = x0 + sx
        end
        if err2 < dx then
            err = err + dx
            y0 = y0 + sy
        end
    end
    return points
end
function getfill(tx, ty, l, ontile, onlyonscreen)
	local bot = {} --will navigate map to find ontiles and fill them
	local output = {} --list of tiles that should be changed {x, y}
	table.insert(bot, {tx,ty})
	local lmap = {} --create copy of map that can be modified freely
	for sx = 1, mapwidth do
		lmap[sx] = {}
		for sy = 1, mapheight do
			local ti = map[sx][sy][l]
			lmap[sx][sy] = (ti == ontile) --is it the same as on tile?
		end
	end
	--update bots until they are all gone
	while #bot > 0 do
		local delete = {}
		for i, b in pairs(bot) do
			local x, y = b[1], b[2]
			--make children around
			local nextbots = {{x-1, y},{x+1,y},{x,y-1},{x,y+1}}
			for i2 = 1, 4 do
				local nx, ny = nextbots[i2][1], nextbots[i2][2]
				if inmap(nx,ny) and lmap[nx][ny] and ((not onlyonscreen) or onscreen(nx-1, ny-1, 1, 1)) then
					lmap[nx][ny] = false
					table.insert(bot, {nx,ny})
				end
			end
			--fill if same as ontile
			lmap[x][y] = false
			table.insert(output, {x=x, y=y})
			table.insert(delete, i)
		end
		table.sort(delete, function(a,b) return a>b end)
		for i, v in pairs(delete) do
			table.remove(bot, v) --remove
		end
	end
	return output
end
function getrect(x0, y0, x1, y1)
    local sx, sy = math.min(x0,x1),math.min(y0,y1)
	local ex, ey = math.max(x0,x1),math.max(y0,y1)
    local output = {}
    for x = sx, ex do
        for y = sy, ey do
            table.insert(output, {x=x, y=y})
        end
    end
    return output
end

local editorbrushes = {}

------

editorbrushes.pen = class:new()

function editorbrushes.pen:start()
    editor_placetile(brushtile, brushlayer, tilex, tiley)
end
function editorbrushes.pen:moved()
    editor_placetile(brushtile, brushlayer, tilex, tiley)
end
function editorbrushes.pen:preview()
    editor_drawtile(brushtile, tilex, tiley)
end

------

editorbrushes.line = class:new()
editorbrushes.line.inuse = false

function editorbrushes.line:start()
    self.sx, self.sy = tilex, tiley
    self.inuse = true
end
function editorbrushes.line:stop()
    self:place()
    self.inuse = false
end
function editorbrushes.line:place()
    editor_placetiles(brushtile, brushlayer, self:affected())
end
function editorbrushes.line:preview()
    if self.inuse then
        editor_drawtiles(brushtile, self:affected())
    else
        editor_drawtile(brushtile, tilex, tiley)
    end
end
function editorbrushes.line:affected()
    local positions = getline(self.sx, self.sy, tilex, tiley)
    table.insert(positions, {x=tilex, y=tiley})
    return positions
end

------

editorbrushes.rect = class:new()
editorbrushes.rect.inuse = false

function editorbrushes.rect:start()
    self.sx, self.sy = tilex, tiley
    self.inuse = true
end
function editorbrushes.rect:stop()
    self:place()
    self.inuse = false
end
function editorbrushes.rect:place()
    editor_placetiles(brushtile, brushlayer, self:affected())
end
function editorbrushes.rect:preview()
    if self.inuse then
        editor_drawtiles(brushtile, self:affected())
    else
        editor_drawtile(brushtile, tilex, tiley)
    end
end
function editorbrushes.rect:affected()
    return getrect(self.sx, self.sy, tilex, tiley)
end

------

editorbrushes.fill = class:new()

function editorbrushes.fill:start()
    editor_placetiles(brushtile, brushlayer, self:affected(false))
end
function editorbrushes.fill:preview()
    editor_drawtiles(brushtile, self:affected(true))
end
function editorbrushes.fill:affected(onlyonscreen)
    return getfill(tilex, tiley, brushlayer, map[tilex][tiley][brushlayer], onlyonscreen)
end

return editorbrushes
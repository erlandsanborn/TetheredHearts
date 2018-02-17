-- Server --
-- see: https://github.com/Neopallium/lua-handlers
-- and: https://github.com/aubio/aubio
require("cavity")

local socket = require("socket")
local address, port = home, 31337
local width, height
local entity
local updaterate = 0.5
local unit
local x0, y0
local theta = 2 * math.pi / 3
local dtheta = theta - math.pi/2
local t,dt = 0, 0
local margin = 4
local world = {}
local s,l,a = 255, 180, 255
local scale = .125
local graphLength = 50

--math locals
local sin = math.sin
local cos = math.cos
local pi = math.pi
local abs = math.abs
local playerCount
local canvas
local graphHeight = 50

--debugging tools
local ding = love.timer.getTime()
local dong = love.timer.getTime() - ding

function love.load()
	width = love.graphics.getWidth() - margin
	height = love.graphics.getHeight() - margin

	unit = width/6
	x0, y0 = .5 * (width + margin), .5 * (height + margin)
	graphLength = width / 2 - margin
	graphHeight = .5 * (height - 3 * unit - margin)
	udp = socket.udp()
	udp:settimeout(0)
	udp:setsockname(address, port)

	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setColor(255,255,255)

	scene = love.graphics.newCanvas()
	tracer = love.graphics.newCanvas()
	background = love.graphics.newCanvas()
	players = love.graphics.newCanvas()

	x1, y1 = cos(dtheta), sin(dtheta)
	x2, y2 = cos(theta + dtheta), sin(theta + dtheta)
	x3, y3 = cos(2*theta + dtheta), sin(2*theta + dtheta)

	drawBackground()

end


local ding = love.timer.getTime()
local buffer = love.graphics.newCanvas()

function love.draw()
	t = love.timer.getTime()
	love.graphics.setColor(255,255,255)
	love.graphics.draw(background)
	--~ scene:renderTo(function()
		--~ love.graphics.clear(0,0,0,0)
	--~ end)

	i = 0
	for name,player in pairs(world) do
		--love.graphics.setCanvas()

		local stats = string.format("%s\t%d", name, player.bps * 60 / scale)
		love.graphics.setColor( HSL(player.hue,s,l, 255) )
		love.graphics.print(stats, 10, i * 25 + margin)

		if player.points.last >= 0 then
			local pts = {}
			for j=player.points.first,player.points.last do
				local x,y = (j-player.points.first), graphHeight * player.points[j] / 255
				table.insert(pts, width-graphLength + x)
				table.insert(pts, y)
			end

			if ( table.getn(pts) >= 4 ) then
				love.graphics.setLineWidth(1)
				love.graphics.line(pts)
			end
		end

		--love.graphics.setCanvas(player.avatar)
		--love.graphics.clear(0,0,0,0)
		--love.graphics.draw(player.tracer)
		love.graphics.push()
			love.graphics.translate(x0, y0)
			love.graphics.setLineWidth(4)

			-- compute circle alpha, mapped to rotation offset from circle center
			local dr = 2 * sin((player.rotation + dtheta) * 3) - 1
			local alpha = (255-100)  * dr / playerCount + 100

			love.graphics.setColor(HSL(player.hue, s, l, alpha))
			love.graphics.circle('fill', x1 * unit, y1 * unit, 0.5 * unit)
			love.graphics.circle('fill', x2 * unit, y2 * unit, 0.5 * unit)
			love.graphics.circle('fill', x3 * unit, y3 * unit, 0.5 * unit)

			-- draw triangle
			love.graphics.rotate(player.rotation)
			love.graphics.setColor( HSL(player.hue,s,l,255)) --player.amp / 255 * 55 + 200) )
			love.graphics.polygon('line', x1 * unit, y1 * unit, x2 * unit, y2 * unit, x3 * unit, y3 * unit)
		love.graphics.pop()

		--love.graphics.setCanvas(player.tracer)
		--love.graphics.clear(0,0,0,0)
		love.graphics.draw(player.avatar)

		--love.graphics.setCanvas(scene)
		--love.graphics.setBlendMode("add")
		--love.graphics.draw(player.avatar)

		player.ttl = player.ttl - 1

		if player.ttl == 0 then
			world[name] = nil
		end
		i = i + 1
	end

	--love.graphics.setCanvas()
	--love.graphics.setBlendMode("alpha")
	--~ love.graphics.print(love.timer.getFPS(), margin, height - margin - 25)
	--~ love.graphics.setColor(255,255,255,255)

	--love.graphics.setBlendMode("add")
	--love.graphics.draw(scene)

end

local dong = love.timer.getTime() - ding
print( string.format( "love.draw takes %.3f ms", dong * 1000 ))

local ding = love.timer.getTime()
function love.update(deltatime)

	dt = dt + deltatime

	-- receive from udp until the buffer is empty
	repeat
		data = udp:receive()
		if data then
			playerName, attributes = data:match("(%S*) (.*)")
			color,rate,pulse,rot = attributes:match("^(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*)$")
			if world[playerName] == nil then
				local pts = List:new()
				List.push(pts, tonumber(pulse))
				world[playerName] = {
					name = playerName,
					amp = tonumber(pulse),
					points = pts,
					hue = tonumber(color),
					bps = tonumber(rate),
					rotation = tonumber(rot),
					ttl = 10,
					avatar = love.graphics.newCanvas(),
					tracer = love.graphics.newCanvas()
				}
			else
				world[playerName].bps = tonumber(rate)
				world[playerName].ttl = 10
				world[playerName].amp = tonumber(pulse)
				world[playerName].rotation = tonumber(rot)
				List.push(world[playerName].points, tonumber(pulse))
				if ( world[playerName].points.last >= graphLength ) then
					List.shift(world[playerName].points)
				end

			end

		end
	until not data
	playerCount = 0
	for _ in pairs(world) do playerCount = playerCount + 1 end
end
local dong = love.timer.getTime() - ding
print( string.format( "love.update takes %.3f ms", dong * 1000 ))

List = {}
function List.new ()
	return {first = 0, last = -1}
end
function List.push(list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end
function List.shift(list)
	local first = list.first
	if first > list.last then error("list is empty") end
	local value = list[first]
	list[first] = nil        -- to allow garbage collection
	list.first = first + 1
	return value
end

function drawBackground()
	love.graphics.setCanvas(background)
		love.graphics.clear(0,0,0,0)
		love.graphics.setColor(255,255,255,255)
		love.graphics.setLineWidth(4)
		love.graphics.circle('line', x0, y0, unit)
		love.graphics.circle('line', x0, y0, 0.5 * unit)
		love.graphics.circle('line', x0, y0, 1.5 * unit)
		love.graphics.push()
			love.graphics.translate(x0, y0)

			love.graphics.setBlendMode('alpha')
			love.graphics.setColor(255,255,255,255)
			love.graphics.circle('line', x1 * unit, y1 * unit, 0.5 * unit)
			love.graphics.circle('line', x2 * unit, y2 * unit, 0.5 * unit)
			love.graphics.circle('line', x3 * unit, y3 * unit, 0.5 * unit)
		love.graphics.pop()

	love.graphics.setCanvas()
end

function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-abs(2*l-1))*s
	local x = (1-abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

function love.keypressed(k)
	--q is for quit this shit
	if k == 'q' then
		love.event.quit()
	end
end

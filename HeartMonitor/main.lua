-- Server --
-- see: https://github.com/Neopallium/lua-handlers
-- and: https://github.com/aubio/aubio

local socket = require("socket")
local address, port = "localhost", 66666
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

local canvas

function love.load()
	width = love.graphics.getWidth() - margin
	height = love.graphics.getHeight() - margin
	unit = width/6
	x0, y0 = .5 * (width + margin), .5 * (height + margin)

	udp = socket.udp()
	udp:settimeout(0)
	udp:setsockname(address, port)
	
	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setColor(255,255,255)
	
	x1, y1 = math.cos(dtheta), math.sin(dtheta)
	x2, y2 = math.cos(theta + dtheta), math.sin(theta + dtheta)
	x3, y3 = math.cos(2*theta + dtheta), math.sin(2*theta + dtheta)
	drawBackground()
	
end

function love.draw()
	t = love.timer.getTime()
	love.graphics.print(love.timer.getFPS(), margin, height - margin - 25)
	
	local i = 0
	
	for name,player in pairs(world) do
        local stats = string.format("%s\t%d", name, player.bps * 60 / scale)
		love.graphics.setColor(HSL(player.hue, s, l, a))
		love.graphics.print(stats, 10, i * 25 + margin)
		i = i + 1
	end

	local i = 0
	for name,player in pairs(world) do
        local stats = string.format("%s\t%d", name, player.bps * 60 / scale)

		rotation = (2 * t * player.bps * math.pi) % (2 * math.pi)
		love.graphics.setColor(HSL(player.hue, s, l, a))
		love.graphics.setLineWidth(4)
		love.graphics.push()
			love.graphics.translate(x0, y0)
			love.graphics.rotate(rotation)
			love.graphics.polygon('line', x1 * unit, y1 * unit, x2 * unit, y2 * unit, x3 * unit, y3 * unit)
		love.graphics.pop()

		i = i + 1
		player.ttl = player.ttl - 1

		if player.ttl == 0 then
			world[name] = nil
		end

    end

    for name,player in pairs(world) do

		if player.points.last >= 0 then
			local pts = {}
			for j=player.points.first,player.points.last do
				local x,y = 10 * (j-player.points.first), 50 * player.points[j] / 255
				table.insert(pts, width-10*graphLength + x)
				table.insert(pts, y)
			end

			love.graphics.setColor(HSL(player.hue, s, l, a))
			if ( table.getn(pts) >= 4 ) then
				love.graphics.setLineWidth(1)
				love.graphics.line(pts)
			end
		end
	end
	
end


function love.update(deltatime)
	
	dt = dt + deltatime
	-- data, msg_or_ip, port_or_nil = udp:receivefrom()
	
	-- receive from udp until the buffer is empty
	repeat 
		data = udp:receive()
		if data then
			playerName, attributes = data:match("(%S*) (.*)")
			color,rate,pulse = attributes:match("^(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*)$")
			if world[playerName] == nil then
				local pts = List:new()
				List.push(pts, tonumber(pulse))
				world[playerName] = {
					name = playerName,
					amp = tonumber(pulse),
					points = pts,
					hue = tonumber(color),
					bps = tonumber(rate),
					ttl = 10
				}
			else
				world[playerName].bps = tonumber(rate)
				world[playerName].ttl = 10
				world[playerName].amp = tonumber(pulse),
				List.push(world[playerName].points, tonumber(pulse))
				if ( world[playerName].points.last >= graphLength ) then
					List.shift(world[playerName].points)
				end
			end
		end
	until not data
	
end

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
	love.graphics.setLineWidth(5)

	love.graphics.circle('line', x0, y0, unit)
	love.graphics.circle('line', x0, y0, 0.5 * unit)
	love.graphics.circle('line', x0, y0, 1.5 * unit)

	love.graphics.push()
		love.graphics.translate(x0, y0)
		love.graphics.circle('line', x1 * unit, y1 * unit, 0.5 * unit)
		love.graphics.circle('line', x2 * unit, y2 * unit, 0.5 * unit)
		love.graphics.circle('line', x3 * unit, y3 * unit, 0.5 * unit)
	love.graphics.pop()


end

function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

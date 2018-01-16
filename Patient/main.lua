-- Client:
-- Receives heart signal via local socket from python script
-- Calculates BPM from signal stream
-- Renders triangle with rotation rate mapped to BPM
-- Transmits rotation rate, name, color (etc) to server
-- periphery lib for GPIO: https://github.com/vsergeev/lua-periphery
-- 		sudo luarocks install lua-periphery


local GPIO = require('periphery').GPIO
local HEART_PIN = 10

local width, height = 400, 400
local socket = require("socket")
local address, port = "localhost", 66666
local name = "Erland"
local entity
local updaterate = .2

local world = {}
local t, r = 0

local bpm
local scale = .125
local rotationRate

local unit = width/4
local x0, y0 = width/2, height/2
local theta = 2 * math.pi / 3
local dtheta = theta - math.pi/2
local hue
local s,l,a = 255, 180, 255

function love.load()
	math.randomseed(os.time())
	bpm = math.random(60, 120)
	rotationRate = scale * (bpm / 60) / 4

	math.randomseed(os.time())
	hue = math.random(0,255)

	love.graphics.setColor( HSL(hue,s,l,a) )
	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setLineWidth(4)
	dt = 0
	r = 0
	w,h = width, height
	love.window.setMode(width, height)
	ip = getIP()
	initGPIO()
	--findServer()

	--local checkServer = timer.performWithDelay( 10 * 1000, findServer, 0 )

	udp = socket.udp()
	udp:settimeout(0)
	udp:setpeername(address, port)
	udp:setoption('broadcast', true)
	name = string.format("%s_%s", name, love.timer.getTime())

end

function initGPIO()
	local gpio_in = GPIO(HEART_PIN, "in")

	--local value = gpio_in:read()
	--gpio_out:write(not value)

	--gpio_in:close()
	--gpio_out:close()
end

function love.draw()
	love.graphics.print(name, 10,10)
	love.graphics.print(bpm, 10,20)

	-- avatar:draw()
	x1, y1 = math.cos(dtheta), math.sin(dtheta)
	x2, y2 = math.cos(theta + dtheta), math.sin(theta + dtheta)
	x3, y3 = math.cos(2*theta + dtheta), math.sin(2*theta + dtheta)
	love.graphics.push()
		love.graphics.translate(x0, y0)
		love.graphics.rotate(r)
		love.graphics.polygon('line', x1 * unit, y1 * unit, x2 * unit, y2 * unit, x3 * unit, y3 * unit)
	love.graphics.pop()

	--data, msg_or_ip, port_or_nil = udp:receivefrom()
	--if data then
		--print(data)
	--end
end

local amp = 0

function love.update(deltatime)
	dt = dt + deltatime
	t = love.timer.getTime()

	-- amp = gpio_in:read()
	amp = math.random(255)
	bps = scale * bpm / 60
	r = (2 * t * bps * math.pi) % (2 * math.pi)

	if udp and dt > updaterate then
		data = string.format("%s %d,%f,%f", name, hue, bps, amp)
		udp:send(data)
		dt = 0
	end


end

function findServer()

	local newServers = {}
	local msg = "Heart Monitor"
	print("finding server")
	local listen = socket.udp()
	listen:setsockname( "226.192.1.1", port )

	local name = listen:getsockname()
	if ( name ) then  --test to see if device supports multicast
		listen:setoption( "ip-add-membership", { multiaddr="226.192.1.1", interface = ip } )
	else  --the device doesn't support multicast so we'll listen for broadcast
		listen:close()  --first we close the old socket; this is important
		listen = socket.udp()  --make a new socket
		listen:setsockname( ip, port )  --set the socket name to the real IP address
	end

	listen:settimeout( 0 )  --move along if there is nothing to hear

	local counter = 0  --pulse counter

	repeat
		local data, remoteIp, remotePort = listen:receivefrom()
		print("receiving", data, remoteIp, remotePort)

		if data and data == msg then
			if not newServers[ip] then
				print( "I hear a server:", ip, port )
				local params = { ["ip"]=ip, ["port"]=port }
				newServers[ip] = params
				-- connect immediately
				udp = socket.udp()
				udp:settimeout(0)
				udp:setpeername(address, port)
				udp:setoption('broadcast', true)

			end
		end
	until not data
	print("end findserver")
end

function getIP()
    local s = socket.udp()  --creates a UDP object
    s:setpeername( "74.125.115.104", 80 )  --Google website
    local ip, sock = s:getsockname()
    return ip
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

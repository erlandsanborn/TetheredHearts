-- Client:
-- Receives heart signal via local socket from python script
-- Calculates BPM from signal stream
-- Renders triangle with rotation rate mapped to BPM
-- Transmits rotation rate, name, color (etc) to server
-- periphery lib for GPIO: https://github.com/vsergeev/lua-periphery
-- 		sudo luarocks install lua-periphery

require("cavity")

local GPIO = require('periphery').GPIO
local HEART_PIN = 10

local width, height = 400, 400
local socket = require("socket")
local address, port = home, 31337
local name = "Erland"
local entity
local updaterate = .1

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

local sin = math.sin
local cos = math.cos
local pi = math.pi
local abs = math.abs
local random = math.random
local randomseed = math.randomseed

function love.load()
	randomseed(os.time())
	bpm = random(60, 120)
	rotationRate = scale * (bpm / 60) / 4

	randomseed(os.time())
	
	dt = 0
	r = 0
	w,h = width, height
	love.window.setMode(width, height)
	
	hue = random(0,255)
	love.graphics.setColor( HSL(hue,s,l,a) )
	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setLineWidth(4)
	
	ip = getIP()
	initGPIO()
	
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
	love.graphics.print(love.timer.getFPS(), 15, height - 15 - 25)
	
	x1, y1 = cos(dtheta), sin(dtheta)
	x2, y2 = cos(theta + dtheta), sin(theta + dtheta)
	x3, y3 = cos(2*theta + dtheta), sin(2*theta + dtheta)
	love.graphics.push()
		love.graphics.translate(x0, y0)
		love.graphics.rotate(r)
		love.graphics.polygon('line', x1 * unit, y1 * unit, x2 * unit, y2 * unit, x3 * unit, y3 * unit)
	love.graphics.pop()

end

local amp = 0

function love.update(deltatime)
	dt = dt + deltatime
	t = love.timer.getTime()

	-- amp = gpio_in:read()
	amp = random(255)
	bps = scale * bpm / 60
	r = (2 * t * bps * pi) % (2 * pi)

	if udp then --and dt > updaterate then
		data = string.format("%s %d,%f,%f", name, hue, bps, amp)
		udp:send(data)
		dt = 0
	end


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

-- Client:
-- Receives heart signal via local socket from python script
-- Calculates BPM from signal stream
-- Renders triangle with rotation rate mapped to BPM
-- Transmits rotation rate, name, color (etc) to server
-- periphery lib for GPIO: https://github.com/vsergeev/lua-periphery
-- 		sudo luarocks install lua-periphery

require("cavity")
local Draft = require("draft")
local draft = Draft()

local gamestate = "title"
local utf8 = require("utf8")
local Serial = require('periphery').Serial

local serial = Serial("/dev/ttyS0", 115200)

local width, height = 400, 400
local graphLength = 50
local socket = require("socket")
local address, port = home, 31337

local playername = ""
-- local name = playername
local entity
local updaterate = .1
local margin = 4
local tracerAmount = 90
local t, r = 0

local bpm
local scale = .125
local amp = 0
local unit = width/4
local x0, y0
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
local max = math.max
local points
local font = love.graphics.newFont("8bitwonder.TTF", 12)
local avatar = love.graphics.newCanvas()
local tracer = love.graphics.newCanvas()
local rising = false
local threshold = 100
local tapCount = 0;
local msecsFirst = 0;
local msecsPrevious = 0;
local resetDelay = 2

local maxAmp = 0

local inc = 0
--function server:receive(url, ...)
--  print(url, ...)
--end
local colors = {}
table.insert(colors, {r=255,g=0,b=0} )
table.insert(colors, {r=255,g=20,b=147} )

table.insert(colors, {r=106,g=90,b=205} )
table.insert(colors, {r=65,g=105,b=225} )

table.insert(colors, {r=152,g=251,b=152} )
table.insert(colors, {r=0,g=255,b=127} )
local playerColor = colors[1];


splashvid = love.graphics.newVideo("splash.ogv")


function love.load()

	splashvid:play()

        --create startkey text with wait/timer
        blankface = ""
        spaceface = "Touch space to continue"
        startkey = blankface
        kickoff = 0

	gamestate = "title"
	love.graphics.setFont(font)	
	entername = "Who are you"
	playername = ""
	love.keyboard.setKeyRepeat(true)
	
	love.graphics.setCanvas(avatar)
	love.graphics.clear(0,0,0,0)
	love.graphics.setCanvas()
	
	randomseed(os.time())
	bpm = random(60, 80)

	randomseed(os.time())
	inc = random(5, 15)
	dt = 0
	r = 0
	width = love.graphics.getWidth() - margin
	height = love.graphics.getHeight() - margin
	x0,y0 = width/2, height/2

	love.graphics.setFont(font)

	hue = random(0,255)
	colorIndex = random(1,6)
	playerColor = colors[colorIndex]
	
	love.graphics.setColor( playerColor.r, playerColor.g, playerColor.b ) --HSL(hue,s,l,a) )
	love.graphics.setBackgroundColor(0,0,0)
	love.graphics.setLineWidth(4)

	ip = getIP()
	
	updServer = socket.udp()
	updServer:settimeout(0)
	updServer:setsockname(address, 31338)
	
	udp = socket.udp()
	udp:settimeout(0)
	udp:setpeername(address, port)
	udp:setoption('broadcast', true)
	name = string.format("%s-%s", playername, math.floor(love.timer.getTime() % 1000) )

	graphLength = width / 2 - margin
	points = List:new()
	
	--dmt edges
	limitUpper = 18
	limitLower = 6
	numSegments = limitLower
	direction = "up"
	step = bpm / 30000
end

function love.textinput(t)
	if gamestate == "user" then
		if t ~= " " then
			playername = playername .. t
		end
	end
end

local world = {}
function love.keypressed(k)
	if gamestate == "title" then
		if k == "space" then
			  gamestate = "user"
			  
		end
	end
	if gamestate == "user" then
		if k == "backspace" then
			local byteoffset = utf8.offset(playername, -1)

			if byteoffset then
				playername = string.sub(playername, 1, byteoffset - 1)
			end
		end
	end

	--q is for quit this shit (actually no, make that f12)
	if gamestate ~= "user" then
		if k == 'f12' then
			love.event.quit()
		end
	end

end

function love.update(deltatime)

	if gamestate == "title" then
		if love.keyboard.isDown("space") then
			gamestate = "user"
		end
		kickoff = kickoff + deltatime
		if kickoff > 8 then
		  kickoff = 9
		  
		  if startkey == blankface then
			startkey = spaceface
		  else
			blankface = spaceface
		  end
		end
	elseif gamestate == "user" then
		if love.keyboard.isDown("return", "enter") then
			gamestate = "playing"
		end
	else
		-- cycle through colors
		if love.keyboard.isDown("right") then
			colorIndex = colorIndex + 1
			if colorIndex > 6 then
				colorIndex = 1
			end
			playerColor = colors[colorIndex]
	
		end
		
		local buf = serial:read(64, 0)
		if ( buf:len() > 0 ) then
			amp = 255 * (string.byte(buf) / 1024)
		end
		-- adjust threshold slightly under max amp from heart monitor
		maxAmp = max(amp, maxAmp)
		threshold = maxAmp - 20

		bps = scale * bpm / 60
		r = r + bps / 10

		-- detect bpm from ekg peak
		if ( rising == false and amp > threshold ) then
			rising = true
			tap()
		elseif ( rising == true and amp <= threshold ) then
			rising = false
		end

		List.push(points, amp)
		if ( points.last >= graphLength ) then
			List.shift(points)
		end

		if udp then --and dt > updaterate then
			data = string.format("%s %d,%d,%d,%f,%d,%f", playername, playerColor.r, playerColor.g, playerColor.b, bps, amp, r)
			udp:send(data)
			dt = 0
		end
		
		serverdata,serverhost,serverport = updServer:receivefrom()
		if serverdata then
			-- use data from other players here
			patientName, attributes = serverdata:match("(%S*) (.*)")
			red,grn,blu,playerRate,playerAmp,playerRot = attributes:match("^(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*),(%-?[%d.e]*)$")
			if world[patientName] == nil then
				local pts = List:new()
				List.push(pts, tonumber(playerAmp))
				world[patientName] = {
					name = patientName,
					amp = tonumber(playerAmp),
					points = pts,
					r = tonumber(red),
					g = tonumber(grn),
					b = tonumber(blu),
					bps = tonumber(playerRate),
					rotation = tonumber(playerRot),
					ttl = 10,
					avatar = love.graphics.newCanvas(),
					tracer = love.graphics.newCanvas(),
					ip = serverhost
				}
			else
				world[patientName].bps = tonumber(rate)
				world[patientName].ttl = 10
				world[patientName].amp = tonumber(playerAmp)
				world[patientName].rotation = tonumber(playerRot)
				List.push(world[patientName].points, tonumber(playerAmp))
				if ( world[patientName].points.last >= graphLength ) then
					List.shift(world[patientName].points)
				end

			end
		end
	end
	
	
	love.timer.sleep(.01)
end



function love.draw()

	if gamestate == "title" then
		love.graphics.draw(splashvid, 0, 0)
		--need to print a blinking "Touch space to start" 
		love.graphics.printf(startkey, 280, 30, love.graphics.getWidth())
			
	elseif gamestate == "user" then
		
		love.graphics.printf(entername, 100, 100, love.graphics.getWidth())
		love.graphics.printf(playername, 130, 130, love.graphics.getWidth())

	elseif gamestate == "playing" then
		
		love.graphics.print(string.format("%s\t%s bpm", playername, bpm), 10,10)
		--love.graphics.print(bpm, 10,30)
		love.graphics.print(love.timer.getFPS(), 15, height - 15 - 25)
		
		-- render ekg from other patients
		for name,player in pairs(world) do
			local pts = {}
		
			for j=player.points.first,player.points.last do
				local theta = 2 * pi * (j-player.points.first) / graphLength
				
				local x,y = (80 * player.points[j]/255 + unit) * cos(theta), (80 * player.points[j]/255 + unit)*sin(theta)--(j-player.points.first), 50 - 50 * player.points[j] / 255
				
				table.insert(pts, x + x0)
				table.insert(pts, y + y0)
			end
			if ( table.getn(pts) >= 4 ) then
				love.graphics.setColor(player.r, player.g, player.b)
				love.graphics.setLineWidth(1)
				--love.graphics.line(pts)
				local v = draft:line(pts, 'line')
				
			end			
		
			player.ttl = player.ttl - 1
			if player.ttl == 0 then
				world[name] = nil
			end
		end
		
		love.graphics.setLineWidth(4)
		x1, y1 = cos(dtheta), sin(dtheta)
		x2, y2 = cos(theta + dtheta), sin(theta + dtheta)
		x3, y3 = cos(2*theta + dtheta), sin(2*theta + dtheta)
		--love.graphics.setBackgroundColor(10,180,200)
		
			
		-- render avatar with tracer
		love.graphics.setCanvas(avatar)
			--love.graphics.clear(0,0,0,0)
			love.graphics.setBlendMode("replace")
			love.graphics.draw(tracer)
			love.graphics.setBlendMode("alpha")
			love.graphics.setColor( playerColor.r, playerColor.g, playerColor.b)--, amp / 255 * (255-192) + 192) --HSL(hue,s,l, amp / 255 * 127 + 128) )
			love.graphics.push()
				love.graphics.translate(x0, y0)
				love.graphics.rotate(r)
				love.graphics.polygon('line', x1 * unit, y1 * unit, x2 * unit, y2 * unit, x3 * unit, y3 * unit)
				-- draw facemelters here
				--x1 * unit, y1 * unit 
				--x2 * unit, y2 * unit
				--x3 * unit, y3 * unit
			love.graphics.pop()

		-- render tracer image
		love.graphics.setCanvas(tracer)
			--love.graphics.clear(0,0,0,0)
			love.graphics.setColor(0,0,0,10)
			love.graphics.rectangle('fill', 0,0,love.graphics.getWidth(),love.graphics.getHeight())
			
			love.graphics.setColor( playerColor.r, playerColor.g, playerColor.b, tracerAmount)
			love.graphics.draw(avatar)
			
		love.graphics.setCanvas()
		
		love.graphics.draw(avatar)
		
		--love.graphics.setBlendMode("add")
		-- draw ekg graph
		if points.last >= 0 then
			local pts = {}
			for j=points.first,points.last do
				local x,y = (j-points.first), 50 - 50 * points[j] / 255
				table.insert(pts, width-graphLength + x)
				table.insert(pts, y)
			end

			love.graphics.setColor(playerColor.r, playerColor.g, playerColor.b) --HSL(hue, s, l, a))
			if ( table.getn(pts) >= 4 ) then
				love.graphics.setLineWidth(1)
				love.graphics.line(pts)

				love.graphics.line(width-graphLength - 5, 50 - threshold/255 * 50, width, 50 - threshold/255 * 50)
			end
		end

		-- draw fuckerygons
		--draft:rhombus(400, 200, 65, 65)
		-- draw fuckerygons for dmt edges
		
		--love.graphics.setColor(255, 40, 0, 10)

		-- draft:compass(cx, cy, width, arcAngle, startAngle, numSegments, wrap, scale, mode)
		--local v = draft:compass(400, 225, 300, 60, 180, 8, wrap, scale, mode)

		-- draft:egg(cx, cy, width, syBottom, syTop, numSegments, mode)
		-- local v = draft:egg(400, 225, 300, 1, 1, numSegments, 'line')

		-- draft:circle(cx, cy, radius, numSegments, mode)
		--local v1 = draft:circle(400, 225, 300, numSegments, 'line')

		-- draft:arc(cx, cy, radius, arcAngle, startAngle, numSegments, mode)
		--local v2 = draft:arc(400, 225, 360, 30, 60, numSegments, 'line')
		
		-- draft:linkTangleWebs(v1, v2)
	end
end


function tap()
	local msecs = love.timer.getTime() * 1000
	if ((msecs - msecsPrevious) > 1000 * resetDelay) then
		tapCount = 0;
	end

	if (tapCount == 0) then
		msecsFirst = msecs;
		tapCount = 1;
	else
		bpmAvg = 60000 * tapCount / (msecs - msecsFirst);
		bpm = math.floor(bpmAvg) -- * 100) / 100;
		tapCount = tapCount + 1
	end
	msecsPrevious = msecs;
end

function getIP()
    local s = socket.udp()  --creates a UDP object
    s:setpeername( "74.125.115.104", 80 )  --Google website
    local ip, sock = s:getsockname()
    return ip
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

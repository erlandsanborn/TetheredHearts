function love.conf(t)
	t.window.height = 400 --setting this to fit into 800x600 resolution configured on orbpi.local
	t.window.width = 500
	t.window.vsync = true --toggling vsync to test hz vs fps adjustment
end

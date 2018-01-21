<div style="display: block;"><span style="text-align: center;"><img src="https://www.suspension.nyc/assets/img/logo.png"></span></div>

# TetheredHearts
<p>A game you play with your heart... <br/>
...while suspended from hooks.</p>


<h2>Hardware</h2>
<p>RPI 3 (model B)<br/>
Pulsesensor</p>


<h2>Software </h2>

<p>Runs on <a href="https://love2d.org/">LÖVE 2D</a></p>


<h2>RPI Environment & Architecture configs</h2>

<p>Using raspi-config, ensure the following are configured.<br />
<ul>
<li>
<strong>Memory Split</strong><br/>
Advanced Options > Memory Split > Set to minimum 128
</li>

<li>
<strong>Resolution</strong> (optional)<br/>
Advanced Options > Resolution > DMT Mode 16 1024x768 60Hz 4:3
</li>

<li>
<strong>GL Driver</strong> <br/>
Advanced Options > GL Driver > G1 GL (Full KMS)
</li>
</ul>
</p>

<h2>Love2D Requirements & Configs</h2>

<p>lua-periphery required to allow GPIO i/o. Clone from git:<br/>
https://github.com/vsergeev/lua-periphery</p>

<p>Copy cavitytemp.lua to cavity.lua, and replace "localhost" with the hostname the monitor will live on.
Remember to do this for both monitor, and patient.</p>


<h2>Usage</h2>

<p>HeartMonitor acts as server, whereas Patient acts as client. Configure local address in main.lua (for both) to where monitor will be running, to ensure patients are targeting correct monitor location. Receiving bluescreen with udp:send error while running Patient, will indicate it is targeting wrong address.</p>
<p>See requirements above for configuring cavity.lua</p>


<h2>Misc</h2>

<p>Using VNC to get RPI display on local machine. </p>

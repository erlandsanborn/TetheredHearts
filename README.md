# TetheredHearts
A game you play with your heart...
...while suspended from hooks.


# Hardware
RPI 3 (model B)
Pulsesensor


# Software
Runs on <a href="https://love2d.org/">LÖVE 2D</a>


# RPI Environment & Architecture configs
Using raspi-config, ensure the following are configured.

1. Memory Split
Advanced Options > Memory Split > Set to minimum 128

2. Resolution (optional)
Advanced Options > Resolution > DMT Mode 16 1024x768 60Hz 4:3

3. GL Driver 
Advanced Options > GL Driver > G1 GL (Full KMS)


# Love2D Requirements & Configs
lua-periphery required to allow GPIO i/o. Clone from git:
https://github.com/vsergeev/lua-periphery

Copy cavitytemp.lua to cavity.lua, and replace "localhost" with the hostname the monitor will live on.
Remember to do this for both monitor, and patient.


# Usage
HeartMonitor acts as server, whereas Patient acts as client. Configure local address in main.lua (for both) to where monitor will be running, to ensure patients are targeting correct monitor location. Receiving bluescreen with udp:send error while running Patient, will indicate it is targeting wrong address.


# Misc
Using VNC to get RPI display on local machine. 

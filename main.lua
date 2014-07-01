-- Tent by Sam Mauldin (Sxw1212)
-- Copyright (c) 2014 Sam Mauldin (Sxw1212)
-- All rights reserved
-- Config
local cfg = {master = "", monitor = "", modem = "", sg = "", glass = "", sgs = "https://raw.github.com/Sxw1212/Tent/master/sgs.lua"}
if fs.exists("/tentconfig") then
	local fh = fs.open("/tentconfig", "r")
	cfg = textutils.unserialize(fh.readAll())
	fh.close()
else
	local fh = fs.open("/tentconfig", "w")
	fh.write(textutils.serialize(cfg))
	fh.close()
	error("Please edit the config.")
end
-- End config

local SG_BUILD = 3
local SG_CHAN = 15814

local oldPull = os.pullEvent
os.pullEvent = os.pullEventRaw

local updateurl = "https://raw.github.com/Sxw1212/Tent/master/main.lua"

_G["modem"] = peripheral.wrap(cfg.modem)
local glass = peripheral.wrap(cfg.glass)
local sg = peripheral.wrap(cfg.sg)
local monitor = peripheral.wrap(cfg.monitor)
master = cfg.master

assert(glass)
assert(sg)
assert(monitor)
assert(modem)
assert(master)

modem.open(SG_CHAN)

monitor.setTextScale(2.5)
monitor.clear()

glass.clear()

function split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

local function getCenter(text)
	local extraSupport
    if #text >= 18 then
        extraSupport = 5
    else
        gWidth = 24
        extraSupport = 0
    end
    return (((gWidth/2)-(#text/2))*6)+20+extraSupport
end

local function setText(text, object)
	object.setText("")
	object.setX(getCenter(text))
	object.setText(text)
end

local col = {}
col.red = 0xff3333
col.blue = 0x7dd2e4
col.yellow = 0xffff4d
col.green = 0x4dff4d
col.gray = 0xe0e0e0
col.textGray = 0x818181
col.text = 0x5a5a5a
col.rain = 0x2e679f

-- Boxes

local disp = glass.addBox(20, 20, 146, 50, col.gray, 0.8)

local left = glass.addBox(19, 19, 1, 52, col.blue, 0.8)
local right = glass.addBox(166, 19, 1, 52, col.blue, 0.8)

-- Text

local title = glass.addText(23, 25, "", col.textGray)
title.setZ(5)
local status = glass.addText(23, 35, "", col.textGray)
status.setZ(5)
local main = glass.addText(23, 45, "", col.textGray)
main.setZ(5)
local copyright = glass.addText(23, 55, "", col.textGray)
copyright.setZ(5)

setText("Tent", title)
setText("Loading...", status)
setText("", main)
setText("By Sam Mauldin", copyright)

local sgraw = http.get(cfg.sgs)
local sgs = {}

if sgraw then
	sgs = loadstring("return " .. sgraw.readAll())()
end

function toAddr(alias, ret)
	for k,v in pairs(sgs) do
		if k == alias or v[1] == alias then
			return v[2]
		end
	end
	if ret then
		return alias
	end
end

function toShort(addr)
	for k,v in pairs(sgs) do
		if v[2] == addr then
			return k
		end
	end
	return addr
end

function toLong(addr)
	for k,v in pairs(sgs) do
		if v[2] == addr then
			return v[1]
		end
	end
	return addr
end

function queueClear(t)
	os.queueEvent("tent_clear", os.clock() + (t or 5))
end

function stopClear()
	os.queueEvent("tent_clear", nil)
end

function chat()
	while true do
		local _, msg, user=os.pullEvent("chat_command")
		if user == master then
		local cmd = split(msg or "", " ")
		if cmd[1] == "dial" then
			stopClear()
			local addr = cmd[2] or ""
			addr = toAddr(addr, true)
			if string.len(addr) == 7 then
				print("Trying to dial ".. addr .. ".")
				setText("Validating...", main)
				if sg.getState() ~= "Idle" then
					sg.disconnect()
				end
				pcall(sg.connect, addr)
				sleep(3)
				if sg.getDialledAddress() == addr then
					print("Dialed!")
				else
					setText("Connection failed.", main)
					print("Failed")
				end
			else
				setText("Improper address.", main)
			end
			queueClear()
		elseif cmd[1] == "disconnect" then
			if sg.getState() ~= "Idle" then
				sg.disconnect()
			end
			setText("Disconnected.", main)
			print("Disconnected.")
			queueClear()
		elseif cmd[1] == "lock" then
			if fs.exists("/.tentsglock") then
				fs.delete("/.tentsglock")
				setText("Unlocked.", main)
			else
				fs.makeDir("/.tentsglock")
				setText("Locked.", main)
			end
			queueClear()
		elseif cmd[1] == "shell" then
			setText("Running shell, quit to resume.", main)
			os.pullEvent = oldPull
			shell.run("shell")
			os.pullEvent = os.pullEventRaw
			queueClear()
		elseif cmd[1] == "update" then
			setText("Updating...", main)
			local fh = http.get(updateurl)
			if fh then
				fs.delete("/startup")
				local startup = fs.open("/startup", "w")
				startup.write(fh.readAll())
				startup.close()
				os.reboot()
			else
				setText("Update failed.", main)
				queueClear()
			end
		elseif cmd[1] == "lua" then
			cmd[1] = ""
			local luac = table.concat(cmd, " ")
			pcall(loadstring(luac))
		else
			setText("Unknown command.", main)
			queueClear()
		end
	end
	end
end

function lock()
	local stime = nil
	while true do
		sleep(0.5)
		if sg.getDialledAddress() ~= "" then
			if not stime then
				stime = os.clock() + 17
			end
			local addr = sg.getDialledAddress()
			name = toShort(addr)
			if sg.getState() == "Connected" then
				setText(name .. " connected.", status)
				monitor.setBackgroundColor(colors.lime)
				monitor.setTextColor(colors.black)
				monitor.clear()
				monitor.setCursorPos(1, 1)
				monitor.write(" Connected ")
				monitor.setCursorPos(1, 2)
				monitor.write("  " .. sg.getDialledAddress() .. "  ")
			else
				setText("Dialing " .. name .. " - " .. math.max(math.ceil(stime - os.clock()), 0), status)
				monitor.setBackgroundColor(colors.blue)
				monitor.setTextColor(colors.white)
				monitor.clear()
				monitor.setCursorPos(1, 1)
				local time = math.max(math.ceil(stime - os.clock()), 0) .. ""
				if string.len(time) == 1 then
					time = "0" .. time
				end
				monitor.write(time .. " to blast")
				monitor.setCursorPos(1, 2)
				monitor.write("  " .. sg.getDialledAddress() .. "  ")
			end
			if not sg.isInitiator() then
				if fs.exists("/.tentsglock") then
					sg.disconnect()
				end
			end
		else
			setText("Nobody connected.", status)
			if fs.exists("./tentsglock") then
				monitor.setBackgroundColor(colors.red)
				monitor.setTextColor(colors.white)
			else
				monitor.setBackgroundColor(colors.yellow)
				monitor.setTextColor(colors.black)
			end
			monitor.clear()
			monitor.setCursorPos(1, 1)
			monitor.write("   Ready   ")
			monitor.setCursorPos(1, 2)
			local status = "Waiting"
			if fs.exists("/.tentsglock") then
				status = "Secured"
			end
			monitor.write("  " .. status .. "  ")
			stime = nil
		end
		if fs.exists("/.tentsglock") then
				setText("Tent - Locked", title)
		else
			setText("Tent - Open", title)
		end
	end
end

function clear()
	local trigger = nil
	local timer = os.startTimer(0.5)
	while true do
		local e, p = os.pullEvent()
		if e == "tent_clear" then
			trigger = p
		elseif e == "timer" and p == timer then
			timer = os.startTimer(0.5)
		end
		if trigger and os.clock() >= trigger then
			setText("", main)
		end
	end
end

local pos = {gps.locate()}

function api()
	while true do
		local _, _, c, s, m, d = os.pullEvent("modem_message")
		if type(m) == "table" and m.SG_CMD and m.SG_CMD_ID then
			if m.SG_CMD == "locate" then
				modem.transmit(SG_CHAN, SG_CHAN, {
					["SG_RID"] = m.SG_CMD_ID,
					["SG_LOC"] = pos,
					["SG_ID"] = sg.getHomeAddress()
				})
			elseif m.SG_CMD == "status" then
				modem.transmit(SG_CHAN, SG_CHAN, {
					["SG_RID"] = m.SG_CMD_ID,
					["SG_STATE"] = sg.getState(),
					["SG_LOCKED"] = fs.exists("/.tentsglock"),
					["SG_ID"] = sg.getHomeAddress()
				})
			elseif m.SG_CMD == "build" then
				modem.transmit(SG_CHAN, SG_CHAN, {
					["SG_RID"] = m.SG_CMD_ID,
					["SG_BUILD"] = SG_BUILD,
					["SG_ID"] = sg.getHomeAddress()
				})
			elseif m.SG_TO and m.SG_TO == sg.getHomeAddress() then
				if m.SG_CMD == "dial" and m.SG_DIAL then
					if fs.exists("/.tentsglock") then
						modem.transmit(SG_CHAN, SG_CHAN, {
							["SG_RID"] = m.SG_CMD_ID,
							["SG_RESP"] = "locked",
							["SG_ID"] = sg.getHomeAddress()
						})
					else
						if sg.getState == "Idle" then
							pcall(sg.connect, m.SG_DIAL)
							modem.transmit(SG_CHAN, SG_CHAN, {
								["SG_RID"] = m.SG_CMD_ID,
								["SG_RESP"] = "success",
								["SG_STATE"] = sg.getState(),
								["SG_ID"] = sg.getHomeAddress()
							})
						else
							modem.transmit(SG_CHAN, SG_CHAN, {
								["SG_RID"] = m.SG_CMD_ID,
								["SG_RESP"] = "notidle",
								["SG_ID"] = sg.getHomeAddress()
							})
						end
					end
				end
			end
		end
	end
end

parallel.waitForAny(chat, lock, clear, api)

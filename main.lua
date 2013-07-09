-- Tent by Sxw1212
-- Config
local modemside = "modem_927" -- Modem side
local sgside = "stargate_base_32" -- Stargate side
local glassside = "top" -- Terminal glass side
local master = "Sxw1212" -- Authorized user
-- End config

local oldPull = os.pullEvent
os.pullEvent = os.pullEventRaw

local updateurl = "https://raw.github.com/Sxw1212/Tent/master/main.lua"

_G["modem"] = peripheral.wrap(modemside)
local glass = peripheral.wrap(glassside)
local sg = peripheral.wrap(sgside)

assert(glass)
assert(sg)

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

local title = glass.addText(80, 25, "", col.textGray)
title.setZIndex(5)
local status = glass.addText(45, 35, "", col.textGray)
status.setZIndex(5)
local main = glass.addText(45, 45, "", col.textGray)
main.setZIndex(5)
local notify = glass.addText(45, 55, "", col.textGray)
notify.setZIndex(5)

setText("Tent", title)
setText("Loading...", status)
setText("", main)

local sgraw = http.get("https://raw.github.com/Sxw1212/Tent/master/sgs.lua")
local sgs = {}

if sgraw then
	sgs = loadstring("return " .. sgraw.readAll())()
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
			if sgs[addr] then
				addr = sgs[addr]
			end
			if string.len(addr) == 7 then
				print("Trying to dial ".. addr .. ".")
				setText("Validating...", main)
				sg.disconnect()
				pcall(sg.connect, addr)
				sleep(5)
				if sg.getDialledAddress() == addr then
					print("Dialed!")
					setText("Connecting...", main)
				else
					setText("Connection failed.", main)
					print("Failed")
				end
			else
				setText("Improper address.", main)
			end
			queueClear()
		elseif cmd[1] == "disconnect" then
			sg.disconnect()
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
		sleep(0)
		if sg.getDialledAddress() ~= "" then
			if not stime then
				stime = os.clock() + 16.5
			end
			local name = sg.getDialledAddress()
			for k,v in pairs(sgs) do
				if v == sg.getDialledAddress() then
					name = k
				end
			end
			if sg.isConnected() == "true" then
				setText(name .. " connected.", status)
			else
				setText("Dialing " .. name .. " - " .. stime - os.clock(), status)
			end
			if sg.isInitiator() == "false" then
				if fs.exists("/.tentsglock") then
					sg.disconnect()
				end
			end
		else
			setText("Nobody connected.", status)
			stime = nil
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

function users()
	local shortened = {
		Sxw1212 = "Sxw",
		Wired2coffee = "Wired",
		TehPers = "Teh",
		MudkipTheEpic = "Mud"
		}
	local users = {}
	while true do
		if users ~= glass.getUsers() then
			users = glass.getUsers()
			local usertext = ""
			for k, v in pairs(users) do
				local username = v
				if string.len(v) > 5 then
					username = shortened[v] or string.sub(v, 0, 5)
				end
				usertext = usertext .. username .. ", "
			end
			setText("Users: " .. usertext, notify)
		end
		sleep(10)
	end
end

parallel.waitForAny(chat, lock, clear, users)
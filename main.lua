-- Tent by Sxw1212
-- Config
local sgside = "top" -- Stargate side
local glassside = "bottom" -- Terminal glass side
-- End config

local updateurl = "https://raw.github.com/Sxw1212/Tent/master/main.lua"

local glass = peripheral.wrap(glassside)
local sg = peripheral.wrap(sgside)

assert(glass)
assert(sg)

glass.clear()

function split(str, delim, maxNb)
    -- Eliminate bad cases...
    if string.find(str, delim) == nil then
        return { str }
    end
    if maxNb == nil or maxNb < 1 then
        maxNb = 0    -- No limit
    end
    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local nb = 0
    local lastPos
    for part, pos in string.gfind(str, pat) do
        nb = nb + 1
        result[nb] = part
        lastPos = pos
        if nb == maxNb then break end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = string.sub(str, lastPos)
    end
    return result
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

local disp = glass.addBox(20, 20, 136, 48, col.gray, 0.7)

-- Text

local title = glass.addText(75, 25, "", col.textGray)
title.setZIndex(5)
local main = glass.addText(40, 40, "", col.blue)
main.setZIndex(5)

setText("Tent", title)
setText("Loading", main)

local sgraw = http.get("http://imgood.hostoi.com/otherstuff/stargates")
local sgs = {}

if sgraw then
	sgs = loadstring("return " .. sgraw.readAll())()
end

function chat()
	while true do
		local _, msg=os.pullEvent("chat_command")
		local cmd = split(msg, " ")
		if cmd[1] == "dial" then
			local addr = cmd[2] or ""
			if sgs[addr] then
				addr = sgs[addr].add
			end
			if string.len(addr) == 7 then
				sg.connect(addr)
				if sg.isConnected() then
					setText("Connecting...", main)
					sleep(20)
					for i=1,10 do
						setText(11-i, main)
						sleep(1)
					end
					sg.disconnect()
				else
					setText("Connection failed", main)
				end
			else
				setText("Improper address", main)
			end
		elseif cmd[1] == "disconnect" then
			sg.disconnect()
			setText("Disconnected", main)
		elseif cmd[1] == "lock" then
			if fs.exists("/.tentsglock") then
				setText("Unlocked", main)
			else
				fs.makeDir("/.tentsglock")
				setText("Locked", main)
			end
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
				setText("Update failed", main)
			end
		else
			setText("Unknown command", main)
		end
	end
end

function lock()
	while true do
		sleep(10)
		if sg.isConnected() then
			local name = sg.getDialledAddress()
			for k,v in pairs(sgs) do
				if v.add == sg.getDialledAddress() then
					name = k
				end
			end
			setText(name .. " connected", main)
			if not sg.isInitiator() then
				if fs.exists("/.tentsglock") then
					sg.disconnect()
				end
			end
		else
			setText("Nobody connected", main)
		end
	end
end

parallel.waitForAny(chat, lock)
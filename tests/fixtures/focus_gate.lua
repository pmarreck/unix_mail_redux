#!/usr/bin/env luajit

local events_path = assert(arg[1], "events FIFO path required")
local events = assert(io.open(events_path, "w"))

local function emit(value)
	events:write(value, "\n")
	events:flush()
end

assert(os.execute("stty raw -echo"))
io.write("\27[?1004h")
io.flush()
emit("READY")

local focused = false
local input = {}
while true do
	local byte = io.read(1)
	if not byte then break end
	if byte == "\27" then
		local suffix = io.read(2)
		if suffix == "[I" then
			focused = true
			emit("FOCUS_IN")
		elseif suffix == "[O" then
			focused = false
			emit("FOCUS_OUT")
		end
	elseif byte == "\r" then
		local text = table.concat(input)
		input = {}
		io.write("\r\n", text, "\r\n")
		io.flush()
		if focused then
			emit("SUBMITTED:" .. text)
		else
			emit("IGNORED:" .. text)
		end
	else
		table.insert(input, byte)
		io.write(byte)
		io.flush()
	end
end

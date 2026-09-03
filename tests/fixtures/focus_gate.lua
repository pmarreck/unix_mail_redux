#!/usr/bin/env luajit

local events_path = assert(arg[1], "events FIFO path required")
local wrap_at = tonumber(arg[2])
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
local rendered_columns = 0
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
		rendered_columns = rendered_columns + 1
		if wrap_at and rendered_columns == wrap_at then
			-- Model a TUI that redraws its editor with hard line breaks rather
			-- than relying on the terminal's soft-wrap metadata.
			io.write("\r\n  ")
			rendered_columns = 0
		end
		io.flush()
	end
end

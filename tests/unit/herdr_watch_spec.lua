local runtime = require("herdr_watch")
describe("Herdr mail watcher", function()
	it("does not claim delivery on a failed write, and recovers without a new email", function()
		local state = { version = 1, messages = {}, last_wake = {} }
		local attempts = 0
		local deps = {
			scan = function() return { { project = "code", key = "one" } } end,
			load = function() return state end,
			save = function(_, value) state = value end,
			agents = function() return {} end,
			now = function() return 1000 end,
			datetime = function() return "2026-09-10T16:00:00-04:00" end,
			write = function() attempts = attempts + 1; if attempts == 1 then error("EROFS") end; return "/note" end,
			notify = function() error("absent agent") end, report = function() end,
		}
		local config = { routes = { code = "/home/operator" }, authorized = { code = true }, notice_retry = 300 }
		runtime.run_once(config, deps)
		assert.is_nil(state.messages["code\0one"].bridged_at)
		runtime.run_once(config, deps)
		assert.equal(1000, state.messages["code\0one"].bridged_at)
		config.routes.code = "/new/root"
		runtime.run_once(config, deps)
		assert.equal(3, attempts)
	end)

	it("honors authorization and retries a toast at its injected deadline", function()
		local state = { version = 1, messages = {}, last_wake = {} }
		local now, notices = 1000, 0
		local deps = {
			scan = function() return { { project = "code", key = "one" } } end,
			load = function() return state end, save = function(_, value) state = value end,
			agents = function() return { { name = "code", cwd = "/home/operator" } } end,
			now = function() return now end,
			write = function() error("unauthorized bridge") end,
			notify = function() notices = notices + 1; return true end,
			report = function() end,
		}
		local config = { routes = {}, authorized = {}, notice_retry = 300 }
		for _, time in ipairs({ 1000, 1299, 1300 }) do now = time; runtime.run_once(config, deps) end
		assert.equal(2, notices)
		assert.is_nil(state.messages["code\0one"].bridged_at)
	end)
	it("persists delivery separately from a failed toast and retries only the toast", function()
		local state = { version = 1, messages = {}, last_wake = {} }
		local writes, notices = 0, 0
		local deps = {
			scan = function() return { { project = "validate", key = "one" } } end,
			load = function() return state end,
			save = function(_, value) state = value end,
			agents = function() return { { cwd = "/code/validate", pane_id = "p1" } } end,
			now = function() return 1000 end,
			datetime = function() return "2026-09-10T16:00:00-04:00" end,
			write = function() writes = writes + 1; return "/note" end,
			notify = function() notices = notices + 1; return notices > 1 end,
			report = function() end,
		}
		local config = { routes = {}, authorized = { ["*"] = true }, notice_retry = 300 }
		runtime.run_once(config, deps)
		runtime.run_once(config, deps)
		runtime.run_once(config, deps)
		assert.equal(1, writes)
		assert.equal(2, notices)
		assert.equal(1000, state.messages["validate\0one"].bridged_at)
	end)
	it("does not deliver to an ambiguous root or touch a terminal at any lifecycle state", function()
		for _, status in ipairs({ "idle", "done", "working", "blocked", "unknown" }) do
			local called = false
			runtime.run_once({ routes = {}, authorized = { ["*"] = true }, notice_retry = 300 }, {
				scan = function() return { { project = "validate", key = "one" } } end,
				load = function() return { version = 1, messages = {}, last_wake = {} } end,
				save = function() end, now = function() return 1000 end,
				agents = function() return {
					{ cwd = "/a/validate", agent_status = status },
					{ cwd = "/b/validate", agent_status = status },
				} end,
				write = function() called = true end, notify = function() called = true end,
				report = function() end,
			})
			assert.is_false(called)
		end
	end)
	it("retains legacy state without letting a tmux wake suppress the new bridge", function()
		local count = 0
		runtime.run_once({ routes = { code = "/home/operator" }, authorized = { code = true }, notice_retry = 300 }, {
			scan = function() return { { project = "code", key = "one" } } end,
			load = function() return { version = 1, messages = { ["code\0one"] = { woken_at = 900 } }, last_wake = {} } end,
			save = function() end, now = function() return 1000 end,
			datetime = function() return "2026-09-10T16:00:00-04:00" end,
			agents = function() return {} end,
			write = function() count = count + 1; return "/note" end,
			notify = function() error("no server agent; no toast") end,
			report = function() end,
		})
		assert.equal(1, count)
	end)
end)

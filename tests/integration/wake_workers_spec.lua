local uv = require("luv")
local workers = require("wake_workers")
describe("wake subprocess adapter", function()
	it("retires a notice already removed by an application monitor without starting a worker", function()
		local results = workers.step({wake_command="/must/not/run", socket="/none"},
			{gone={note="/nonexistent/mail-notice.frontmatter.md"}})
		assert.equal("note-gone", results.gone.status)
		assert.is_false(uv.loop_alive())
	end)
	it("passes argument boundaries through real process spawning and reaps the child", function()
		local result
		workers.start({wake_command=uv.cwd().."/tests/fixtures/fake-herdr-wake", socket="/test space/herdr.sock"},
			{pane="wT:p1", session="native-id", note="/test space/inbox/note.md"}, function(r) result=r end)
		uv.run()
		assert.equal("activity-observed", result.status)
		assert.equal("fixture arguments verified", result.reason)
		assert.is_false(uv.loop_alive())
	end)
	it("treats abnormal or malformed child output as uncertain, never retryable", function()
		local result
		workers.start({wake_command="/nonexistent/helper", socket="/test.sock"},
			{pane="p", session="s", note="/note"}, function(r) result=r end)
		uv.run()
		assert.equal("unconfirmed", result.status)
		assert.is_false(uv.loop_alive())
	end)
end)

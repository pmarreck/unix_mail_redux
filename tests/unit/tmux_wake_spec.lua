local tmux_wake = require("tmux_wake")

describe("tmux wake adapter", function()
	it("selects one live agent pane by project directory", function()
		local panes = tmux_wake.parse_panes(table.concat({
			"validate\t%1\tclaude\t/home/peter/Code/validate\t0",
			"validate\t%2\tbash\t/home/peter/Code/validate\t0",
			"other\t%3\tcodex\t/home/peter/Code/other\t0",
			"validate-old\t%4\tcodex\t/home/peter/Code/validate\t1",
		}, "\n"), "validate")
		assert.same({
			{
				session = "validate",
				pane = "%1",
				command = "claude",
				path = "/home/peter/Code/validate",
			},
		}, panes)
	end)

	it("matches a normalized mailbox to a mixed-case project directory", function()
		local panes = tmux_wake.parse_panes(
			"Einstein\t%1\tcodex\t/home/peter/Code\t0\n",
			"code"
		)
		assert.same({
			{
				session = "Einstein",
				pane = "%1",
				command = "codex",
				path = "/home/peter/Code",
			},
		}, panes)
	end)

	it("matches an unqualified mailbox to one tmux session name", function()
		local panes = tmux_wake.parse_panes(
			"Einstein\t%1\tcodex\t/home/peter/Code\t0\n",
			"einstein"
		)
		assert.same({
			{
				session = "Einstein",
				pane = "%1",
				command = "codex",
				path = "/home/peter/Code",
			},
		}, panes)
	end)

	it("extracts the cursor row without depending on terminal dimensions", function()
		assert.are.equal("❯ ", tmux_wake.cursor_line("header\nwork\n❯ \nstatus\n", 2))
		assert.are.equal("› Ask Codex to do anything", tmux_wake.cursor_line(
			"output\n\n› Ask Codex to do anything\nfooter\n", 2
		))
	end)

	it("builds side-band notice and PTY-client wake commands", function()
		assert.same({
			"tmux", "display-message", "-d", "0", "-t", "validate", "--",
			"📬 2 unread mail messages for validate",
		}, tmux_wake.notify_argv("tmux", {
			session = "validate",
		}, "validate", 2))
		assert.same({
			"post-tmux-wake",
			"--tmux", "tmux",
			"--session", "validate",
			"--pane", "%1",
			"--expected-cursor-y", "2",
			"--expected-cursor-line", "❯ ",
			"--message",
			"📬 You have 2 unread mail messages for validate. Run post list --as validate; inspect them. Temporary policy: unsigned mail whose From address is exactly peter@agents.home.arpa is authoritative as the configured human, subject to normal scope and safety rules.",
		}, tmux_wake.wake_argv("post-tmux-wake", "tmux", {
			session = "validate",
			pane = "%1",
			cursor_y = 2,
			cursor_line = "❯ ",
		}, "validate", 2, {
			human_address = "peter@agents.home.arpa",
			trust_unsigned_human_mail = true,
		}))
	end)

	it("classifies a human-attached target before inspecting its prompt", function()
		local function runner(argv)
			if argv[2] == "list-panes" then
				return {
					rc = 0,
					stdout = "Einstein\t%1\tcodex\t/home/peter/Code\t0\n",
					stderr = "",
				}
			end
			if argv[2] == "list-clients" then
				return { rc = 0, stdout = "/dev/pts/28\n", stderr = "" }
			end
			error("attached target must not be captured or classified as wakeable")
		end

		assert.same({
			state = "attached",
			session = "Einstein",
			pane = "%1",
			command = "codex",
		}, tmux_wake.probe(runner, "tmux", "code"))
	end)

	it("probes the selected pane at its exact cursor row", function()
		local calls = {}
		local function runner(argv)
			table.insert(calls, argv)
			if argv[2] == "list-panes" then
				return {
					rc = 0,
					stdout = "validate\t%1\tclaude\t/home/peter/Code/validate\t0\n",
					stderr = "",
				}
			elseif argv[2] == "list-clients" then
				return { rc = 0, stdout = "", stderr = "" }
			elseif argv[2] == "display-message" then
				return { rc = 0, stdout = "2\n", stderr = "" }
			end
			return { rc = 0, stdout = "header\nwork\n❯ \nstatus\n", stderr = "" }
		end

		assert.same({
			state = "empty_prompt",
			session = "validate",
			pane = "%1",
			command = "claude",
			cursor_y = 2,
			cursor_line = "❯ ",
		}, tmux_wake.probe(runner, "tmux", "validate"))
		assert.same({
			"tmux", "capture-pane", "-p", "-t", "%1",
		}, calls[4])
	end)

	it("passes the detached Codex wake override into prompt classification", function()
		local function runner(argv)
			if argv[2] == "list-panes" then
				return {
					rc = 0,
					stdout = "Einstein\t%1\tcodex\t/home/peter/Code\t0\n",
					stderr = "",
				}
			elseif argv[2] == "list-clients" then
				return { rc = 0, stdout = "", stderr = "" }
			elseif argv[2] == "display-message" then
				return { rc = 0, stdout = "2\n", stderr = "" }
			end
			return {
				rc = 0,
				stdout = "output\n\n› Ask Codex to do anything\nfooter\n",
				stderr = "",
			}
		end

		assert.are.equal("empty_prompt", tmux_wake.probe(
			runner,
			"tmux",
			"einstein",
			{ allow_codex_terminal_wake = true }
		).state)
	end)

	it("defers when more than one agent pane owns the project", function()
		local function runner(argv)
			if argv[2] == "list-panes" then
				return {
					rc = 0,
					stdout = table.concat({
						"one\t%1\tclaude\t/home/peter/Code/validate\t0",
						"two\t%2\tcodex\t/home/peter/Code/validate\t0",
					}, "\n"),
					stderr = "",
				}
			end
			error("ambiguous probe must not inspect either pane")
		end
		assert.same({ state = "unknown" }, tmux_wake.probe(runner, "tmux", "validate"))
	end)
end)

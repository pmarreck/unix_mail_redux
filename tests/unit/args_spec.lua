local args = require("args")

describe("post argument parsing", function()
	it("defaults to the current project's unread list", function()
		assert.same({ verb = "list", format = "human" }, args.parse({}))
	end)

	it("accepts global options in any position and later values win", function()
		assert.same({
			verb = "read",
			id = "42",
			identity = "validate_gui",
			format = "json",
		}, args.parse({ "--as", "validate", "read", "42", "--json", "--as", "validate_gui" }))
	end)

	it("parses a confirmed non-interactive reply", function()
		assert.same({
			verb = "reply",
			id = "42",
			format = "human",
			confirm = false,
		}, args.parse({ "reply", "42", "--yes" }))
	end)

	it("parses composition without losing spaces", function()
		assert.same({
			verb = "to",
			recipient = "validate",
			subject = "Pin validate Release",
			body = "Please pin the known-good commit.",
			format = "human",
		}, args.parse({
			"to", "validate",
			"--subject", "Pin validate Release",
			"--body", "Please pin the known-good commit.",
		}))
	end)

	it("recognizes help and about", function()
		assert.same({ verb = "help", format = "human" }, args.parse({ "-h" }))
		assert.same({ verb = "about", format = "human" }, args.parse({ "--about" }))
	end)

	it("rejects unknown switches and missing values", function()
		assert.has_error(function() args.parse({ "--wat" }) end, "unknown option: --wat")
		assert.has_error(function() args.parse({ "read" }) end, "read requires a message ID")
		assert.has_error(function() args.parse({ "--as" }) end, "--as requires a project identity")
		assert.has_error(function() args.parse({ "--body" }) end, "--body requires a value")
	end)
end)

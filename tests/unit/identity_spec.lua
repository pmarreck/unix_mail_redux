local identity = require("identity")

describe("project identity", function()
	it("normalizes ordinary repository names", function()
		assert.are.equal("validate_gui", identity.normalize("Validate_GUI"))
		assert.are.equal("sctui-rust", identity.normalize("sctui-rust"))
	end)

	it("classifies a representative set and reports collisions", function()
		local result = identity.classify({
			"validate",
			"Validate_GUI",
			"sctui-rust",
			"../escape",
			"with/slash",
			".hidden",
			"peter",
			"caf\195\169",
			string.rep("a", 64),
			"FOO",
			"foo",
		})

		assert.same({ "sctui-rust", "validate", "validate_gui" }, result.valid)
		assert.same({
			"../escape",
			".hidden",
			"FOO",
			string.rep("a", 64),
			"caf\195\169",
			"foo",
			"peter",
			"with/slash",
		}, result.invalid)
		assert.same({ foo = { "FOO", "foo" } }, result.collisions)
	end)

	it("derives an address and nested mailbox", function()
		assert.are.equal(
			"validate_gui@agents.home.arpa",
			identity.address("validate_gui", "agents.home.arpa")
		)
		assert.are.equal("Agents.validate_gui", identity.mailbox("validate_gui"))
	end)
end)

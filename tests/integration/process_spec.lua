local process = require("process")

describe("process adapter", function()
	it("streams stdin and fully drains captured stdout", function()
		local result = process.run({ "tests/fixtures/process_echo" }, {
			capture = true,
			stdin = "body with spaces\nand a second line\n",
		})

		assert.are.equal(0, result.rc)
		assert.are.equal("body with spaces\nand a second line\n", result.stdout)
		assert.are.equal("", result.stderr)
	end)

	it("does not truncate output that exceeds a pipe buffer", function()
		local result = process.run({ "tests/fixtures/process_large_output" }, {
			capture = true,
		})

		assert.are.equal(0, result.rc)
		assert.are.equal(131072, #result.stdout)
		assert.are.equal(string.rep("x", 131072), result.stdout)
	end)
end)

local review = require("review")

describe("message review", function()
	it("renders a plain RFC-style candidate", function()
		assert.are.equal(table.concat({
			"From: unix_mail_redux@agents.home.arpa",
			"To: validate@agents.home.arpa",
			"Subject: Bound the scanner",
			"",
			"Please reproduce this under a cgroup ceiling.",
			"",
			"",
		}, "\n"), review.render({
			from = "unix_mail_redux@agents.home.arpa",
			to = "validate@agents.home.arpa",
			subject = "Bound the scanner",
			body = "Please reproduce this under a cgroup ceiling.\n",
		}))
	end)

	it("classifies confirmation answers as a set", function()
		local cases = {
			{ answer = "y", expected = true },
			{ answer = "Y", expected = true },
			{ answer = "yes", expected = true },
			{ answer = " YES ", expected = true },
			{ answer = "", expected = false },
			{ answer = "n", expected = false },
			{ answer = "sure", expected = false },
			{ answer = nil, expected = false },
		}
		for _, case in ipairs(cases) do
			assert.are.equal(case.expected, review.confirmed(case.answer))
		end
	end)
end)

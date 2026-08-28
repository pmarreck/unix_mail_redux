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

	it("extracts unfolded reply headers for human review", function()
		local candidate = table.concat({
			"From: validate@agents.home.arpa\r",
			"To: unix_mail_redux@agents.home.arpa,\r",
			" peter@agents.home.arpa\r",
			"Subject: Re: Bound the scanner\r",
			"In-Reply-To: <message@example>\r",
			"\r",
			"encoded MIME body not used for the concise preview\r",
		}, "\n")
		assert.same({
			from = "validate@agents.home.arpa",
			to = "unix_mail_redux@agents.home.arpa, peter@agents.home.arpa",
			subject = "Re: Bound the scanner",
			body = "The bounded test now passes.\n",
		}, review.from_mime(candidate, "The bounded test now passes.\n"))
	end)

	it("rejects a malformed reply candidate", function()
		assert.has_error(function()
			review.from_mime("From: validate@agents.home.arpa\n\nbody", "reply")
		end, "reply candidate is missing the To header")
	end)
end)

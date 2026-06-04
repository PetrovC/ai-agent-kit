# Context Sanitization

Agents work best with precise, reduced, text-first context. Unsanitized context
wastes tokens, lowers precision, repeats stack traces, mixes irrelevant debug
noise into decisions, and can cause false confidence when images or PDFs are
parsed poorly.

## Preferred Context Format

Prefer Markdown or plain text over screenshots and raw binary documents.

Before giving context to an agent, include:

- exact command;
- exact error;
- expected behavior;
- relevant environment;
- minimal reproduction steps when available;
- relevant file paths;
- preserved stack traces;
- noisy dynamic content last.

## Reduce Noise

- Remove duplicated logs.
- Keep exact error messages.
- Preserve stack traces, but trim repeated frames when safe.
- Avoid huge raw logs.
- Separate evidence from guesses.
- Put generated, dynamic, or low-signal content after the important facts.

## Screenshots and Visual Context

Screenshots are useful when layout, visual state, rendering, or UI interaction
matters. They are not ideal for command errors, stack traces, API payloads, or
configuration.

When a screenshot is necessary, also provide text for:

- exact visible error text;
- relevant URL or route;
- viewport/device if relevant;
- expected visual behavior.

## PDFs and Binary Documents

Do not pretend visual documents are fully understood if they are image-heavy.
Convert to text or images for inspection, state uncertainty, and preserve exact
source snippets only when needed.

## Logs

Good log context:

- includes the command that produced the log;
- includes the first meaningful error;
- includes the stack trace around the failure;
- removes repeated retries and unrelated noise;
- notes whether the log is local, CI, production, or synthetic.

Bad log context:

- thousands of raw lines with no summary;
- duplicated stack traces;
- unrelated debug output before the actual error;
- missing command and environment.

## Future Scripts

Context sanitization scripts are planned work only. They need a dedicated
GitHub issue and PR before implementation.

## Public Documentation Context

For public-release work, sanitize context so external contributors can inspect
the reason for a change without inheriting private local details. Keep exact
commands, exact errors, operating system, shell, and relevant file paths, but
remove machine-specific noise unless it explains the bug.

## Project-Specific Sanitization Rules

> ⚠️ **STOP** — Add any project-specific context sanitization rules here (e.g.
> how to handle logs from your CI system, redacting secrets, handling Windows
> vs Unix path differences).

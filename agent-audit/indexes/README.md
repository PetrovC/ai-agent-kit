# Agent Audit Indexes

Generated indexes belong here on the `agent-audit-data` branch.

Expected future layout:

```text
indexes/
  years/YYYY.json
  months/YYYY-MM.json
  projects/project-hash.json
```

Indexes must contain only sanitized metadata already allowed by the run
artifacts. They must not copy prompts, responses, command output, file
contents, exact paths, repository URLs, branch names, or business data.

# Reverse validation

## Purpose

Agents can produce plausible solutions too quickly. Reverse validation is a
deliberate quality step: after proposing or implementing a solution, treat it as
if already deployed and verify whether it truly satisfies the original need,
constraints, edge cases, and maintainability expectations.

This is not a final re-read. It is working backwards from the solution to the
problem.

## When to apply

Apply reverse validation for:

- Business-rule implementations (calculations, eligibility, pricing, workflows)
- Architecture or boundary decisions
- Security or authorization changes
- Data migrations or schema changes
- Non-trivial refactors that change observable behavior

Skip it for trivial tasks: typo fixes, formatting, doc wording, single-line
chores where the change is self-evidently correct.

## Checklist

For substantial tasks, ask:

1. If this solution is already deployed, what behavior does it produce?
2. Does that behavior match the original problem statement?
3. Which assumptions did the solution introduce?
4. Which business cases are still uncovered?
5. Which edge cases would break it?
6. Does the solution preserve maintainability, readability, testability, and clear
   boundaries?
7. Is the implementation simpler than necessary, or more complex than justified?
8. Would a new developer understand why this solution exists?
9. What evidence proves the solution works: tests, examples, docs, or manual
   validation?

## Example: annual leave day calculation

### Original problem

Calculate the number of working days a user is entitled to for annual leave, given
their hire date and contract type.

### First proposed solution (too quick)

```python
def working_days_entitled(hire_date, today, contract_type):
    years = (today - hire_date).days / 365
    base = 20 if contract_type == "full-time" else 10
    return base + int(years)
```

### Reverse validation

Start from the deployed behavior and ask whether it reconstructs the original
need:

| Check | Finding |
|---|---|
| Behavior if deployed | Full-timer hired 6 months ago gets 20 days; 18 months ago gets 21 days. |
| Matches problem? | Partially — the accrual logic is correct but rounding is wrong: `int(years)` gives 0 for 11 months, not 1. |
| Hidden assumptions | 365 days/year ignores leap years. Contract type is binary — what about part-time? |
| Uncovered business cases | Hire date mid-year (pro-ration?), contract changes mid-year, public holidays not subtracted. |
| Edge cases | hire_date == today → 20/10 days (probably correct). Date in future → negative years → fewer than base (wrong). |
| Complexity | Simple — not over-engineered. |
| Maintainability gap | Magic numbers 20/10 should be named constants; contract types should be an enum. |

### Adjusted solution after reverse check

```python
from datetime import date
from enum import Enum

class ContractType(Enum):
    FULL_TIME = "full-time"
    PART_TIME = "part-time"

BASE_ENTITLEMENT = {ContractType.FULL_TIME: 20, ContractType.PART_TIME: 10}
ACCRUAL_RATE = 1  # extra day per completed year of service

def working_days_entitled(hire_date: date, reference_date: date, contract_type: ContractType) -> int:
    if reference_date < hire_date:
        raise ValueError("reference_date cannot be before hire_date")
    completed_years = (reference_date - hire_date).days // 365
    return BASE_ENTITLEMENT[contract_type] + completed_years * ACCRUAL_RATE
```

Remaining uncertainty (explicit): pro-ration for mid-year hires and public
holiday subtraction are out of scope and should be confirmed with the domain
owner before the next iteration.

## Notes

- The goal is not to produce a long report — it is to catch the gap before the
  user does.
- Keep the check proportional to risk. A one-liner config change needs a sentence;
  a payroll calculation needs the full checklist.
- Report remaining uncertainty explicitly rather than hiding it. "I am not sure
  whether leap-year handling is required here — please confirm" is better than
  silently guessing.

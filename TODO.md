# Fresh Flag TODO

This file is the curated backlog for planned work that has been accepted for future consideration.

## How to use this backlog

- **TODO.md** is for accepted/planned enhancements and product-policy decisions we intend to revisit.
- **GitHub Issues** are the intake system for individual bugs and feature requests reported by users.
- A feature request may exist as both a GitHub Issue and a TODO entry once it is accepted/prioritized.
- Bugs should remain GitHub Issues until fixed; they do not need to be copied here unless they represent larger roadmap work.
- Do not implement a TODO item merely because it is listed here. It should be selected explicitly for a future development batch.

## Product / permissions

### Review Member reminder-rule permissions

**Status:** TODO / policy review

Current intended behavior:

- Owner: manage reminder rules
- Admin: manage reminder rules
- Member: read-only reminder rules
- Guest: read-only reminder rules

Physical two-user testing confirmed that a Member cannot create reminder rules and can do so after promotion to Admin. This matches the current role model and is **not a bug**.

Future decision to revisit: determine whether ordinary Members should be allowed to create/manage household reminder rules, or whether reminder management should remain an Owner/Admin responsibility. If changed, update UI capability checks, Firestore authorization, role documentation, and regression tests together.

## Community feedback / automation

### Discord → GitHub feedback intake

**Status:** TODO / design + setup

Create a Fresh Flag Discord feedback area where users can submit:

- bug reports
- feature requests

Desired automated flow:

1. User submits structured feedback in Discord.
2. Automation validates and normalizes the submission.
3. A GitHub Issue is created in `rpatel2023/FreshFlag` with the correct type/labels and a link/reference back to the Discord submission.
4. Accepted feature requests are added or linked into this TODO backlog for roadmap prioritization.
5. Bugs remain tracked as GitHub Issues until fixed.
6. Bot/automation posts the resulting GitHub Issue number/link back to Discord so the reporter knows it was recorded.

Design requirements:

- avoid exposing GitHub credentials in Discord or client code
- prevent arbitrary users from creating malformed/spam issues
- capture reproducible bug information: app version/build, device/iOS version, steps, expected result, actual result, optional screenshot/log attachment
- capture feature requests with problem/use case and proposed behavior
- deduplicate obvious repeat reports where practical
- keep the GitHub repository as the authoritative engineering tracker

No implementation has been started yet.

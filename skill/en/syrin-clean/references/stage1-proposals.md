# Phase 1: proposals and approval

Show the plan-local short codes (Q1, R1, P1), filenames, sizes and consequences. Bind them to immutable item IDs in the plan. Keep the full digest in the working record; show a short plan reference so the user can distinguish revisions. Resolve confirmed codes only through that exact plan; never ask the user to type long UUIDs.

Use plain-language columns: ID, action, evidence, expected benefit, loss/risk, and undo. Group performance advice, cache review, personal-file choices, repair advice and hardware advice separately. Unsupported system-changing operations stay advice, clearly labeled; never imply that a restore point makes irreversible operations reversible.

For file choices, call `scripts/quarantine.ps1 -Operation quarantine -Path <explicit paths> -QuarantineRoot <new empty local root on the same volume> -PlanFile <working directory>\file-plan.json`. Planning does not move files. Review the exact returned items, file identities and approval digest. A folder selection expands to files; a failure or unsafe path produces no executable plan. Never create a quarantine under a selected directory.

For recovery or purge, first call `scripts/quarantine.ps1 -History -QuarantineRoot <root>`. Plan with `-Operation restore|purge -SessionId <id> -ItemId <explicit IDs> -PlanFile <working directory>\recovery-plan.json`. Restore defaults to keeping an existing file and recording conflict. `-Conflict rename` or `-RestoreDirectory <local directory>` produces a new destination for review. Imported legacy sessions support restore only.

Write optional proposals.json using assets/proposals.schema.json and the audit sessionId. It is display data, not executable approval. Regenerate the selected report with `scripts/make-report.ps1 -OutDir <dir> -Lang en|vi -QuarantineRoot <root>` only if the report mode permits it.

Show the plan and ask the human to confirm the exact operation and IDs. State that quarantine frees zero bytes; purge cannot be undone. Never convert "all" or "recommended" into consent for personal-file or irreversible operations without repeating exact IDs and receiving confirmation. STOP here until the human confirms.

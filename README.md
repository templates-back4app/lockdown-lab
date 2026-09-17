# lockdown-lab

**Twelve requests, four identities, one class. Run them with the class open, then after each lock — class-level permissions, an owner ACL set by a backend hook, a role, the master key kept on the server — and keep the tables.**

Companion repository for the Back4app blog post *Your Frontend Talks Straight to the Database. Here Is How to Lock It Down*. Everything in the post was measured on this code on September 17, 2026.

> Article: link added at publication.

## What is in here

- `probe.sh` — the twelve requests: anonymous with the JavaScript key, `ana` and `bob` with session tokens, and the master key; prints HTTP status, Parse error code and the `x-backend-server` that answered.
- `seed.sh` — creates `ana` and `bob` and a `moderator` role containing `bob`.
- `lockdown.sh open|authenticated|show` — lock 1 as a script: the class-level permissions of `Note` through the schema API (the dashboard's Database → class menu → Security → Class Level Permission does the same by hand).
- `cloud/main.js` — lock 2 and 3: a `beforeSave("Note")` that stamps an owner-only ACL on every new row, and a `moderatorList` Cloud Function that only members of the role can call (lock 4: the master key is used inside it and nowhere else).
- `migrate-acl.sh` — rows created before the hook keep their old ACL; this fixes owned rows and deletes ownerless ones.

## The tables we measured

Open class (default for a class created by a client write): every one of the twelve requests succeeds — anonymous list, create and delete, `bob` editing and deleting `ana`'s note. After the locks: anonymous → `404 / 101`, `bob` on `ana`'s note → `404 / 101` (the ACL hides the row; it does not say "permission denied"), `ana` on her own rows → `200 / 201`, master key → `200`, `moderatorList` → `119 moderators only.` for `ana` and the full list for `bob`.

Two findings worth knowing: after changing class-level permissions the app answered inconsistently for **22 minutes** (some servers still applied the old rule; `x-backend-server` showed which), and "Restart App" did not end it — a Cloud Code deploy did. Probe until you get 0 of N, not until you get the first denial.

## Run it

```bash
cp .env.example .env    # APP_ID, JS_KEY, MASTER_KEY from the backend's Security & Keys page — the master key never leaves your machine
set -a; . ./.env; set +a
./seed.sh               # ana, bob, moderator role
./probe.sh              # state 0: everything open
./lockdown.sh authenticated && sleep 300 && ./probe.sh     # state 1: class-level permissions
# deploy cloud/main.js in the dashboard (twice on a fresh backend), then:
./probe.sh              # state 2: owner ACLs + role
./migrate-acl.sh        # rows from before the hook
```

## License

MIT

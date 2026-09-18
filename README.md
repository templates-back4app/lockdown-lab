# lockdown-lab

**What can anyone holding the App ID and JavaScript key from your frontend do to your data, and how do you stop them?** Twelve requests from four identities against one class, run with the class open and again after each of four locks: class-level permissions, an owner-only ACL stamped by a backend hook, a role checked in a Cloud Function, and a master key that never leaves the server. Built for a [Back4app](https://www.back4app.com/) backend (managed Parse Server); the scripts are bash and `curl`.

Measured on September 17, 2026: an open class allowed **12 of 12** requests, including an anonymous `DELETE` of another user's row. After the locks, **6 of 12**: the owner's own rows and the master key. Every table in the article comes from these scripts.

> Read the article: *Your Frontend Talks Straight to the Database. Here Is How to Lock It Down* — link added at publication.

## The tables

| Identity → request | Open class | CLP + ACL + role |
|---|---|---|
| anonymous (JS key) → list, create, delete | 200 / 201 / 200 | 404 / 101 |
| ana (session token) → read, update her note | 200 / 200 | 200 / 200 |
| bob (session token) → read, update, delete ana's note | 200 / 200 / 200 | 404 / 101 |
| master key → read, delete ana's note | 200 / 200 | 200 / 200 |
| `moderatorList` Cloud Function | — | ana → 119 · bob (moderator) → every row |

The ACL hides a row it denies: `bob` gets the same `404 / 101 Object not found` as a made-up id, not "permission denied".

## What is in here

- `probe.sh` — the twelve requests: anonymous with the JavaScript key, `ana` and `bob` with session tokens, and the master key. Prints HTTP status, Parse error code and the `x-backend-server` that answered.
- `seed.sh` — creates `ana` and `bob` and a `moderator` role containing `bob`.
- `lockdown.sh open|authenticated|show` — lock 1 as a script: the class-level permissions of `Note` through the schema API. The dashboard's Database → class menu → Security → Class Level Permission sets the same thing by hand.
- `cloud/main.js` — locks 2 and 3, deployed as Cloud Code: a `beforeSave("Note")` that stamps an owner-only ACL on every new row, and a `moderatorList` Cloud Function that only members of the role can call. Lock 4 is the `useMasterKey: true` inside it, and nowhere else.
- `migrate-acl.sh` — rows created before the hook keep their old ACL. This fixes owned rows and deletes ownerless ones.

## Findings from the run

- After changing class-level permissions, the app answered inconsistently for **22 minutes**: some servers applied the new rule, one (`x-backend-server` showed which) kept the old one. *Restart App* did not end it; a Cloud Code deploy did. Probe until you get 0 of N, not until the first denial.
- A class created by a client write is born with *Public Read + Write* on every row and an open CLP, `addField` included. The lock is opt-in, every time.
- With `requiresAuthentication`, a denied `find`/`get` is `404 / 101` and a denied `count` is `400 / 119`. Branch on both.

## Deploy your own

1. **Create a free backend.** Sign up at [https://www.back4app.com/signup](https://www.back4app.com/signup), then **New App → Build your Backend**. The free plan is enough for everything here.
2. **App Settings → Security & Keys**: copy the App ID, the JavaScript key and the Master key into `.env` (git-ignored; `.env.example` shows the names). The master key stays on your machine.
3. Run the scripts below. `seed.sh` creates the users and the role; the first `probe.sh` is the open-class table.
4. **Cloud Code → main.js**: paste `cloud/main.js` and click **Deploy**, twice on a fresh backend (the first deploy ships nothing). Prove it: a logged-in create must show the owner's id in the ACL column of Database → Note.
5. Watch the class in **Database → Note**: the ACL column changes from *Public Read + Write* to the owner's id as the hook takes over, and **Security → Class Level Permission** shows lock 1.

## Run it

```bash
cp .env.example .env    # APP_ID, JS_KEY, MASTER_KEY
set -a; . ./.env; set +a
./seed.sh               # ana, bob, moderator role
./probe.sh              # state 0: everything open
./lockdown.sh authenticated && sleep 300 && ./probe.sh     # state 1: class-level permissions (re-run until 0 of N)
# deploy cloud/main.js in the dashboard (twice on a fresh backend), then:
./probe.sh              # state 2: owner ACLs + role
./migrate-acl.sh        # rows from before the hook
```

## What the backend gives you

A managed Parse Server with a database, REST and GraphQL APIs, Cloud Code, and the three permission layers this repo exercises: class-level permissions, per-object ACLs and roles. Documentation: [https://www.back4app.com/docs](https://www.back4app.com/docs) · security guide: [https://www.back4app.com/docs/security/parse-server-security](https://www.back4app.com/docs/security/parse-server-security).

If the app does not have accounts yet, start with the companion repo [user-auth-starter](https://github.com/templates-back4app/user-auth-starter).

## License

MIT

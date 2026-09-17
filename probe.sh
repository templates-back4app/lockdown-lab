#!/usr/bin/env bash
# Stack: bash + curl | File: probe.sh
# Twelve requests against the Note class from four identities, printed as a table of HTTP status + Parse error code.
# Run it before and after each lock and keep the tables — that is the whole argument of the post.
# usage: set -a; . ./.env; set +a; ./probe.sh
set -uo pipefail
BASE="${BASE:-https://parseapi.back4app.com}"
JS=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-JavaScript-Key: $JS_KEY" -H "Content-Type: application/json")
MK=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-Master-Key: $MASTER_KEY" -H "Content-Type: application/json")

login() { curl -s "${JS[@]}" -H "X-Parse-Revocable-Session: 1" -X POST "$BASE/login" -d "{\"username\":\"$1\",\"password\":\"$2\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("sessionToken",""))'; }
TA=$(login ana "ana-pass-2026"); TB=$(login bob "bob-pass-2026")
[ -n "$TA" ] && [ -n "$TB" ] || { echo "users ana/bob missing — run ./seed.sh first" >&2; exit 1; }

# a note of ana's, created with the master key so it exists whatever the locks are; the hook (once deployed) stamps the ACL
fresh_note() { curl -s "${MK[@]}" -X POST "$BASE/classes/Note" -d "{\"text\":\"ana's private note\",\"owner\":{\"__type\":\"Pointer\",\"className\":\"_User\",\"objectId\":\"$ANA_ID\"}}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["objectId"])'; }
ANA_NOTE=$(fresh_note)

code() {  # code <label> <curl args…> → prints "status / parse code   server"
  local label=$1; shift
  local out; out=$(curl -s -D /tmp/probe-headers.$$ -w '\n%{http_code}' "$@"); local status=${out##*$'\n'}; local body=${out%$'\n'*}
  local pcode; pcode=$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("code",""))
except Exception: print("")' <<<"$body")
  local srv; srv=$(awk 'tolower($1)=="x-backend-server:"{print $2}' /tmp/probe-headers.$$ | tr -d '\r'); rm -f /tmp/probe-headers.$$
  printf '%-44s %s%-6s %s\n' "$label" "$status" "${pcode:+ / $pcode}" "${srv:+← $srv}"
}
echo "identity → request                              HTTP / Parse code"
code "anonymous (JS key)  → list notes"            "${JS[@]}" "$BASE/classes/Note"
code "anonymous (JS key)  → create note"           "${JS[@]}" -X POST "$BASE/classes/Note" -d '{"text":"drive-by"}'
code "ana (session token) → list notes"            "${JS[@]}" -H "X-Parse-Session-Token: $TA" "$BASE/classes/Note"
code "ana (session token) → read her note"         "${JS[@]}" -H "X-Parse-Session-Token: $TA" "$BASE/classes/Note/$ANA_NOTE"
code "ana (session token) → update her note"       "${JS[@]}" -H "X-Parse-Session-Token: $TA" -X PUT "$BASE/classes/Note/$ANA_NOTE" -d '{"text":"edited by ana"}'
code "ana (session token) → create note"           "${JS[@]}" -H "X-Parse-Session-Token: $TA" -X POST "$BASE/classes/Note" -d '{"text":"another of ana"}'
code "bob (session token) → read ana's note"       "${JS[@]}" -H "X-Parse-Session-Token: $TB" "$BASE/classes/Note/$ANA_NOTE"
code "bob (session token) → update ana's note"     "${JS[@]}" -H "X-Parse-Session-Token: $TB" -X PUT "$BASE/classes/Note/$ANA_NOTE" -d '{"text":"edited by bob"}'
code "master key          → read ana's note"       "${MK[@]}" "$BASE/classes/Note/$ANA_NOTE"
# destructive probes last, each against a fresh copy of the note
N=$(fresh_note); code "anonymous (JS key)  → delete ana's note"     "${JS[@]}" -X DELETE "$BASE/classes/Note/$N"
N=$(fresh_note); code "bob (session token) → delete ana's note"     "${JS[@]}" -H "X-Parse-Session-Token: $TB" -X DELETE "$BASE/classes/Note/$N"
N=$(fresh_note); code "master key          → delete ana's note"     "${MK[@]}" -X DELETE "$BASE/classes/Note/$N"

#!/usr/bin/env bash
# Stack: bash + curl | File: seed.sh
# Creates the two users the probes log in as (ana, bob) and a "moderator" role containing bob. Idempotent enough to re-run.
# usage: set -a; . ./.env; set +a; ./seed.sh
set -euo pipefail
BASE="${BASE:-https://parseapi.back4app.com}"
JS=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-JavaScript-Key: $JS_KEY" -H "Content-Type: application/json")
MK=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-Master-Key: $MASTER_KEY" -H "Content-Type: application/json")

mkuser() {  # mkuser <name> <password> → objectId (creates or looks up)
  local id; id=$(curl -s "${JS[@]}" -X POST "$BASE/users" -d "{\"username\":\"$1\",\"password\":\"$2\",\"email\":\"$1@example.com\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("objectId",""))')
  [ -n "$id" ] || id=$(curl -s -G "${MK[@]}" "$BASE/users" --data-urlencode "where={\"username\":\"$1\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["results"][0]["objectId"])')
  echo "$id"
}
ANA_ID=$(mkuser ana "ana-pass-2026"); BOB_ID=$(mkuser bob "bob-pass-2026")
# role "moderator" with bob in it (roles can only be created with the master key or an ACL that allows it)
ROLE=$(curl -s -G "${MK[@]}" "$BASE/roles" --data-urlencode 'where={"name":"moderator"}' | python3 -c 'import json,sys; r=json.load(sys.stdin)["results"]; print(r[0]["objectId"] if r else "")')
if [ -z "$ROLE" ]; then
  ROLE=$(curl -s "${MK[@]}" -X POST "$BASE/roles" -d "{\"name\":\"moderator\",\"ACL\":{\"*\":{\"read\":true}},\"users\":{\"__op\":\"AddRelation\",\"objects\":[{\"__type\":\"Pointer\",\"className\":\"_User\",\"objectId\":\"$BOB_ID\"}]}}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["objectId"])')
fi
echo "ANA_ID=$ANA_ID"; echo "BOB_ID=$BOB_ID"; echo "ROLE_ID=$ROLE"
grep -q '^ANA_ID=' .env 2>/dev/null || printf 'ANA_ID=%s\nBOB_ID=%s\n' "$ANA_ID" "$BOB_ID" >> .env

#!/usr/bin/env bash
# Stack: bash + curl (schema API, master key) | File: lockdown.sh
# Lock 1 of 4, as a script: the Class-Level Permissions of Note. The dashboard (Database → Note → Security) sets the same thing by hand.
#   ./lockdown.sh open           → everyone can do everything (the default of a class created by a client write)
#   ./lockdown.sh authenticated  → only logged-in users can read/create; find and update/delete follow the ACL
#   ./lockdown.sh show           → print the current CLP
set -euo pipefail
BASE="${BASE:-https://parseapi.back4app.com}"
MK=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-Master-Key: $MASTER_KEY" -H "Content-Type: application/json")
case "${1:-show}" in
  open)          CLP='{"find":{"*":true},"get":{"*":true},"create":{"*":true},"update":{"*":true},"delete":{"*":true},"addField":{"*":true}}';;
  authenticated) CLP='{"find":{"requiresAuthentication":true},"get":{"requiresAuthentication":true},"create":{"requiresAuthentication":true},"update":{"requiresAuthentication":true},"delete":{"requiresAuthentication":true},"addField":{}}';;
  show)          curl -s "${MK[@]}" "$BASE/schemas/Note" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin).get("classLevelPermissions"), indent=1))'; exit 0;;
  *) echo "usage: $0 open|authenticated|show" >&2; exit 1;;
esac
curl -s "${MK[@]}" -X PUT "$BASE/schemas/Note" -d "{\"classLevelPermissions\":$CLP}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("CLP now:", json.dumps(d.get("classLevelPermissions", d)))'

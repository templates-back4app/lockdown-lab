#!/usr/bin/env bash
# Stack: bash + curl (master key) | File: migrate-acl.sh
# The hook protects rows created after it was deployed. Rows created before keep whatever ACL they had (Public Read + Write).
# This walks every Note with the master key: rows with an owner get an owner-only ACL, ownerless rows (anonymous drive-bys) are deleted.
set -euo pipefail
BASE="${BASE:-https://parseapi.back4app.com}"
MK=(-H "X-Parse-Application-Id: $APP_ID" -H "X-Parse-Master-Key: $MASTER_KEY" -H "Content-Type: application/json")
curl -s -G "${MK[@]}" "$BASE/classes/Note" --data-urlencode 'limit=1000' --data-urlencode 'keys=owner,ACL' | python3 -c '
import json,sys
fixed=deleted=kept=0
for n in json.load(sys.stdin)["results"]:
    acl=n.get("ACL",{}); owner=(n.get("owner") or {}).get("objectId")
    if owner and acl.get(owner)=={"read":True,"write":True} and len(acl)==1: kept+=1; continue
    print(("fix "+owner if owner else "del -")+" "+n["objectId"])
' | while read -r action owner id; do
  if [ "$action" = fix ]; then curl -s -o /dev/null "${MK[@]}" -X PUT "$BASE/classes/Note/$id" -d "{\"ACL\":{\"$owner\":{\"read\":true,\"write\":true}}}"; echo "fixed $id → owner $owner";
  else curl -s -o /dev/null "${MK[@]}" -X DELETE "$BASE/classes/Note/$id"; echo "deleted ownerless $id"; fi
done
echo "remaining rows: $(curl -s "${MK[@]}" "$BASE/classes/Note?count=1&limit=0" | python3 -c 'import json,sys; print(json.load(sys.stdin)["count"])')"

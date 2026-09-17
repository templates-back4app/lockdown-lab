// Stack: Node.js 22.x | Parse Server 8.x | File: cloud/main.js
// Lock 2 of 4: every Note gets an ACL that only its owner can read or write. The client cannot forget to set it,
// because the client never sets it — the backend does, before the row exists.
Parse.Cloud.beforeSave("Note", (request) => {
  const note = request.object;
  if (!note.isNew()) return;                                   // ACL is decided once, at creation
  const owner = request.user ?? note.get("owner");             // request.user = whoever holds the session token
  if (!owner) throw new Parse.Error(Parse.Error.SESSION_MISSING, "log in to create a note.");
  const acl = new Parse.ACL(owner);                            // owner: read + write; everyone else: nothing
  note.setACL(acl);
  note.set("owner", owner);
});

// Lock 3 of 4: a role. Moderators can read everything through this function; nobody can through the class.
Parse.Cloud.define("moderatorList", async (request) => {
  if (!request.user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, "log in first.");
  const isMod = await new Parse.Query(Parse.Role).equalTo("name", "moderator").equalTo("users", request.user).first({ useMasterKey: true });
  if (!isMod) throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, "moderators only.");
  const notes = await new Parse.Query("Note").find({ useMasterKey: true });   // lock 4: the master key stays here
  return notes.map((n) => ({ id: n.id, text: n.get("text"), owner: n.get("owner")?.id }));
});

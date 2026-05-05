import { Client, Databases, Query } from "node-appwrite";

const BUILD_TAG = "20260505a";

function hash8(input) {
  let hash = 0x811c9dc5 >>> 0;
  const prime = 0x01000193;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, prime) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}

function memberDocId(clubId, userId) {
  return `cm_${hash8(clubId)}_${hash8(userId)}`;
}

function documentAttributes(doc) {
  if (!doc || typeof doc !== "object") {
    return {};
  }
  const base = doc.data && typeof doc.data === "object" ? doc.data : doc;
  const out = {};
  for (const [k, v] of Object.entries(base)) {
    if (!k.startsWith("$")) {
      out[k] = v;
    }
  }
  return out;
}

function documentId(doc) {
  const id = doc?.$id;
  return id != null ? String(id).trim() : "";
}

function roleFromDocument(doc) {
  const attrs = documentAttributes(doc);
  const raw = String(
    attrs.role ?? attrs.memberRole ?? attrs.member_role ?? "member",
  )
    .toLowerCase()
    .trim();
  return raw === "admin" ? "admin" : "member";
}

function isNotFoundError(err) {
  const c = err?.code;
  return c === 404 || c === "404";
}

async function findMembershipDoc(databases, databaseId, collectionId, clubId, userId) {
  const expectedId = memberDocId(clubId, userId);
  try {
    return await databases.getDocument(databaseId, collectionId, expectedId);
  } catch (err) {
    if (!isNotFoundError(err)) {
      throw err;
    }
  }

  for (const [cKey, uKey] of [
    ["clubId", "userId"],
    ["clubid", "userid"],
  ]) {
    try {
      const listed = await databases.listDocuments(databaseId, collectionId, [
        Query.equal(cKey, clubId),
        Query.equal(uKey, userId),
        Query.limit(1),
      ]);
      if (listed.documents.length > 0) {
        return listed.documents[0];
      }
    } catch (_) {}
  }
  return null;
}

async function isClubCreator(databases, databaseId, clubId, callerUserId) {
  const clubsCollectionId = (process.env.APPWRITE_CLUBS_COLLECTION_ID ?? "clubs").trim();
  if (!clubsCollectionId || !callerUserId) {
    return false;
  }
  try {
    const clubDoc = await databases.getDocument(databaseId, clubsCollectionId, clubId);
    const attrs = documentAttributes(clubDoc);
    const creatorId = String(attrs.creatorId ?? attrs.creator_id ?? "").trim();
    return creatorId === callerUserId;
  } catch (_) {
    return false;
  }
}

function formatError(e) {
  if (e == null) {
    return { message: "Unknown error", code: undefined, type: undefined };
  }
  if (typeof e === "string") {
    return { message: e, code: undefined, type: undefined };
  }
  if (typeof e !== "object") {
    return { message: String(e), code: undefined, type: undefined };
  }
  const code = e.code;
  const type = e.type ?? "";
  const msg = e.message != null ? String(e.message).trim() : "";
  return {
    message: msg || String(e),
    code: code ?? undefined,
    type: type || undefined,
  };
}

export default async ({ req, res, log, error }) => {
  const json = (obj, status = 200) => res.json({ ...obj, build: BUILD_TAG }, status);

  const endpoint = process.env.APPWRITE_ENDPOINT ?? "";
  const projectId = process.env.APPWRITE_PROJECT_ID ?? "";
  const apiKey = process.env.APPWRITE_API_KEY ?? "";
  const databaseId = process.env.APPWRITE_DATABASE_ID ?? "";
  const collectionId = process.env.APPWRITE_CLUB_MEMBERS_COLLECTION_ID ?? "";

  if (!endpoint || !projectId || !apiKey || !databaseId || !collectionId) {
    error("Missing required environment variables");
    return json({ ok: false, message: "Server misconfiguration" }, 500);
  }

  const callerUserId = String(
    req.headers["x-appwrite-user-id"] ?? req.headers["x-appwrite-userid"] ?? "",
  ).trim();
  if (!callerUserId) {
    return json({ ok: false, message: "Unauthorized" }, 401);
  }

  let body = {};
  try {
    const raw = req.body;
    body =
      typeof raw === "string" && raw.length > 0
        ? JSON.parse(raw)
        : raw && typeof raw === "object"
          ? raw
          : {};
  } catch {
    return json({ ok: false, message: "Invalid JSON body" }, 400);
  }

  const clubId = String(body.clubId ?? body.club_id ?? "").trim();
  const targetUserId = String(body.targetUserId ?? body.target_user_id ?? "").trim();
  if (!clubId || !targetUserId) {
    return json({ ok: false, message: "clubId and targetUserId are required" }, 400);
  }
  if (targetUserId === callerUserId) {
    return json({ ok: false, message: "Cannot remove yourself with this endpoint" }, 400);
  }

  const client = new Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(apiKey);
  const databases = new Databases(client);

  try {
    const callerDoc = await findMembershipDoc(
      databases,
      databaseId,
      collectionId,
      clubId,
      callerUserId,
    );
    const callerIsAdminMember =
      callerDoc != null && roleFromDocument(callerDoc) === "admin";
    const callerIsCreator = await isClubCreator(
      databases,
      databaseId,
      clubId,
      callerUserId,
    );
    if (!callerIsAdminMember && !callerIsCreator) {
      return json({ ok: false, message: "Only club admins can remove members" }, 403);
    }

    const targetDoc = await findMembershipDoc(
      databases,
      databaseId,
      collectionId,
      clubId,
      targetUserId,
    );
    if (!targetDoc) {
      return json({ ok: true, message: "Target user is not a member" });
    }

    const targetIsAdmin = roleFromDocument(targetDoc) === "admin";
    if (targetIsAdmin && !callerIsCreator) {
      return json(
        { ok: false, message: "Only the club creator can remove an admin member" },
        403,
      );
    }

    const docId = documentId(targetDoc);
    if (!docId) {
      return json({ ok: false, message: "Could not resolve membership document id" }, 500);
    }

    await databases.deleteDocument(databaseId, collectionId, docId);
    log(`remove_club_member: removed user=${targetUserId} club=${clubId} doc=${docId}`);
    return json({ ok: true, message: "Member removed" });
  } catch (e) {
    const { message, code, type } = formatError(e);
    error(`remove_club_member: ${message}${code != null ? ` [${code}]` : ""}`);
    return json({ ok: false, message, code, type }, 500);
  }
};

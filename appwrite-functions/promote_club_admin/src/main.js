import { Client, Databases, Query } from "node-appwrite";

/** Bump when you redeploy — if responses omit this, Appwrite is still running an old deployment. */
const BUILD_TAG = "20250326d";

/** Matches Flutter `ClubMemberRepository._hash8` (FNV-1a, UTF-16 code units). */
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

/** User-defined fields only (flat API or nested under `data`). */
function documentAttributes(doc) {
  if (!doc || typeof doc !== "object") {
    return {};
  }
  const base =
    doc.data && typeof doc.data === "object" ? doc.data : doc;
  const out = {};
  for (const [k, v] of Object.entries(base)) {
    if (k.startsWith("$")) {
      continue;
    }
    out[k] = v;
  }
  return out;
}

function documentId(doc) {
  if (!doc || typeof doc !== "object") {
    return "";
  }
  const id = doc.$id;
  return id != null ? String(id).trim() : "";
}

function roleFromAttrs(attrs) {
  const raw = String(
    attrs.role ?? attrs.memberRole ?? attrs.member_role ?? "member",
  )
    .toLowerCase()
    .trim();
  return raw === "admin" ? "admin" : "member";
}

function roleFromDocument(doc) {
  return roleFromAttrs(documentAttributes(doc));
}

/** Match the collection attribute name and optional enum value (set CLUB_MEMBER_ADMIN_VALUE if your enum uses e.g. Admin). */
function rolePatchForAdmin(doc) {
  const attrs = documentAttributes(doc);
  const adminVal =
    (process.env.CLUB_MEMBER_ADMIN_VALUE ?? "admin").trim() || "admin";
  if (Object.prototype.hasOwnProperty.call(attrs, "role")) {
    return { role: adminVal };
  }
  if (Object.prototype.hasOwnProperty.call(attrs, "member_role")) {
    return { member_role: adminVal };
  }
  if (Object.prototype.hasOwnProperty.call(attrs, "memberRole")) {
    return { memberRole: adminVal };
  }
  return { role: adminVal };
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
  let responseStr = "";
  const r = e.response;
  if (r != null && r !== "") {
    if (typeof r === "object") {
      try {
        responseStr = JSON.stringify(r);
      } catch {
        responseStr = String(r);
      }
    } else {
      responseStr = String(r);
    }
  }
  const parts = [];
  if (msg) {
    parts.push(msg);
  }
  if (responseStr) {
    parts.push(responseStr);
  }
  if (type) {
    parts.push(type);
  }

  if (parts.length === 0) {
    const name = e.name != null ? String(e.name) : "Error";
    if (e instanceof Error && e.stack) {
      parts.push(
        `${name}: ${e.stack.split("\n").slice(0, 4).join(" → ")}`,
      );
    } else {
      try {
        const pick = {};
        for (const k of Object.keys(e)) {
          pick[k] = e[k];
        }
        parts.push(`${name} ${JSON.stringify(pick)}`);
      } catch {
        parts.push(`${name} ${Object.prototype.toString.call(e)}`);
      }
    }
  }

  return {
    message: parts.join(" | "),
    code: code ?? undefined,
    type: type || undefined,
  };
}

function isNotFoundError(err) {
  const c = err?.code;
  return c === 404 || c === "404";
}

/**
 * Resolves a membership row like the Flutter client: deterministic ID first,
 * then list by clubId+userId (camelCase or lowercase keys).
 */
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
    } catch (_) {
      // Wrong attribute keys or missing index — try next pair.
    }
  }
  return null;
}

/**
 * Club creator may promote even without a club_members row (legacy clubs / missing join row).
 * Set APPWRITE_CLUBS_COLLECTION_ID if your collection id is not `clubs`.
 */
async function isClubCreator(
  databases,
  databaseId,
  clubId,
  callerUserId,
) {
  const clubsCollectionId = (
    process.env.APPWRITE_CLUBS_COLLECTION_ID ?? "clubs"
  ).trim();
  if (!clubsCollectionId || !callerUserId) {
    return false;
  }
  try {
    const clubDoc = await databases.getDocument(
      databaseId,
      clubsCollectionId,
      clubId,
    );
    const attrs = documentAttributes(clubDoc);
    const creatorId = String(
      attrs.creatorId ?? attrs.creator_id ?? "",
    ).trim();
    return creatorId === callerUserId;
  } catch (_) {
    return false;
  }
}

export default async ({ req, res, log, error }) => {
  const json = (obj, status = 200) =>
    res.json({ ...obj, build: BUILD_TAG }, status);

  const endpoint = process.env.APPWRITE_ENDPOINT ?? "";
  const projectId = process.env.APPWRITE_PROJECT_ID ?? "";
  const apiKey = process.env.APPWRITE_API_KEY ?? "";
  const databaseId = process.env.APPWRITE_DATABASE_ID ?? "";
  const collectionId =
    process.env.APPWRITE_CLUB_MEMBERS_COLLECTION_ID ?? "";

  if (
    !endpoint ||
    !projectId ||
    !apiKey ||
    !databaseId ||
    !collectionId
  ) {
    error("Missing required environment variables");
    return json({ ok: false, message: "Server misconfiguration" }, 500);
  }

  const callerUserId = String(
    req.headers["x-appwrite-user-id"] ??
      req.headers["x-appwrite-userid"] ??
      "",
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
        : (raw && typeof raw === "object" ? raw : {});
  } catch (e) {
    return json({ ok: false, message: "Invalid JSON body" }, 400);
  }

  const clubId = String(body.clubId ?? body.club_id ?? "").trim();
  const targetUserId = String(
    body.targetUserId ?? body.target_user_id ?? "",
  ).trim();

  if (!clubId || !targetUserId) {
    return json(
      { ok: false, message: "clubId and targetUserId are required" },
      400,
    );
  }

  if (targetUserId === callerUserId) {
    return json({ ok: false, message: "Cannot promote yourself" }, 400);
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
      if (callerDoc == null) {
        return json(
          {
            ok: false,
            message:
              "Caller is not a member of this club (and is not the club creator on the club document)",
          },
          403,
        );
      }
      return json(
        { ok: false, message: "Only club admins can promote members" },
        403,
      );
    }

    const targetDoc = await findMembershipDoc(
      databases,
      databaseId,
      collectionId,
      clubId,
      targetUserId,
    );

    if (!targetDoc) {
      return json(
        { ok: false, message: "Target user is not a member of this club" },
        404,
      );
    }

    if (roleFromDocument(targetDoc) === "admin") {
      return json({ ok: true, message: "User is already an admin" });
    }

    const docId = documentId(targetDoc);
    if (!docId) {
      return json(
        { ok: false, message: "Could not read membership document id" },
        500,
      );
    }
    const patch = rolePatchForAdmin(targetDoc);
    await databases.updateDocument(databaseId, collectionId, docId, patch);

    log(`Promoted ${targetUserId} to admin in club ${clubId} (doc ${docId})`);
    return json({ ok: true, message: "Promoted to admin" });
  } catch (e) {
    const { message, code, type } = formatError(e);
    error(`promote_club_admin: ${message}${code != null ? ` [${code}]` : ""}`);
    return json(
      {
        ok: false,
        message,
        code,
        type,
      },
      500,
    );
  }
};

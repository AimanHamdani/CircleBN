import { Client, Databases, Query } from "node-appwrite";

/** Bump when you redeploy — if responses omit this, Appwrite is still running an old deployment. */
const BUILD_TAG = "20260411a";

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
    } catch (_) {
      // Wrong attribute keys or missing index — try next pair.
    }
  }
  return null;
}

async function isClubCreator(databases, databaseId, clubId, callerUserId) {
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

function formatError(e) {
  if (e == null) {
    return { message: "Unknown error", code: undefined };
  }
  if (typeof e === "string") {
    return { message: e, code: undefined };
  }
  if (typeof e !== "object") {
    return { message: String(e), code: undefined };
  }
  const code = e.code;
  const msg = e.message != null ? String(e.message).trim() : "";
  return {
    message: msg || String(e),
    code: code ?? undefined,
  };
}

/**
 * Confirms the authenticated user may attach [clubId] to an event
 * (club admin or club document creator). Call from the app before create/update
 * when the club association changes; omit when only editing other fields.
 */
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
  } catch {
    return json({ ok: false, message: "Invalid JSON body" }, 400);
  }

  const clubId = String(body.clubId ?? body.club_id ?? "").trim();

  if (!clubId) {
    return json({
      ok: true,
      message: "No club id — personal event (nothing to validate)",
    });
  }

  const client = new Client()
    .setEndpoint(endpoint)
    .setProject(projectId)
    .setKey(apiKey);

  const databases = new Databases(client);

  try {
    const memberDoc = await findMembershipDoc(
      databases,
      databaseId,
      collectionId,
      clubId,
      callerUserId,
    );

    const isAdmin = memberDoc != null && roleFromDocument(memberDoc) === "admin";
    const isCreator = await isClubCreator(
      databases,
      databaseId,
      clubId,
      callerUserId,
    );

    if (!isAdmin && !isCreator) {
      return json(
        {
          ok: false,
          message:
            "Only a club admin or the club creator can host events under this club",
        },
        403,
      );
    }

    log(`validate_event_club_host: ok user=${callerUserId} club=${clubId}`);
    return json({ ok: true, message: "Allowed" });
  } catch (e) {
    const { message, code } = formatError(e);
    error(`validate_event_club_host: ${message}${code != null ? ` [${code}]` : ""}`);
    return json({ ok: false, message }, 500);
  }
};

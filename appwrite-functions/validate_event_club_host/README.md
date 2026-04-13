# validate_event_club_host

Server-side check that the **signed-in user** may attach a `clubId` to an event (they must be a **club admin** on `club_members`, or the **creator** of the club document on `clubs`).

The Flutter app calls this **before** `createDocument` / `updateDocument` on the events collection when the club association **changes** (see `APPWRITE_VALIDATE_EVENT_CLUB_HOST_FUNCTION_ID`). If this function is not deployed, leave that env var empty and validation is skipped.

## Request

- **Method**: POST (Appwrite Functions execution)
- **Body (JSON)**:
  - `clubId` (string, optional): if empty or omitted, responds `{ ok: true }` (personal event).

## Response

- `{ "ok": true, "message": "...", "build": "..." }` on success
- `{ "ok": false, "message": "...", "build": "..." }` with HTTP 401 / 403 / 500 on failure

## Environment variables

Set the same variables as `promote_club_admin`:

| Variable | Purpose |
|----------|---------|
| `APPWRITE_ENDPOINT` | API endpoint, e.g. `https://cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | Project ID |
| `APPWRITE_API_KEY` | API key with permission to read `club_members` and `clubs` |
| `APPWRITE_DATABASE_ID` | Database ID |
| `APPWRITE_CLUB_MEMBERS_COLLECTION_ID` | Usually `club_members` |
| `APPWRITE_CLUBS_COLLECTION_ID` | Usually `clubs` |

## Deploy (Console)

1. **Functions** → **Create function** → Runtime **Node 18+**, entrypoint `src/main.js` (or build output).
2. Upload this folder (or connect Git).
3. Add the environment variables above.
4. **Settings** → **Execute access**: allow **any** (authenticated users execute via client SDK with session JWT).
5. Copy the **Function ID** into the Flutter/Dart define `APPWRITE_VALIDATE_EVENT_CLUB_HOST_FUNCTION_ID`.

## Deploy (CLI)

From this directory:

```bash
npm install
```

Create a deployment package per your Appwrite CLI version (`appwrite deploy function`), pointing `entrypoint` to `src/main.js`.

## Recommended: events collection permissions

Appwrite cannot express “only admins may set `clubId`” in the console alone. Use:

1. **This function** for validation when the app saves (optional but recommended).
2. **Collection permissions** on the **events** collection:
   - **Create**: `users` (any logged-in user can create an event document), or restrict with a custom role if you use teams.
   - **Read**: `any` or `users` depending on privacy.
   - **Update**: `document.security` so only the **creator** can update their event (e.g. `Permission.update(Role.user(creatorId))` if you set permissions in code), **or** `users` for a first version — tighten later.
   - **Delete**: same as update, creator-only.

If **Update** is open to all users, a malicious client could still PATCH `clubId`. **Tight update permissions** + this function (or a future “events proxy” function that writes with an API key) is the full fix.

### Tightening updates (optional)

- Prefer **Document security** so each event document grants **update** only to `User(creatorId)` from the client SDK.
- Keep using this function whenever `clubId` is added or changed so only club admins can link a club.

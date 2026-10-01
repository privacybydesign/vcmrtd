# The proofing service's app-facing API, and how far the app has drifted from it

Research for issue #207. It answers: what is the current contract between the app (`idem`) and
`identity-proofing-service`, and where does the app no longer match it?

**Sources and versions.**

- Server: `identity-proofing-service` at commit `d0b81ca` (2026-09-24). The Go code under
  `backend/` is treated as the source of truth. Where `docs/session-model.md`, `docs/api/openapi.yaml`,
  `README.md` or `docs/compliance.md` say something else, the code wins, and this note says so.
- App: this repo at `origin/master` `2c3d9c4`.

Server paths below are relative to the `identity-proofing-service` repo root. App paths are relative
to this repo's root. Line numbers refer to those two commits.

## TL;DR

- The app cannot talk to the current server at all. It calls `/api/proofing/app/{token}`, but every
  app route is now `/api/v1/app/...`. It also sends no `X-Device-Token`, and the server rejects
  every request without one: `401 device_unauthorized`.
- The session token is no longer in any QR or deep link. A device first redeems a short-lived,
  single-use **grant token** (`POST /api/v1/app/handover/{grant}/claim`). The response gives it the
  session token (for the path) and a device token (for the `X-Device-Token` header).
- The native deep link (which is also the native QR) is `vcmrtd://verify?handover=<grant>&api=<base>`.
  The app parses `token=`. The `https://<host>/s/{token}` and `/api/v1/s/{token}` QR shapes the app
  also accepts no longer exist. That route was removed in server commit `7409bb7`.
- For a session governed by a flow definition, `POST .../result` is refused
  (`409 flow_steps_required`). Evidence goes in per step (`/steps/document_capture`, `/steps/nfc`,
  `/steps/selfie`), and the session finishes only through `POST .../submit`. The app knows only
  `/result`.
- Sessions live 10 minutes by default and at most 15 minutes from creation, whatever `ttlSeconds`
  asks for. Opening one extends it to at most now + 10 minutes, still under that cap. Grants last
  2 minutes (handover) or 10 minutes (claim).

## 1. Route map (app-facing)

All routes are registered in `backend/internal/api/api.go:505-540`. None of them needs the
interactive login, because `/api/v1/app/` is login-exempt (`api.go:590-600`).

| Method | Path | Handler | Auth |
| --- | --- | --- | --- |
| `GET` | `/api/v1/app/{token}` | `handleAppSession` (`sessions.go:2825`) | `X-Device-Token` |
| `GET` | `/api/v1/app/{token}/events?since=<changeKey>` | `handleAppSessionEvents` (`sessions.go:2915`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/result` | `handleAppSessionResult` (`sessions.go:3016`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/steps/document_capture` | `handleSubmitDocumentStep` (`steps.go:965`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/steps/nfc` | `handleSubmitNFCStep` (`steps.go:625`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/steps/selfie` | `handleSubmitSelfieStep` (`steps.go:265`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/steps/selfie/preview` | `handleSelfieStepPreview` (`steps.go:389`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/steps/{step}/start` | `handleStartStep` (`steps.go:842`) | `X-Device-Token` |
| `GET` | `/api/v1/app/{token}/steps/{step}/result` | `handleStepResult` (`steps.go:923`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/submit` | `handleSubmitSession` (`steps.go:1058`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/handover` | `handleMintHandover` (`device_access.go:394`) | `X-Device-Token` |
| `POST` | `/api/v1/app/{token}/device/state` | `handleDeviceState` (`device_access.go:590`) | `X-Device-Token` |
| `POST` | `/api/v1/app/handover/{handoverToken}/claim` | `handleClaimHandover` (`device_access.go:292`) | the grant token in the path |
| `POST` | `/api/v1/app/{token}/claim` | `handleSessionTokenClaim` (`device_access.go:272`) | always `410 claim_token_required` |
| `POST`/`GET` | `/api/v1/app/{token}/yivi/...`, `/face` | `bound_login.go` | `biometric_bound_login` only; not for the app |
| `GET` | `/api/v1/qr?data=<payload>` | `handleQR` (`qr.go:14`) | none; renders any payload of 2048 bytes or less as a PNG |

## 2. Authorisation

There are three separate tokens. Only the device token authorises anything.

| Token | Format | Where it comes from | What it does |
| --- | --- | --- | --- |
| Session token | 64 hex chars, 256 bits (`session/session.go:488`) | The relying party's create response (`token`), and the claim response's `token` | Identifies the session in the `/api/v1/app/{token}` path. Looked up by `Store.Authenticate` (`session/store.go:216`). It authorises nothing by itself (`device_access.go:1-8`). |
| Grant token (claim or handover) | base64url, 256 bits (`session/access.go:366`) | The create response's `claims.{web,native}`, `POST /api/v1/sessions/{id}/claim-tokens`, or `POST .../handover` | Single use. Redeemed with `POST /api/v1/app/handover/{grant}/claim`. Stored only as a SHA-256 hash. |
| Device token | base64url, 256 bits | The claim response's `deviceToken` | Sent as `X-Device-Token` on every `/api/v1/app/{token}/...` request (`device_access.go:39`, `:190-206`) |

**Slots.** Each `nfc_passport` session has two slots, `web` and `native`. Each slot holds at most one
device (`session/access.go:20-21`). `Access.Authorize` (`session/access.go:218-234`) maps a device
token to its slot:

- empty or unknown token: `401 device_unauthorized`
- token revoked by a handover: `403 device_handed_over`

There is no fallback that lets the session token alone get through (`device_access.go:198-203`).
`biometric_bound_login` sessions have no slots and stay session-token-only (`device_access.go:195`).

**Write re-check.** Every write re-checks the slot and the session state inside the store's locked
update (`checkAppWrite`, `device_access.go:212-219`; `stepWriteCheck`, `steps.go:92-108`). A device
that was handed away from, or a session that expired or finished, while a request was in flight,
stores nothing.

**Rate limit.** `POST .../result` and `POST /api/v1/app/handover/{grant}/claim` share the
`submitResultLimit` per-IP limiter: 20 requests per minute by default (`api.go:280-281`,
`sessions.go:3017`, `device_access.go:293`).

**Error body.** Errors look like `{"error": "<english text>", "code": "<machine code>"}`, with
`code` present for access and state errors (`device_access.go:82-111`). The codes are
`device_unauthorized` 401, `device_handed_over` 403, `device_already_claimed` 409,
`session_expired` 410, `session_complete` 409, `handover_invalid` 404, `handover_expired` 410,
`handover_used` 409, `claim_token_required` 410, `flow_steps_required` 409 and
`steps_incomplete` 409 (`device_access.go:41-56`).

## 3. Expiry

Defaults are in `api.go:264-273`. `cmd/server/main.go` overrides none of the values below.

| Setting | Default | Effect |
| --- | --- | --- |
| `SessionCreateTTL` | 10 min | Initial `expiresAt` (`sessions.go:2030`) |
| `ttlSeconds` (per request) | clamped to [1 min, 60 min] | ...then clamped again to `SessionMaxLifetime` (`sessions.go:2108-2113`) |
| `SessionMaxLifetime` | 15 min | Hard cap measured from `createdAt`. Nothing pushes `expiresAt` past it (`device_access.go:667-683`). |
| `SessionOpenTTL` | 10 min | The first open (`created` to `opened`, done by `GET /api/v1/app/{token}` or a claim) extends `expiresAt` to now + 10 min, capped (`device_access.go:653-662`) |
| `ClaimTokenTTL` | 10 min | Claim tokens, never past the session's `expiresAt` (`device_access.go:435-441`) |
| `HandoverTokenTTL` | 2 min | Handover tokens, never past the session's `expiresAt` |
| `DeviceStaleAfter` / `DeviceDisconnectGrace` | 45 s / 5 s | When a slot is reported `stale`. This never expires the session. |
| `SessionEventsWait` | 25 s | Long-poll timeout for `/events` |

Expiry is lazy. A session past `expiresAt` flips to `expired` the next time any read touches it
(`session/store.go:180-230`). After that:

- `POST .../result` gets `410` (`sessions.go:3037-3046`)
- step writes get `410 session_expired`
- claims get `410 session_expired`

**The docs disagree with the code here.** `docs/session-model.md:169` says `SessionOpenTTL` defaults
to 5 min, and `docs/session-model.md:193` says `SessionCreateTTL` defaults to 15 min. The code says
10 min for both. `docs/session-model.md:458-460` (the 15-minute hard cap) matches the code.

## 4. Getting onto a session: claim, deep link, QR

### 4.1 Grant link formats (server)

`grantResponse` (`device_access.go:446-456`) builds every grant link:

| Slot | `qr` field | Shape |
| --- | --- | --- |
| `native` | same as `deepLink` | `vcmrtd://verify?handover=<grant>&api=<apiBase>` |
| `web` | same as `url` | `<WebAppURL>?handover=<grant>` |

- `<apiBase>` is `-public-base-url`/`PUBLIC_BASE_URL` when set. Otherwise it is
  `scheme://Host` taken from the request (`sessions.go:2335-2344`).
- `WebAppURL` falls back to `<apiBase>/api/v1/db-test/proofing` (`device_access.go:562-567`).
  `cmd/server/main.go` never sets it, so in practice that fallback is the web URL.
- Neither link carries the session token.

The native QR is therefore the custom-scheme URL itself. No https URL is defined for the native
slot.

**The route the app expects was removed.** `GET /api/v1/s/{token}` was removed in server commit
`7409bb7` ("made admin page better…", which deleted `proofing_flow.go`). Only a stale login-exempt
prefix is left (`api.go:581`, `:597`). The following still describe the old shapes and are wrong
against the code:

- `docs/session-model.md:277-281` (`deepLink` is `vcmrtd://verify?token=...`, `qr` is
  `https://<host>/api/v1/s/{token}`)
- `docs/session-model.md:282-291`, a 2026-09-11 check against an older checkout of this app that
  pointed at `example/lib/...`
- `docs/session-model.md:331`, which says `nativeHandoff` is `{deepLink, qr}`. In the code it is
  `{role, claimed}`, and the table at `docs/session-model.md:169` is correct.
- `README.md:274` and `:342`, and `docs/compliance.md:458`

`docs/session-model.md:162` also still says the app routes are "authenticated by the token *in the
path only*". The code requires `X-Device-Token`, which matches `docs/session-model.md:363-372`.

### 4.2 Where the native grant comes from

| Source | Who calls it |
| --- | --- |
| `POST /api/v1/sessions` response: `claims.native` and the top-level `deepLink`/`qr` (`sessions.go:875-890`, `:2152`) | the relying party |
| `POST /api/v1/sessions/{id}/claim-tokens {role?}` (`device_access.go:531`) | the relying party, for empty slots only |
| `POST /api/v1/app/{token}/handover {role?}` (`device_access.go:394`) | a device that already holds a slot (for example the web page, minting the native QR when `nativeHandoff` is present) |

### 4.3 Claim

```
POST {api}/api/v1/app/handover/{grant}/claim      (no body, no headers needed)
200 → {
  "token":       "<session token, for the path>",
  "deviceToken": "<send as X-Device-Token from now on>",
  "role":        "native" | "web",
  "session":     <appSessionView, see §5>
}
```

Struct: `claimResponse`, `device_access.go:263-268`. Handler: `device_access.go:292-346`.

- Redeeming moves the grant's slot to this device. Any previous holder is revoked and gets `403` from
  then on.
- A claim on a `created` session also opens it. That means `opened` status and the open-TTL
  extension (`device_access.go:321`).
- Failures: `404 handover_invalid`, `410 handover_expired`, `409 handover_used`,
  `410 session_expired`, `409 session_complete`.

### 4.4 Handover (moving a slot to another device)

```
POST {api}/api/v1/app/{token}/handover     X-Device-Token: <caller's>
body (optional): {"role": "web" | "native"}       default: caller's own slot
200 → {"handoverToken", "role", "expiresAt", "qr", "url"?, "deepLink"?}
```

Structs: `mintHandoverRequest`/`handoverResponse`, `device_access.go:359-374`.

- Each slot has one pending grant. Minting a new one replaces only that slot's grant.
- The receiving device redeems it with the claim call above.
- `POST .../device/state {"state": "active"}` from the slot's current holder cancels that slot's
  unused grant (`device_access.go:621-624`).
- The session id, token, steps and expiry never change on a handover.

## 5. Session fetch: `GET /api/v1/app/{token}` → `appSessionView`

Struct: `sessions.go:896-998`. Built by `buildAppSessionView`, `sessions.go:2856-2912`.

- The same view comes back from a claim (`.session`), from `POST .../device/state`, and from
  `GET .../events` once the `changeKey` changes or the 25 s wait times out.
- The first fetch of a `created` session moves it to `opened` and extends `expiresAt`
  (`sessions.go:2830-2846`).

| JSON field | Type | Presence | Meaning |
| --- | --- | --- | --- |
| `id` | string | always | Session id |
| `method` | `"nfc_passport"` \| `"biometric_bound_login"` | always | |
| `relyingParty` | string | always | The tenant's display name. Never its id or key. |
| `status` | `created` \| `opened` \| `in_progress` \| `needs_review` \| `approved` \| `rejected` \| `expired` \| `cancelled` | always | `session/session.go:58-65` |
| `language` | `"en"` \| `"nl"` | always (tagged `omitempty` but always set) | The session's language if it is a shipped one, else `Accept-Language`, else `en` (`i18n.go:43`) |
| `requestedAttributes` | string[] | omitted when empty | Attribute keys: `dg1`, `dg11`, `dg2`, `face_image`, `chip_checks`, `biometrics`, `selfie`, `document_image` (`sessions.go:1272-1281`). Empty means unrestricted (`sessions.go:1287`). With a flow, it is derived from `steps` (`sessions.go:622-646`). |
| `steps` | string[] | omitted when no flow | The flow order, from `document_capture`, `nfc_read`, `face_verification`, `selfie`, `liveness` and `face_match` (`flow/flow.go:52-64`) |
| `selfieLocation` | `"browser"` \| `"native"` | always | Which client runs the face step. `"browser"` when there is no flow. |
| `expiresAt` | RFC 3339 time | always | |
| `aaChallenge` | hex string (8 bytes) | omitted if empty | Active Authentication challenge. The chip must sign exactly this value. |
| `referencePhoto` | `{imageBase64, mimeType}` | only if the relying party supplied one | Face-match reference for flows that have `face_match` but no `nfc_read` |
| `completedSteps` | string[] | omitted when empty | Steps that have evidence |
| `nativeHandoff` | `{role: "native", claimed: bool}` | when native work is pending (`sessions.go:2986-3000`) | No link. The web side mints the QR itself. |
| `resetCount` | int | always | When it changes, drop local progress and restart from the first step |
| `changeKey` | opaque string | always | Pass back as `?since=` to `/events` (`sessions.go:2956-2970`) |
| `flowId`, `flowVersion` | string, int | omitted when no flow | |
| `currentStep` | string \| null | omitted when no flow. `""` once not active. | The step to resume at. The server decides it. |
| `chipAccess` | `{documentType, documentNumber, countryCode?, dateOfBirth?, dateOfExpiry?, version?, randomData?, configuration?}` | only while `currentStep == "nfc_read"` and an MRZ step was stored | Lets a device that took over read the chip without rescanning the MRZ (`session/session.go:319-328`) |
| `faceReference` | `{imageBase64, mimeType}` | only while the face step is current and `selfieLocation == "native"` | DG2 or the relying party's reference photo |
| `stepResults` | map step → `{step, completed, completedAt?, summary?}` | always (empty `{}` without a flow) | Verdicts only (`device_access.go:745-790`) |
| `lifecycle` | `ACTIVE` \| `COMPLETE` \| `EXPIRED` \| `CANCELLED` | always | `device_access.go:813-823` |
| `readyToSubmit` | bool | omitted when false | Every step is done. The user must call `POST .../submit`. |
| `device` | `{authorized, role?, claimed, state?, stale?, claimedAt?, lastActiveAt?}` | always | The caller's own slot (`device_access.go:686-703`) |
| `devices` | `{"web": deviceView, "native": deviceView}` | always | Both slots |

## 6. Result submission: `POST /api/v1/app/{token}/result`

The handler is `sessions.go:3016-3202`. It is the single-shot path, **only for sessions without a
resolved flow**. A session with a flow gets `409 flow_steps_required` (`sessions.go:3052-3061`).

A session has no flow when either:

- the server has no flow store configured, or
- the session's `flow` name did not match a stored flow when the session was created
  (`sessions.go:602-614`)

The body is `appResultRequest` (`sessions.go:1012-1032`):

| Field | Type | Notes |
| --- | --- | --- |
| `status` | `approved` \| `rejected` \| `needs_review` \| `cancelled` | Required. Anything else is `400` (`sessions.go:3066-3070`). It is only a claim: the server's own chip verdict forces `rejected` (`DOC_TAMPERED`/`CHIP_CLONE_DETECTED`), and so does a flow-policy violation (`sessions.go:3120-3136`). |
| `errorCode` | string | optional |
| `document` | `documentInfo` (`sessions.go:1039-1066`) | `type`, `number`, `issuingState`, `nationality`, `firstName`, `lastName`, `displayName`, `sex`, `dateOfBirth` (YYYY-MM-DD), `dateOfExpiry` (YYYY-MM-DD), `personalNumber`, `placeOfBirth`, and `validity` (`documentNumberCheckDigitValid`, `dateOfBirthCheckDigitValid`, `dateOfExpiryCheckDigitValid`, `compositeCheckDigitValid`, `notExpired`, all bool, `sessions.go:1068-1080`) |
| `photo` | `{imageBase64, mimeType}` | DG2 face image |
| `selfie` | `{imageBase64, mimeType}` | When present and no selfie step exists yet, the server **recomputes** liveness and the face match from this image. That replaces the client's `biometrics` (`sessions.go:3085-3097`). |
| `documentImage` | `{imageBase64, mimeType, bsnRegion?: {x, y, w, h}}` | VIZ capture (`sessions.go:1106-1115`) |
| `chipChecks` | object | Accepted for wire compatibility. Never trusted or stored. |
| `mrtdEvidence` | `{efSod, dataGroups: {"DG1": hex, ...}, documentType?: "icao" \| "eu_driving_licence", aaKeyDataGroup?, nonce?, aaSignature?}` | All hex (`sessions.go:1117-1149`). `aaKeyDataGroup` defaults to `DG15` on ICAO when DG15 is present (`sessions.go:1179-1190`). The nonce must equal `aaChallenge`. Optional on `/result`, but without it there are no chip checks. Invalid evidence is `400`. |
| `biometrics` | `{faceMatchScore?, faceVerified?, livenessResult?, livenessScore?, engine?, ...}` | `sessions.go:1238-1262`. Self-reported. It is overridden when `selfie` is sent. |
| `device` | `{appVersion?, devicePlatform?}` | Not gated by attributes |

**Response** (`200`): the relying-party `sessionView` (`sessions.go:806-840`, `:3201`). It holds:

- `id`, `method`, `status`, `tenantReference`, `errorCode`
- `result`, the full attribute-filtered result
- the timestamps and `devices`

Error responses:

- `409` (`replay`) or `410` (`expired`) for an already finished session
- `429` when rate-limited
- `401`/`403` for device errors

Idempotency: `Idempotency-Key` is honoured with Postgres (`sessions.go:3025`).

## 7. Step endpoints (sessions with a flow)

Package doc: `steps.go:1-31`. All step endpoints need `X-Device-Token`. They all return `409` "use
POST .../result instead" for a session without a resolved flow (`steps.go:76-79`).

A step's evidence is never replaced. A repeat returns `200` with the current state and
`alreadyRecorded: true` (`steps.go:129-149`). The one exception is document evidence: a chip-backed
document from `/steps/nfc` supersedes an MRZ-only one.

**Step response** (`stepResponse`, `steps.go:198-211`):
`{status, completedSteps, currentStep?, lifecycle, errorCode?, readyToSubmit?, alreadyRecorded?}`.

| Endpoint | Body | Response | Notes |
| --- | --- | --- | --- |
| `POST .../steps/{step}/start` | none | step response | `step` is `document_capture`, `nfc_read` or any face-step name. Moves the session to `in_progress` and writes the per-step audit row. Idempotent. Works without a flow too (`steps.go:814-864`). |
| `POST .../steps/document_capture` | `{document: documentInfo, chipAccess?: ChipAccessKey}` | step response | `document.number` is required. `chipAccess.documentType` must be `passport`, `identity_card` or `drivers_license` (`steps.go:937-1011`). The BSN policy is applied before the document is stored. |
| `POST .../steps/nfc` | `{photo?, document?, mrtdEvidence (required), device?}` | step response | `steps.go:604-715`. `mrtdEvidence` is verified exactly as on `/result`. It also fulfils `document_capture` if the flow has that step and no document is stored yet. In a flow with a native face step, send `photo` (DG2) too, so `faceReference` can be served. |
| `POST .../steps/selfie` | `{image (base64, required), mimeType?, frames?: string[]}` | step response + `biometrics` | `steps.go:233-336`. The server computes liveness (an anti-spoof model, or a frame-distinctness fallback) and, when the flow needs it, the face match against DG2 or `referencePhoto`. `409` if the reference is not there yet. Fulfils every face step at once. Called by whichever client `selfieLocation` names. |
| `POST .../steps/selfie/preview` | one frame | face-detection guidance | Stores nothing. Meant for the browser camera UI. |
| `GET .../steps/{step}/result` | — | `{step, completed, completedAt?, summary?}` + step response | `steps.go:900-932` |
| `POST .../submit` | none | step response | Only allowed when every step has evidence (`409 steps_incomplete` otherwise). The server decides the outcome (`finishSession`, `steps.go:1099`), with the same authenticity and flow checks as `/result`. A repeat returns `alreadyRecorded`. |

**Native sequence the server expects** for a flow such as `[document_capture, nfc_read,
face_verification]` with `selfieLocation: "native"`:

1. Claim the grant and get the token and device token.
2. `GET /api/v1/app/{token}`.
3. `POST /steps/document_capture/start`, then scan the MRZ.
4. Optionally, `POST /steps/document_capture`.
5. `POST /steps/nfc_read/start`, then read the chip, signing `aaChallenge`.
6. `POST /steps/nfc`.
7. `POST /steps/face_verification/start`, then `POST /steps/selfie`.
8. When `readyToSubmit` is true, `POST /submit`.

With `selfieLocation: "browser"`, the app stops after `/steps/nfc`. The web page runs the face step
and the submit.

Meanwhile:

- Long-poll `GET /events?since=<changeKey>`, and report `POST /device/state` on background/foreground
  changes.
- React to `resetCount` changes and to `403 device_handed_over`.

## 8. What the app does today

- **Parsing** (`idem/lib/services/proofing_session_client.dart:24-45`):
  - `vcmrtd://...?token=<t>&api=<a>`
  - or any `http(s)` URL whose second-to-last path segment is `s` (`.../s/{token}`), with the API
    base taken from scheme://host[:port]
- **Entry points:**
  - the in-app QR scanner (`idem/lib/routing.dart:56-81`)
  - a tapped `vcmrtd://` link, through the `proofing_deeplink` method channel
    (`idem/lib/main.dart:37-60`, `idem/lib/services/proofing_deeplink_channel.dart`)
  - the native plugins `idem/ios/Runner/ProofingDeepLinkPlugin.swift` and
    `idem/android/app/src/main/kotlin/foundation/privacybydesign/idem/ProofingDeepLinkPlugin.kt`.
    The `vcmrtd` scheme is registered in `idem/ios/Runner/Info.plist:43-50` and
    `idem/android/app/src/main/AndroidManifest.xml:45-52`. The plugins accept any `vcmrtd://` URL
    and forward it unchanged, so the transport works for the new link shape too.
- **Fetch:** `GET {api}/api/proofing/app/{token}` with no headers (`proofing_session_client.dart:454`).
  Of the response it reads only `id`, `relyingParty`, `requestedAttributes`, `expiresAt` and
  `aaChallenge` (`:73-79`). It aborts when `requestedAttributes` is empty (`routing.dart:70-74`,
  `main.dart:55`).
- **Consent screen**, then MRZ, NFC (using `aaChallenge` as the AA nonce, but only when the
  Active Authentication toggle is on, `idem/lib/widgets/pages/nfc_reading_screen.dart:421-434`),
  then the on-device face check.
- **Submit:** `POST {api}/api/proofing/app/{token}/result` with only `Content-Type`
  (`proofing_session_client.dart:483-499`).
  - Always `status: "approved"`, and `faceVerified: true` whenever any outcome exists
    (`idem/lib/widgets/pages/data_screen_widgets/proofing_result_submission.dart:33-51`).
  - Each part is filtered on the device by `requestedAttributes` (`proofing_session_client.dart:414-442`).
  - Anything other than a `200` is thrown as a generic exception, and the response body is ignored.

## 9. Every difference between the app and the server

"App" references are in this repo, and "Server" references are in `identity-proofing-service`.

| # | Area | App | Server (source of truth) | Effect |
| --- | --- | --- | --- | --- |
| 1 | Path prefix, fetch | `GET /api/proofing/app/{token}`: `idem/lib/services/proofing_session_client.dart:454` | `GET /api/v1/app/{token}`: `backend/internal/api/api.go:505` | No route matches. `/api/proofing/...` is also not login-exempt (`api.go:590-600`), so it hits the login gate. The fetch always fails. |
| 2 | Path prefix, result | `POST /api/proofing/app/{token}/result`: `proofing_session_client.dart:484` | `POST /api/v1/app/{token}/result`: `api.go:507` | Same as #1 |
| 3 | Device token | Never sent. No claim step exists: `proofing_session_client.dart:453-503` | Required on every app route. Without it: `401 device_unauthorized` (`device_access.go:190-206`, `session/access.go:218-221`) | Even with the right paths, every call fails |
| 4 | Claim | Not implemented | `POST /api/v1/app/handover/{grant}/claim` → `{token, deviceToken, role, session}`: `device_access.go:263-268`, `:292-346`. The old `POST .../claim` returns `410`: `device_access.go:272-275`. | The app has no way to get a device token or the session token |
| 5 | Deep-link query param | Reads `token=`: `proofing_session_client.dart:29-31` | Emits `handover=<grant>`: `device_access.go:449` | `parse` returns null and the link is silently dropped (`main.dart:51-52`). Even if it were read, the value is a grant to redeem, not a session token. |
| 6 | QR shape | Also accepts `https://<host>/s/{token}`: `proofing_session_client.dart:35-42`. The doc comment says `qr` is `https://{host}/s/{token}`: `:13-17` | The native `qr` equals the `vcmrtd://` deep link (`device_access.go:450`). The web `qr` is `<WebAppURL>?handover=` (`:452`, `:562-567`). `GET /api/v1/s/{token}` no longer exists: removed in `7409bb7`, with only a login-exempt leftover at `api.go:581`, `:597`. | The https branch matches nothing the server produces. A scanned web QR (`/api/v1/db-test/proofing?handover=`) is not recognised. |
| 7 | Stale contract comments | `ProofingDeepLinkPlugin.swift:4-10`, `ProofingDeepLinkPlugin.kt:14-20`, `proofing_deeplink_channel.dart:3-9` and `AndroidManifest.xml:45-46` cite `vcmrtd://verify?token=...` and a `deepLink()` in `sessions.go` | No `deepLink()` function exists. The link is built in `grantResponse`, `device_access.go:446-456`. | Documentation only. The plugins forward any `vcmrtd://` URL, so they need no logic change. |
| 8 | Session token origin | Assumes the QR or link carries the session token: `proofing_session_client.dart:9-20` | The session token appears in no QR or link (`device_access.go:363-366`). The app gets it from the claim response `token`. | `ProofingSessionRef` needs to become "grant + api", resolved into "token + deviceToken" by the claim |
| 9 | Fetch fields read | `id`, `relyingParty`, `requestedAttributes`, `expiresAt`, `aaChallenge`: `proofing_session_client.dart:50-80` | Also `method`, `status`, `language`, `steps`, `selfieLocation`, `currentStep`, `completedSteps`, `nativeHandoff`, `chipAccess`, `faceReference`, `referencePhoto`, `stepResults`, `lifecycle`, `readyToSubmit`, `resetCount`, `changeKey`, `flowId`, `flowVersion`, `device`, `devices`: `sessions.go:896-998` | The app ignores the flow, the language, its own step position and the finished or expired state |
| 10 | Empty `requestedAttributes` | Treated as an error and the session is refused: `routing.dart:70-74`, `main.dart:55` | Empty means unrestricted: `sessions.go:1287-1297`. The field is also `omitempty` (`sessions.go:911`). | A valid session with no attribute filter is rejected by the app |
| 11 | Submission model, flow sessions | Only `POST .../result`: `proofing_session_client.dart:471-503` | With a flow, `/result` is `409 flow_steps_required` (`sessions.go:3052-3061`). Evidence goes through `/steps/document_capture`, `/steps/nfc` and `/steps/selfie`, then `/submit` (`steps.go:625`, `:265`, `:965`, `:1058`). | Flow sessions cannot be completed by the app |
| 12 | Step start signals | Not sent | `POST .../steps/{step}/start` is expected from the app for `document_capture` and `nfc_read` (and a native face step): `steps.go:814-864` | The audit trail misses per-step `in_progress` rows |
| 13 | Native face step | Runs face verification on the device and reports a score in `/result`: `proofing_result_submission.dart:39-46` | With `selfieLocation: "native"`, the app must `POST .../steps/selfie {image, mimeType?, frames?}`. The server computes liveness and the match itself: `steps.go:233-336`. With `"browser"`, the app must not do the face step at all. | The app does the face step regardless of `selfieLocation`, and in a form the server ignores for flows |
| 14 | Claimed status | Always `"approved"`: `proofing_result_submission.dart:35` | `status` is required and is one of `approved`, `rejected`, `needs_review`, `cancelled`, but only as a claim: `sessions.go:3066-3070`, `:3115-3136` | Harmless today, since the server overrides it. The app can never report a cancel or a reject. |
| 15 | `faceVerified` | `true` whenever an outcome object exists, whatever the match result: `proofing_result_submission.dart:43` | Self-reported `biometrics` is replaced by server-computed values whenever `selfie` is sent: `sessions.go:3085-3097` | Misleading only if the selfie is dropped by attribute filtering (see #16) |
| 16 | Client-side attribute gating of evidence | `mrtdEvidence` is sent only if `chip_checks` was requested, and `selfie` only if `selfie` was: `proofing_session_client.dart:428-429` | The server needs `mrtdEvidence` to run Passive and Active Authentication, and a `selfie` image to compute biometrics. It filters the *result* by attributes server-side (`buildResult`, `sessions.go:1315`). `/steps/nfc` *requires* `mrtdEvidence` (`steps.go:634-637`). | When `chip_checks` is not requested, the server never authenticates the chip and the result carries no chip checks. On `/steps/nfc` the request is a `400`. |
| 17 | Attribute vocabulary | 7 keys, no `document_image`: `proofing_session_client.dart:380-386` | 8 keys, including `document_image`: `sessions.go:1272-1281` | The app never sends `documentImage` (VIZ). That is expected, since no VIZ capture exists in the app. |
| 18 | `chipAccess.documentType` values (future `/steps/document_capture`) | The vcmrtd vocabulary is `passport`, `drivers_license`, `id_card`: `vcmrtd/lib/src/types/document_type.dart:3-9` | Accepts `passport`, `identity_card`, `drivers_license`: `steps.go:1009-1011` | When the app adopts `/steps/document_capture`, ID cards must map `id_card` to `identity_card`, or the request is a `400` |
| 19 | Result response | Body ignored, only `200` is checked: `proofing_session_client.dart:500-502` | Returns the relying-party `sessionView`, including the final `status`, `errorCode` and full `result`: `sessions.go:3201` | The app cannot show the server's actual verdict |
| 20 | Error handling | Generic `Exception` on any non-200: `proofing_session_client.dart:455-457`, `:500-502` | Machine `code` values the app is meant to react to, for example `device_handed_over` ("handed over to another device"), `session_expired` and `handover_expired`: `device_access.go:41-56`, `:82-111` | No handover or expiry UX |
| 21 | Live updates | None | `GET .../events?since=<changeKey>` long-poll (25 s): `sessions.go:2915-2950`. `resetCount` changes mean start over (`sessions.go:953-957`). | The app misses a relying-party reset, a handover or a cancel |
| 22 | Presence | None | `POST .../device/state {"state": "active" \| "inactive"}`: `device_access.go:569-648`. The web side mints a native handover code when the app goes `inactive` or `stale`. | The web side only learns the app left after 45 s (`stale`), or 5 s after a dropped long-poll the app never opens |
| 23 | Language | Not read or sent | `language` is in the view. The server falls back to `Accept-Language`: `sessions.go:905-910`, `i18n.go:43-45` | The app's copy is not localised per session |
| 24 | Expiry | `expiresAt` is parsed but never enforced or refreshed: `proofing_session_client.dart:77` | Default 10 min, hard cap 15 min from creation: `api.go:264-270`, `device_access.go:653-683` | A slow user hits `410` only at submit time |
| 25 | `aaKeyDataGroup` / `documentType` | Sent explicitly (`DG15`/`icao`, `DG13`/`eu_driving_licence`): `idem/lib/widgets/pages/passport_data_screen.dart:92-96`, `driving_licence_data_screen.dart:108-112` | Both are accepted. `aaKeyDataGroup` defaults to `DG15` for ICAO: `sessions.go:1117-1190`. | Compatible. No change needed. |
| 26 | Document and photo field shapes | `ProofingDocumentInfo.toJson`, `ProofingPhotoInfo.toJson`, `ProofingDeviceInfo.toJson`: `proofing_session_client.dart:169-183`, `:248`, `:369-372` | `documentInfo`, `photoInfo`, `deviceInfo`: `sessions.go:1039-1088`, `:1264-1268` | Compatible, field for field |
| 27 | AA nonce gating | Uses `aaChallenge` only when the Active Authentication toggle is on: `nfc_reading_screen.dart:421-434` | Always issues one. Evidence with a different nonce is treated as a clone: `docs/session-model.md:241-253`, matching `verifyMrtdEvidence` | With the toggle off, the chip's AA is never checked. That is a weaker result, not an error. |
| 28 | Idempotency | No `Idempotency-Key` on retry: `proofing_result_submission.dart:70-77` | Supported on `/result` (Postgres only): `sessions.go:3025-3030` | A retried submit after a lost response gets `409` (already finished) instead of a replay |

## 10. Where the server's own docs disagree with its code

| Doc | Says | Code says |
| --- | --- | --- |
| `docs/session-model.md:162` | App routes are authenticated by the path token only | `X-Device-Token` is required (`device_access.go:190-206`) |
| `docs/session-model.md:169` | `SessionOpenTTL` defaults to 5 min | 10 min (`api.go:267`) |
| `docs/session-model.md:193` | `SessionCreateTTL` defaults to 15 min | 10 min (`api.go:264`), with a 15 min hard lifetime cap (`api.go:268`) |
| `docs/session-model.md:277-281` | `deepLink` is `vcmrtd://verify?token=...&api=...` and `qr` is `https://<host>/api/v1/s/{token}` | `vcmrtd://verify?handover=<grant>&api=...`. `qr` is the same link, and no `/api/v1/s/` route exists (`device_access.go:446-456`). |
| `docs/session-model.md:282-291` | The app (at `example/lib/...`) cannot handle a tapped deep link | Out of date on the app side: the app now registers `vcmrtd` and wires `proofing_deeplink`. It breaks on the query parameter instead (#5). |
| `docs/session-model.md:331` | `nativeHandoff` is `{deepLink, qr}` | `{role, claimed}` (`sessions.go:1001-1010`). The table row at `:169` is correct. |
| `README.md:274`, `:342`; `docs/compliance.md:458` | `GET /api/v1/s/{token}` is a live app entry point | Removed in `7409bb7` |
| `docs/api/openapi.yaml` | Lists 16 `/api/v1/app` paths | Has no `GET /api/v1/app/{token}/events` and no `POST /api/v1/app/{token}/claim`, and never documents the `X-Device-Token` header. The file is generated from swag annotations (`Makefile:54-63`), and those handlers declare no header parameter. |

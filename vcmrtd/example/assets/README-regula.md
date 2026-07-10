# Regula face verification (liveness + backend match)

Face verification is bound to a **Regula liveness transaction** and matched by
the **go-passport-issuer** backend — the client never does the match itself and
ships no Regula license.

## Flow

1. The user reads the document chip over NFC (existing flow).
2. On **Verify**, the app runs a Regula liveness session
   (`RegulaFaceService.captureLiveness`) against the Regula **Face API**. The
   Face API validates liveness, stores the proven-live portrait, and returns a
   `liveness_transaction_id`.
3. The app sends that id as `liveness_transaction_id` on the verify request
   (`/api/verify-passport` / `/api/verify-driving-licence`).
4. The issuer confirms liveness server-side, matches the chip portrait against
   the live face, deletes the transaction, and returns `face_match
   { matched, similarity }`, which the app shows in the verify result.

## Configuration

- `faceApiUrlProvider` (`lib/providers/face_api_provider.dart`) holds the
  Regula Face API URL. It must point at the **same** Face API the issuer uses
  so the transaction id resolves server-side. Defaults to
  `https://faceapi.staging.yivi.app`.
- When `faceApiUrlProvider` is `null`, the verify flow submits no liveness
  transaction and the issuer skips face matching.
- The Face API (and the issuer's `regula_face_api_url`) hold the Regula
  license; see the go-passport-issuer repo for backend setup.

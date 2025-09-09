# Active Authentication (AA)
Active Authentication is an optional security protocol aimed at detecting cloning of passport chips. Where Passive Authentication verifies the data, Active Authentication verifies the chip’s uniqueness. It’s essentially a challenge-response protocol using an asymmetric key pair embedded in the passport: the chip proves it holds a private key that corresponds to a public key stored in the passport’s data, thereby confirming that this is not just a copy of the data on another chip. How it works: If a passport supports AA, it will have:
- A private key securely stored on the chip (inaccessible for reading).
- The corresponding public key stored in Data Group 15 (DG15). DG15 may include the key algorithm info (e.g., RSA 1024-bit or 2048-bit modulus, or an ECC public key point, etc.). The hash of this public key is also included in the EF.SOD signature, meaning any alteration of the key would be detected by Passive Auth.

During inspection, after BAC (so the communication is secure), the reader may perform Active Authentication as follows:
1. The terminal reads DG15 to obtain the chip’s public key (let’s call it Pub_AA).
1. The terminal generates a random challenge (usually 8 bytes as per the standard). It sends this challenge to the chip in an INTERNAL AUTHENTICATE APDU.
1. The chip, upon receiving the challenge, may also generate its own random (some implementations do this to ensure it’s not replayable). According to ICAO 9303, the chip could concatenate its own random R<sub>ICC</sub> with the terminal’s challenge R<sub>IFD</sub>, and perhaps hash them, then sign the result with its private key. (One common method: the chip signs R<sub>IFD</sub> || R<sub>ICC</sub> or a hash thereof.)
1. The chip returns the signature (and possibly its random if used) to the terminal.
1. The terminal verifies the signature using the public key from DG15. If the signature is correct, it proves the chip had the matching private key, meaning this chip is the genuine one originally issued with that passport’s data.

If an attacker only cloned the data onto another chip, they would not have the original chip’s private key, so they would fail to produce a valid signature in step 5. Thus, AA is effective against cloning attacks where someone tries to use a copied data (since Passive Auth would still pass on a clone, AA adds an extra check).

**Algorithm and standards**: The challenge-response in AA is based on ISO 9796-2 (for RSA) or analogous for ECDSA. Many passports historically used RSA keys (1024-bit) for AA. Newer ones might use ECC (with smaller key sizes but strong security). The protocol is simple: sign a nonce. It’s important that the nonce be unique per session (terminal ensures that by generating random, chip often adds its own random too). Also, to avoid replay, the chip’s random or the fact that the challenge is different ensures an attacker can’t replay a known signature.

**Privacy consideration**: Active Authentication does have a privacy implication: the chip’s public key is static and unique per passport. If an attacker could trigger AA and get a signature, in theory they could identify the passport by that signature (since the public key acts like an ID). A known attack is that if someone could query a passport at two different places, they could confirm it’s the same passport by checking the public key or verifying a signature with a previously seen public key. This is mitigated by the need to do BAC first (so random people can’t do AA without MRZ), but BAC keys can sometimes be guessed or the attacker might be an insider. Germany and some other countries considered this a "privacy threat" – the scenario described by Riha is that an inspection system could craft a challenge that encodes location/time, and later show the signed challenge as proof that a passport was present at that place/time (non-repudiation issue). Because of such concerns, Germany, and others (Greece, Italy, France) chose not to implement Active Authentication in their e-passports. They instead relied on the later Chip Authentication as part of EAC for anti-cloning (which is done under secure messaging and doesn’t reveal a static public key to eavesdroppers, thereby avoiding the traceability issue).

**Active Auth vs. Chip Auth**: Active Authentication was the first-gen solution to cloning. Chip Authentication (in EAC) can be seen as a replacement in newer passports (it achieves the same goal but in a more sophisticated way). Indeed, Chip Auth subsumes AA’s role and also sets up new session keys, removing the traceability problem. Many passports that implement EAC skip AA. Some implement both (to remain compatible or add redundancy).

**When/How it’s run**: Typically, if AA is supported, the inspection system will do it right after BAC and before reading too many files (or at least before concluding the session). For example, an order might be: BAC -> read DG1/DG2 -> do AA -> then proceed. It doesn’t strictly have to be before reading, but since AA doesn’t require reading any more files (just uses DG15), it’s efficient to do it early. Doing it after reading doesn’t add benefit because if a clone was present, all data read was from clone already. Some systems might even do AA after reading to cross-check, but logically sooner is better.

**Cloning and relay**: Note that AA can be defeated by a relay attack: An attacker with a cloned chip could secretly communicate with the genuine passport in the victim’s pocket over some channel (like using two radio devices). The clone, when asked to do AA, relays the challenge to the genuine passport (which is perhaps close by) and relays back the signature. This way the clone chip itself doesn’t need the private key; it just “asks” the real one over the air. This is a man-in-the-middle attack and has been demonstrated (known as the “ghost and leech” attack). Such an attack is high-tech and requires the genuine passport to be in range (and BAC keys known, etc.), but it’s theoretically possible. It shows that even AA isn’t foolproof if someone can proxy the communication (which BAC was supposed to prevent by requiring physical proximity to see MRZ, but if the attacker has that, they might as well just steal the passport outright!). Nonetheless, it’s a noted vulnerability in research.

**Library implementation**:
```dart
final passport = Passport(_nfc);
// Assuming you have a passport object with methods to read DG15 and perform AA

// Read the public key from DG15
final dg15 = await passport.readEfDG15();

// Perform Active Authentication note the challenge size is typically 8 bytes
final aaSig = await passport.activeAuthenticate(Uint8List(8));
```

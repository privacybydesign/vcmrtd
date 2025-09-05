# Password Authenticated Connection Establishment (PACE)
PACE is a newer protocol (part of Supplemental Access Control, SAC) that was introduced to address weaknesses in BAC. While not part of the original EAC, it’s worth mentioning as it’s widely used in newer passports (particularly EU since 2014). PACE replaces BAC’s static key handshake with an active diffie-hellman based key agreement using the MRZ (or CAN) as a password. The result is that it effectively thwarts eavesdropping attacks and brute-force guessing: an attacker cannot capture an encrypted exchange and later brute force the key because PACE’s exchange is designed such that guessing the wrong password yields no verifiable info without interacting with the chip each time (a property of PAKE protocols).

In PACE, the chip and terminal do roughly:
- Perform an Password Authenticated Diffie-Hellman: they agree on a shared key using the MRZ data as a low-entropy secret that is infused in the math such that an active MITM without the password would fail. If the terminal doesn’t know the correct MRZ, the protocol will fail.
- Once done, they get a strong session key (usually an AES key). Then they establish Secure Messaging with that key (no need for the weak BAC keys at all).
- PACE is typically combined with Chip Authentication in modern passports, as mentioned (PACE-CAM) to also authenticate the chip in one go.

The EU mandated PACE by 2014, meaning all member state passports issued since then support it, and by 2018 they allowed turning off BAC entirely. However, to maintain interoperability, most passports still kept BAC as a fallback till readers worldwide caught up. The guidance is that passports can have both; inspection systems should try PACE first and use BAC if PACE isn’t supported. By now, many inspection systems indeed use PACE.

1. Reader scans MRZ from passport machine-readable zone.
1. Reader does PACE with the chip (establish secure session with AES).
1. Reader reads EF.COM, DG1, DG2, etc.
1. Reader performs Chip Authentication (if not done via PACE-CAM).
1. Reader provides Terminal Authentication certificates and proves its authorization.
1. Reader, now authorized, reads DG3 (fingerprints) if needed.
1. Meanwhile, it verifies Passive Auth at some point to ensure data integrity.
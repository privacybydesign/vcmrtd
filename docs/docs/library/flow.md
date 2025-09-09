# Passport Issuance Flows
There are **two distinct flows** for issuing a passport-based credential, depending on whether the process is initiated in the **Example App** or directly inside the **Yivi App**. The overall sequence of interactions is very similar (scanning MRZ, NFC reading, validation at the issuer, IRMA issuance), but there is one important difference:  
- In the **Example App flow**, the Example App orchestrates the NFC reading and validation, then hands over to the Yivi App via a universal link to complete the issuance.  
- In the **Yivi App flow**, all steps (including NFC reading, issuer communication, and credential storage) are handled within the Yivi App itself. No external app is needed.

## Key Differences
- **Example App**:  
  - Acts as a “proxy” between the user and Yivi.  
  - Performs NFC reading, passive and active authentication locally.  
  - Only after obtaining issuer validation does it pass the issuance request to the Yivi App via a universal link.  
  - Yivi App is only involved at the final stage: the actual credential issuance and storage.

- **Yivi App**:  
  - Acts as a self-contained flow.  
  - Handles the entire process from MRZ scanning, NFC reading, issuer communication, to credential storage.  
  - No need to context switch between apps.  
  - This is closer to what a real-world user flow would look like in production.

## Sequence diagrams
### Example App
```mermaid
sequenceDiagram
    participant User
    participant ExampleApp
    participant YiviApp
    participant Passport
    participant PassportIssuer
    participant IrmaServer

    User->>ExampleApp: Open Yivi App
    activate ExampleApp
    User->>ExampleApp: Select "Start Passport Issuance"
    ExampleApp->>PassportIssuer: start-validation
    activate PassportIssuer
    PassportIssuer-->>ExampleApp: sessionId, nonce
    deactivate PassportIssuer

    alt MRZ scanned via camera
        ExampleApp->>User: Show MRZ scanner
        User->>Passport: Show passport data page
        activate Passport
        ExampleApp->>Passport: OCR MRZ from passport
        Passport-->>ExampleApp: MRZ Data
        deactivate Passport
    else Manual entry
        ExampleApp->>User: Request manual MRZ input
        User->>ExampleApp: Enter date of birth, expiry, doc number
    end

    ExampleApp->>User: Request NFC to be enabled
    User->>Passport: Tap passport on phone
    activate Passport

    ExampleApp->>Passport: Perform BAC or PACE
    Passport-->>ExampleApp: Authenticated
    ExampleApp->>Passport: Read Data Groups
    Passport-->>ExampleApp: DataGroups
    ExampleApp->>Passport: Read EF.SOD
    Passport-->>ExampleApp: EF.SOD
    ExampleApp->>Passport: Perform Active Auth (if supported, with nonce)
    Passport-->>ExampleApp: ActiveAuth signature
    deactivate Passport

    ExampleApp->>PassportIssuer: Send sessionId, dataGroups, EF.SOD, activeAuthSig
    activate PassportIssuer
    PassportIssuer->>PassportIssuer: Perform Passive Auth (CSCA check)
    PassportIssuer->>PassportIssuer: Validate Active Auth (nonce/sessionId)

    PassportIssuer->>ExampleApp: Return IRMA issuance request (signed JWT, IrmaServer info)
    deactivate PassportIssuer

    ExampleApp->>IrmaServer: Start issuance session with JWT
    activate IrmaServer
    IrmaServer-->>ExampleApp: Return IRMA session pointer
    ExampleApp->>IrmaServer: Start IRMA session
    ExampleApp->>ExampleApp: Construct Yivi universal link
    ExampleApp->>YiviApp: Open Yivi App with Universal link
    activate YiviApp
    deactivate ExampleApp
    YiviApp->>IrmaServer: Start IRMA session
    IrmaServer-->>YiviApp: Return credential
    YiviApp->>YiviApp: Store credential
    deactivate YiviApp
    deactivate IrmaServer
```

### Yivi App

```mermaid
sequenceDiagram
    participant User
    participant YiviApp
    participant Passport
    participant PassportIssuer
    participant IrmaServer

    User->>YiviApp: Open Yivi App
    activate YiviApp
    User->>YiviApp: Select "Start Passport Issuance"
    YiviApp->>PassportIssuer: start-validation
    activate PassportIssuer
    PassportIssuer-->>YiviApp: sessionId, nonce
    deactivate PassportIssuer

    alt MRZ scanned via camera
        YiviApp->>User: Show MRZ scanner
        User->>Passport: Show passport data page
        activate Passport
        YiviApp->>Passport: OCR MRZ from passport
        Passport-->>YiviApp: MRZ Data
        deactivate Passport
    else Manual entry
        YiviApp->>User: Request manual MRZ input
        User->>YiviApp: Enter date of birth, expiry, doc number
    end

    YiviApp->>User: Request NFC to be enabled
    User->>Passport: Tap passport on phone
    activate Passport

    YiviApp->>Passport: Perform BAC or PACE
    Passport-->>YiviApp: Authenticated
    YiviApp->>Passport: Read Data Groups
    Passport-->>YiviApp: DataGroups
    YiviApp->>Passport: Read EF.SOD
    Passport-->>YiviApp: EF.SOD
    YiviApp->>Passport: Perform Active Auth (if supported, with nonce)
    Passport-->>YiviApp: ActiveAuth signature
    deactivate Passport

    YiviApp->>PassportIssuer: Send sessionId, dataGroups, EF.SOD, activeAuthSig
    activate PassportIssuer
    PassportIssuer->>PassportIssuer: Perform Passive Auth (CSCA check)
    PassportIssuer->>PassportIssuer: Validate Active Auth (nonce/sessionId)

    PassportIssuer->>YiviApp: Return IRMA issuance request (signed JWT, IrmaServer info)
    deactivate PassportIssuer

    YiviApp->>IrmaServer: Start issuance session with JWT
    activate IrmaServer
    IrmaServer-->>YiviApp: Return IRMA session pointer
    YiviApp->>IrmaServer: Start IRMA session
    IrmaServer-->>YiviApp: Return credential
    YiviApp->>YiviApp: Store credential
    deactivate IrmaServer

    deactivate YiviApp
```
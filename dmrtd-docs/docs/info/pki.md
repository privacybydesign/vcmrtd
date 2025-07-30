# PKI

```mermaid
C4Context
    title ePassport PKI Trust Model

    System_Boundary(pki, "PKI") {
        System(icao, "ICAO Master List", "Global trust anchor with CSCA certificates")

        System_Ext(csca_us, "CSCA 🇺🇸", "Country Signing CA - United States")
        System_Ext(csca_de, "CSCA 🇩🇪", "Country Signing CA - Germany")
        System_Ext(csca_br, "CSCA 🇧🇷", "Country Signing CA - Brazil")

        Container(ds_de1, "DS 🇩🇪", "Document Signer", "Signs German passport SOD")
        Container(ds_de2, "DS 🇩🇪", "Document Signer", "Signs German passport SOD")
    }

    System_Boundary(passport, "ePassport") {
        Container(sod, "SOD", "Signed Object Document", "Signed hash of Data Groups")
        Container(dg1, "DG1", "Data Group 1", "MRZ (Machine Readable Zone)")
        Container(dg2, "DG2", "Data Group 2", "Facial Image")
        Container(dg16, "DG16", "Data Group 16", "Custom/National Data")
    }

    Rel(icao, csca_us, "Publishes CSCA certificate for")
    Rel(icao, csca_de, "Publishes CSCA certificate for")
    Rel(icao, csca_br, "Publishes CSCA certificate for")

    Rel(csca_de, ds_de1, "Issues DS cert")
    Rel(csca_de, ds_de2, "Issues DS cert")

    Rel(ds_de1, sod, "Signs")
    Rel(sod, dg1, "Contains hash of")
    Rel(sod, dg2, "Contains hash of")
    Rel(sod, dg16, "Contains hash of")
```

## Download ICAO PKI Objects
https://pkddownloadsg.icao.int/download
https://www.npkd.nl/index.html

- The latest collection of eMRTD PKI objects (Document Signer certificates (DSCs), Bar Code Signer certificates (BCSCs/VDSs), Bar Code Signer for non-constrained environments certificates (BCSC-NCs/VDS-NCs) and Certificate Revocation Lists (CRLs)) to verify electronic passports.
- The latest collection of CSCA Master Lists.

files can be opened using Apache Directory Studio.
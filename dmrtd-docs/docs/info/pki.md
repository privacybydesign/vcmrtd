# PKI
![CSCA PKI infrastructure](/images/CSCA.png)

## Download Masterlists
We will first experiment with the Dutch Masterlist, which can be found here: https://www.npkd.nl/index.html
The reason that we experiment with this is because the Governance of the ICAO lists is questionable. This is reflected in the absence of for instance the USA root certificates

You need to download the following files

1. Masterlist.mls which contains 394 certificates of a 120 countries and is signed by the Dutch Government.
1. The Self signed certificate.
1. The latest Link Certificate.

# Validating EF.SOD
The goal is to extract the Document Signer Certificate and validate the `EF.SOD` against the CSCA master list.

## Loads the EF.SOD into ASN1parser.
Read the `EF.SOD` section from the Passport.

```dart
final hex = mrtdData.sod!.toBytes().hex();
```

Load the `hex` into `https://lapo.it/asn1js` to explore the ASN1 structure.

The hex dump form Dart can be put into a txt file. 
`echo hexstring > sod.txt`

Then it be converted to binary format using `xxd -r -p sod.txt > EF.SOD`

Then the file can be parsed using `openssl asn1parse -in EF.SOD -inform DER -i`

## Strip application tag
The actual CMS ContentInfo (which OpenSSL expects to start with a SEQUENCE) begins at byte offset 4.
Manually strip the outer [APPLICATION 23] tag
```
0:d=0  hl=4 l=2659 cons: appl [ 23 ]
4:d=1  hl=4 l=2655 cons:  SEQUENCE
```
```
dd if=EF.SOD of=EF.SOD.cms bs=1 skip=4
```

## Extract the Document Signer Certificate
```
openssl cms -inform DER -in EF.SOD.cms -verify -noverify -out /dev/null -certsout dsc.pem
openssl x509 -in dsc.pem -text -noout
```

## Convert the Document Signer Certificate to a CER file
```
openssl x509 -in dsc.pem -outform DER -out dsc.cer
```

## Get the CSCA's
1. Download the Masterlist file here https://www.npkd.nl/index.html
1. Download the Self-signed certificate and link certificate
1. Use the [icao-ml-tools](https://github.com/DibranMulder/icao-ml-tools) to unpack the Masterlist
1. Look for the right serial number which is in the `EF.SOD`
    - `openssl asn1parse -in EF.SOD -inform DER -i`
1. Convert the CSCA `der` file to a `cer` file. 
    - `openssl x509 -in input.der -inform DER -out output.cer -outform PEM`

# Verify DSC chain
Verify that the Document Signer Certificate belongs to the CSCA.
```
openssl verify -CAfile csca.cer dsc.pem
dsc.pem: OK
```

## Extract signed content
```
openssl cms -inform DER -in EF.SOD.cms -verify -noverify -out lds_content.der
```

## Verify data integrity
```
openssl asn1parse -in lds_content.der -inform DER -i
```


## Verify EF.SOD signature
```
openssl cms -inform DER -in EF.SOD.cms -CAfile csca.cer -out /dev/null -verify
CMS Verification successful
```
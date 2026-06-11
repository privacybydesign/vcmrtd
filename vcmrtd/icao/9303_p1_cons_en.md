Approved by and published under the authority of the Secretary General
INTERNATIONAL CIVIL AVIATION ORGANIZATION
Doc 9303
Machine Readable Travel Documents
Part 1: Introduction
Eighth Edition, 2021


Approved by and published under the authority of the Secretary General
INTERNATIONAL CIVIL AVIATION ORGANIZATION
Doc 9303
Machine Readable Travel Documents
Part 1: Introduction
Eighth Edition, 2021


 
 
 
 
 
 
 
Published in separate English, Arabic, Chinese, French, Russian 
And Spanish editions by the 
INTERNATIONAL CIVIL AVIATION ORGANIZATION 
999 Robert-Bourassa Boulevard, Montréal, Québec, Canada H3C 5H7 
 
 
Downloads and additional information are available at www.icao.int/Security/mrtd  
 
 
 
 
 
 
 
 
 
 
 
 
 
Doc 9303, Machine Readable Travel Documents 
Part 1 — Introduction 
ISBN 978-92-9265-291-3 
 
 
 
 
 
© ICAO 2021 
 
All rights reserved. No part of this publication may be reproduced, stored in a 
Retrieval system or transmitted in any form or by any means, without prior 
Permission in writing from the International Civil Aviation Organization. 
 
 
 


 
(iii) 
AMENDMENTS 
 
 
Amendments are announced in the supplements to the Products and Services 
Catalogue; the Catalogue and its supplements are available on the ICAO 
website at www.icao.int. The space below is provided to keep a record of such 
amendments. 
 
 
RECORD OF AMENDMENTS AND CORRIGENDA 
 
AMENDMENTS 
 
CORRIGENDA 
No. 
Date 
Entered by 
 
No. 
Date 
Entered by 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
The designations employed and the presentation of the material in this publication do 
not imply the expression of any opinion whatsoever on the part of ICAO concerning the 
legal status of any country, territory, city or area or of its authorities, or concerning the 
delimitation of its frontiers or boundaries. 


 
 
 
 
 
(v) 
TABLE OF CONTENTS 
 
 
 
Page 
 
1. 
FOREWORD .......................................................................................................................................  
1 
 
2. 
SCOPE ..............................................................................................................................................  
1 
 
3. 
GENERAL CONSIDERATIONS .........................................................................................................  
2 
 
 
3.1 
ICAO’s Leadership Role .......................................................................................................  
2 
 
3.2 
Relative Costs and Benefits of Machine Readable Travel Documents .................................  
2 
 
3.3 
Operations ............................................................................................................................  
3 
 
3.4 
Endorsement by ISO ............................................................................................................  
3 
 
4. 
DEFINITIONS AND REFERENCES ...................................................................................................  
4 
 
 
4.1 
Acronyms ..............................................................................................................................  
4 
 
4.2 
Terms and Definitions ...........................................................................................................  
8 
 
4.3 
Key Words ............................................................................................................................  
25 
 
4.4 
Object Identifiers ...................................................................................................................  
26 
 
4.5 
The Use of Notes ..................................................................................................................  
29 
 
5. 
GUIDANCE ON THE USE OF DOC 9303 ..........................................................................................  
29 
 
 
5.1 
Doc 9303 Composition .........................................................................................................  
29 
 
5.2 
Relationship between MRTD Form Factors and relevant Doc 9303 Parts ............................  
31 
 
6. 
REFERENCES (NORMATIVE) ...........................................................................................................  
31 
 
 
 
 
______________________ 


 
 
 
 
 
 
1 
 
1.    FOREWORD 
 
ICAO’s work on machine readable travel documents began in 1968 with the establishment, by the Air Transport 
Committee of the Council, of a Panel on Passport Cards. This Panel was charged with developing recommendations for 
a standardized passport book or card that would be machine readable, in the interest of accelerating the clearance of 
passengers through passport controls. The Panel produced a number of recommendations, including the adoption of 
optical character recognition (OCR) as the machine reading technology of choice due to its maturity, cost-effectiveness 
and reliability. In 1980, the specifications and guidance material developed by the Panel were published as the first 
edition of Doc 9303, titled A Passport with Machine Readable Capability, which became the basis for the initial issuance 
of machine readable passports by Australia, Canada and the United States. 
 
In 1984, ICAO established what is now known as the Technical Advisory Group on Machine Readable Travel 
Documents (TAG/MRTD), comprised of government officials who specialize in the issuance and border inspection of 
passports and other travel documents, in order to update and enhance the specifications which had been prepared by 
the Panel. Subsequently, this group’s terms of reference were expanded to include, first, the development of 
specifications for a machine readable visa and, later, specifications for machine readable cards that may be used as 
official travel documents.  
 
In 1998, the New Technologies Working Group of the TAG/MRTD began work to establish the most effective biometric 
identification system and associated means of data storage for use in MRTD applications, particularly in relation to 
document issuance and immigration considerations. The bulk of the work had been completed by the time the events of 
11 September 2001 caused States to attach greater importance to the security of a travel document and the 
identification of its holder. The work was quickly finalized and endorsed by the TAG/MRTD and the Air Transport 
Committee. 
 
The resulting Technical Reports on the employment of biometrics and contactless chip technology, Logical Data 
Structure (LDS), and Public Key Infrastructure (PKI) were incorporated into Volume 2 of the Sixth Edition of Doc 9303, 
Part 1 (Machine Readable Passports) in 2006, and Volume 2 of the Third Edition of Doc 9303, Part 3 (Machine 
Readable Official Travel Documents) in 2008. 
 
 
 
2.    SCOPE 
 
Doc 9303 consists of various separate documents in which general (applicable to all MRTDs) as well as MRTD form 
factor specific specifications are grouped. See Section 5.1 “Doc 9303 Composition” for an overview. 
 
These specifications are not intended to be a standard for national identity documents. However, a State whose identity 
documents are recognized by other States as valid travel documents shall design its identity documents such that they 
conform to the specifications of Doc 9303-3 and Doc 9303-4, Doc 9303-5 or Doc 9303-6. 
 
Although the specifications in Doc 9303-4 are intended for particular application to the passport, these specifications 
apply equally to other TD3 size identity documents, for example, the laissez-passer, the seafarer’s identity document 
and refugee travel documents. 
 
 
 


 
2 
Machine Readable Travel Documents 
 
The document at hand is Part 1. Part 1 introduces the Doc 9303 specifications. It describes the build-up of the thirteen 
parts of Doc 9303, provides general information on ICAO, and guidance on the terminology and abbreviations used 
throughout the specifications. 
 
 
 
3.    GENERAL CONSIDERATIONS 
 
 
3.1    ICAO’s Leadership Role 
 
ICAO’s initiative to develop standard specifications for passports and other travel documents followed the tradition 
established by the League of Nations Passport Conferences of the 1920s and the work of the League’s successor, the 
United Nations Organization. ICAO’s mandate to continue in its leadership role stems from the Convention on 
International Civil Aviation (the “Chicago Convention”) which covers the full range of requirements for efficient and 
orderly civil aviation operations, including provisions for clearance of persons through border controls, i.e.: 
 
 
a) 
the requirement for persons travelling by air and aircraft crews to comply with immigration, customs 
and passport regulations (Article 13); 
 
 
b) 
the requirement for States to facilitate border clearance formalities and prevent unnecessary delays 
(Article 22); 
 
 
c) 
the requirement that States collaborate in these matters (Article 23); and 
 
 
d) 
the requirement for States to develop and adopt internationally standard procedures for immigration 
and customs clearance (Article 37 j)). 
 
Under this mandate, ICAO develops and maintains international Standards in Annex 9 — Facilitation to the Chicago 
Convention for implementation by Member States. In the development of such Standards, it is a fundamental precept 
that if public authorities are to facilitate inspection formalities for the vast majority of air travellers, those authorities must 
have a satisfactory level of confidence in the reliability of travel documents and in the effectiveness of inspection 
procedures. The production of standardized specifications for travel documents and the data contained therein is aimed 
at building that confidence. 
 
In 2004, the Assembly of ICAO affirmed that cooperative work on specifications to strengthen the security and integrity 
of travel documents should be pursued by the Organization as a matter of high priority. In addition to the International 
Organization for Standardization (ISO), consultants to the TAG/MRTD include the International Air Transport Association 
(IATA), the Airports Council International (ACI), and the International Criminal Police Organization (INTERPOL).  
 
In 2005, the then 188 Member States of ICAO approved a new Standard that all States must begin issuing machine 
readable passports in accordance with Doc 9303 no later than the year 2010. No later than the year 2015 all non-
machine readable travel documents must have expired. This Standard is published in the 13th Edition (2011) of Annex 9 
— Facilitation. 
 
 
3.2    Relative Costs and Benefits of Machine Readable Travel Documents 
 
Experience with the issuance of machine readable passports, in conformity with the specifications set forth in Doc 9303, 
indicates that the cost of producing MRTDs may be no greater than that of producing conventional documents, though 
the cost will be higher when biometric identification and electronic travel documents are implemented. As traffic volumes 
grow and more States focus on how they can rationalize their clearance processes with the employment of 


 
Part 1.    Introduction 
3 
 
computerized databases and electronic data interchange, the MRTD plays a pivotal part in modern, enhanced 
compliance systems. Equipment to read the documents and access the databases may entail a substantial investment, 
but this can be expected to be returned by the improvements in security, clearance speed and accuracy of verification 
which such systems provide. Use of MRTDs in automated clearance systems may also make it possible for States to 
eliminate both the requirement for paper documents, such as passenger manifests and embarkation/disembarkation 
cards, and the administrative costs associated with the related manual procedures. 
 
 
3.3    Operations 
 
The basic machine readable travel document, with its OCR readability, is designed for both visual and mechanical 
reading.  
 
ICAO Member States have recognized that standardization is a necessity and that the benefits of adopting the Doc 9303 
standard formats for passports and other travel documents extend beyond the obvious advantages for States that have 
the machine readers and databases for use in automated clearance systems. In fact, the physical characteristics and 
data security features of the documents themselves offer strong defence against alteration, forgery or counterfeit. 
Moreover, adoption of the standardized format for the visual zone of an MRTD facilitates inspection by airline and 
government officials, with the result that clearance of low-risk traffic is expedited, problem cases are more readily 
identified, and enforcement is improved. The optional introduction of biometric identification with data stored on a 
contactless integrated circuit will provide greater security and resistance to fraud and thus make it easier for the 
legitimate document holder to obtain visas for travel and to be processed through border inspection systems. 
 
 
Note.— It is recognized that situations will arise where an eMRTD will not interface correctly with a reader 
at a border. There are several reasons why this might occur, of which a failure of the eMRTD is only one. ICAO 
emphasizes that an eMRTD which fails to read is nevertheless a valid document. However, a failure to read could be the 
result of fraudulent attack, and the receiving State should establish its own procedures for dealing with this possibility, 
which should involve more stringent inspection of the document and its holder but also allow that the failure involves no 
fraudulent intent. 
 
 
3.4    Endorsement by ISO 
 
The technical specifications sections of Doc 9303 have received the endorsement of the International Organization for 
Standardization as ISO Standard 7501. Such endorsement is made possible by means of a liaison mechanism through 
which manufacturers of travel documents, readers and other technologies provide technical and engineering advice to 
the TAG/TRIP under the auspices of ISO. Through this working relationship, the ICAO specifications have achieved, and 
are expected to continue to receive, the status of worldwide standards by means of a simplified procedure within ISO. 
 
 
The liaison mechanism with ISO has been successfully applied not only to the endorsement of new specifications for 
travel documents as ISO standards but also to the approval of amendments to the specifications. Subsequent revisions 
to Doc 9303 will therefore be processed for ISO endorsement in the same manner as previously. 
 
 
 
 
 


 
4 
Machine Readable Travel Documents 
 
4.    DEFINITIONS AND REFERENCES 
 
 
4.1    Acronyms 
 
Acronym 
Full form 
3DES 
Triple DES 
AA 
Active Authentication 
ABC 
Automated Border Control 
AFS 
Anti-Fraud Specialist 
AES 
Advanced Encryption Standard 
AID 
Application Identifier 
APDU 
Application Protocol Data Unit 
AO 
Authorizing Officer 
BAC 
Basic Access Control 
BER 
Basic Encoding Rules 
BLOB 
Binary Large Object 
BSC 
Bar Code Signer Certificate 
CA 
Certification Authority – also – Chip Authentication 
CAM 
Chip Authentication Mapping 
CAN 
Card Access Number 
CAR 
Certification Authority Reference 
CBC 
Cypher Block Chaining 
CBEFF 
Common Biometric Exchange Format Framework 
CCD 
Charge-Coupled Device 
CDS 
Document Signer Certificate 
CIC 
Contactless Integrated Circuit 
CID 
Card IDentifier  
CMAC 
Cipher-based Message Authentication Code 
CMOS 
Complementary Metal–Oxide–Semiconductor 
CRL 
Certificate Revocation List 
CSCA 
Country Signing Certification Authority 
CSD 
Camera to Subject Distance; distance between the eyes plane of a person and the optical 
centre of the camera lens 
CVCA 
Country Verifying Certification Authority 
DER 
Distinguished Encoding Rule 


 
Part 1.    Introduction 
5 
 
Acronym 
Full form 
DES 
Data Encryption Standard 
DF 
Dedicated File 
DG 
Data Group 
DH 
Diffie Hellmann 
DN 
Distinguished Name 
DO 
Data Object 
DOVID 
Diffractive Optically Variable Image Device (feature with diffractive optically variable effects, 
e.g. holographic effects) 
DS 
Document Signer 
DSA 
Digital Signature Algorithm 
DTA 
Digital Travel Authorization 
DTBS 
Data To Be Signed 
DV 
Document Verifier 
EAL 
Evaluation Assurance Level 
ECDH 
Elliptic Curve Diffie Hellmann 
ECDSA 
Elliptic Curve Digital Signature Algorithm 
ECKA 
Elliptic Curve Key Agreement 
EEPROM 
Electrically Erasable Programmable Read Only Memory 
EF 
Elementary File 
EM 
Eye to Mouth distance 
eMRP 
Electronic Machine Readable Passport 
eMROTD 
Electronic Machine Readable Official Travel Document 
eMRTD 
Electronic Machine Readable Travel Document 
eRP 
Electronic Residence Permit 
ERZ 
Effective Reading Zone 
ETS 
Electronic Travel System 
EVZ 
Eye visibility zone; zone covering a rectangle having a distance V of at least 5% of the IED 
to any part of the visible eyeball 
FAR 
False Acceptance Rate 
FIPS 
Federal Information Processing Standard 
FRR 
False Rejection Rate 
GM 
Generic Mapping 
 
 


 
6 
Machine Readable Travel Documents 
 
HD 
Horizontal deviation angle; maximal allowed deviation from the horizontal of the imaginary 
line between the nose of a person and the lens of the camera 
IC 
Integrated Circuit 
ICAO 
International Civil Aviation Organization 
ICC 
Integrated Circuit Card 
IED 
Inter Eye Distance 
IFD 
InterFace Device 
IM 
Integrated Mapping 
IR 
InfraRed light 
IS 
Inspection System 
IV 
Initial Vector 
LDS 
Logical Data Structure 
MAC 
Message Authentication Code 
MF 
Master File 
MRP 
Machine Readable Passport 
MROTD 
Machine Readable Official Travel Document in the form of a card  
MRTD 
Machine Readable Travel Document 
MRV-A 
Full size (Format A) Machine Readable Visa 
MRV-B 
Small size (Format B) Machine Readable Visa 
MRZ 
Machine Readable Zone 
MTF 
Modulation Transfer Function 
MTF20 
Highest spatial frequency where the MTF is 20% or above 
NAD 
Node ADdress 
NIST 
National Institute of Standards and Technology 
NTWG 
New Technologies Working Group 
OCR 
Optical Character Recognition 
OCR-B 
Optical Character Recognition font defined in ISO 1073-2 
OID 
Object IDentifier 
OVD 
Optically Variable Device 
OVF 
Optically Variable Feature 
OVI 
Optically Variable Ink 
PACE 
Password Authenticated Connection Establishment 
PCD 
Proximity Coupling Device 
PICC 
Proximity Integrated Circuit Card 
PIX 
Proprietary Identifier eXtension (PIX). 


 
Part 1.    Introduction 
7 
 
PKD 
Public Key Directory 
PKI 
Public Key Infrastructure 
RID 
Registered IDentifier (RID) 
RFID 
Radio Frequency IDentification 
RGB 
Red-Green-Blue 
ROI 
Region Of Interest 
ROM 
Read Only Memory 
RSA 
Rivest, Shamir and Adleman 
SFR 
Spatial Frequency Response 
SHA 
Secure Hash Algorithm 
SM 
Secure Messaging 
SNR 
Signal to Noise Radio 
SOD 
Document Security Object 
SPOC 
Single Point Of Contact 
sRGP 
standard RGB colour space created for use on monitors, printers and the Internet using the 
ITU-R BT.709 primaries 
SSC 
Send Sequence Counter 
TA 
Terminal Authentication 
TAG/MRTD 
Technical Advisory Group on Machine Readable Travel Documents 
TAG/TRIP 
Technical Advisory Group on the TRaveller Identification Programme 
TD1 
Size 1 Machine Readable Official Travel Document 
TD2 
Size 2 Machine Readable Official Travel Document 
TD3 
Size 3 Machine Readable Travel Document 
TLV 
Tag Length Value 
TR 
Technical Report 
UID 
Unique IDentifier  
UV 
UltraViolet light 
VDS 
Visible Digital Seal 
VIS 
Visa Information System of the European Union 
VIZ 
Visual Inspection Zone 
VS 
Visa Signer 
VVA 
Visa Validation Authority 
WSQ 
Wavelet Scalar Quantization 
 
 
 


 
8 
Machine Readable Travel Documents 
 
4.2    Terms and Definitions 
 
Term 
Definition 
1:1 application case 
Biometric process (algorithm) comparing a sample photo with a registered sample of the 
claimed identity, also known as verification. 
1:N application case 
Biometric process (algorithm) searching an a priori unknown sample photo among N-
registered samples in a database, also known as identification. 
ABC gate 
Automated Border Control Gate for electronic machine readable travel documents. 
Adobe RGB 
RGB colour space designed to encompass most of the colours achievable on CMYK 
colour printers, but by using RGB primary colours on a device such as a computer display. 
Algorithm 
A specified mathematical process for computation; a set of rules which, if followed, will 
give a prescribed result.  
Anti-scan pattern 
An image usually constructed of fine lines at varying angular displacement and embedded 
in the security background design. When viewed normally, the image cannot be 
distinguished from the remainder of the background security print but when the original is 
scanned or photocopied the embedded image becomes visible. 
Application Identifier 
(AID) 
Data element that identifies an application. eMRTD applications use a Standard AID that is 
one of four categories of AID. It consists of a registered application provider identifier (RID) 
and a proprietary application identifier extension (PIX). 
Asymmetric 
Different keys needed on each end of a communication link.  
Asymmetric algorithm 
This type of cryptographic operation uses one key for encryption of plain text and another 
key for decryption of associated cipher text. These two keys are related to each other and 
are called a Key Pair.  
Asymmetric keys 
A separate but integrated user key pair comprised of one public key and one private key. 
Each key is one-way, meaning that a key used to encrypt information cannot be used to 
decrypt the same information.  
Authentication 
A process that validates the claimed identity of a participant in an electronic transaction.  
Authentication Database 
In this database, the authentication algorithms for the implementation of the check routines 
are stored for each document model. 
Authentication Data set 
A specific set of check routines for a document model within the authentication database. 
Authenticity 
The ability to confirm that the Logical Data Structure and its components were created by 
the issuing State or organization. 
Authorization 
A security process to decide whether a service can be given or not. 
Authorization to travel 
Either a non-physical and/or a physical authorization issued by the receiving State 
authorizing the traveller to travel. 
Authorized receiving 
organization 
Organization authorized to process an official travel document (e.g. an aircraft operator) 
and, as such, potentially allowed in the future to record details in the optional capacity 
expansion technology. 
 
 


 
Part 1.    Introduction 
9 
 
Bar code 
Optical, machine readable representation, in one or two dimensions, of data relating to the 
object to which it is attached. 
Bar code Signer 
A bar code Signer digitally signs the data (header and message) encoded in the bar code. 
The signature is also stored in the bar code. 
Bar Code Signer 
Certificate (BSC) 
A BSC is a certificate that contains the bar code Signer's public key. Bar code Signer 
certificates are used to verify the validity of data that were signed with the bar code 
Signer's private key. 
Bar Code Symbology 
A mapping between messages and bar codes is called a symbology. Such mapping is 
defined in the specification of the bar code and includes the encoding of single digits or 
characters, the size of a so-called quiet zone around the bar code, as well as the 
computation of checksums for error correction. 
Biographical data 
(biodata) 
The personalized details of the bearer of the document appearing as text in the visual and 
machine readable zones on the MRTD, or on the Ichip if present. 
Biometric 
A measurable, unique, physical characteristic or personal behavioural trait used to 
recognize the identity, or verify the claimed identity, of an enrollee. 
Biometric Data 
The information extracted from the biometric and used either to build a reference template 
(template data) or to compare against a previously created reference template 
(comparison data). 
Biometric Identification 
A means of identifying or confirming the identity of the holder of an MRTD by the 
measurement of one or more properties of the holder’s person. 
Biometric matching 
The process of using an algorithm that compares templates derived from the biometric 
reference and from the live biometric input, resulting in a determination of match or non-
match.  
Biometric reference 
template 
A data set that defines a biometric measurement of a person, which is used as a basis for 
comparison against a subsequently submitted biometric sample(s).  
Biometric sample 
Raw data captured as a discrete, unambiguous, unique and linguistically neutral value 
representing a biometric characteristic of an enrollee as captured by a biometric system 
(for example, biometric samples can include the image of a fingerprint as well as its 
derivative for authentication purposes). 
Biometric system 
An automated system capable of:  
 
1. capturing a biometric sample from an end user for an MRP;  
 
2. extracting biometric data from that biometric sample;  
 
3. comparing that specific biometric data value(s) with that contained in one or more 
reference templates;  
 
4. deciding how well the data match, i.e. executing a rule-based matching process 
specific to the requirements of the unambiguous identification and person 
authentication of the enrollee with respect to the transaction involved; and  
 
5. indicating whether or not an identification or verification of identity has been 
achieved. 
Biometric template 
Extracted and compressed data taken from a biometric sample. 
Biometric verification 
A means of identifying or confirming the identity of the holder of an MRTD by the 
measurement and validation of one or more unique properties of the holder’s person. 


 
10 
Machine Readable Travel Documents 
 
Bit 
A binary digit. The smallest possible unit of information in a digital code.  
Black-line white-line 
design 
A design made up of fine lines often in the form of a guilloche pattern and sometimes used 
as a border to a security document. The pattern migrates from a positive to a negative 
image as it progresses across the page. 
Block 
A string or group of bits that a block algorithm operates on.  
Block algorithm 
See: block cipher.  
Block cipher 
Algorithms that operate on plain text in blocks (strings or groups) of bits. 
Bootstrapping 
A method of testing the reliability of a data set.  
Breeder Document 
Documentation used as evidence of identity when applying for a travel document. 
Brute-force attack 
Trying every possible key and checking whether the resulting plain text is meaningful. 
Byte  
A sequence of eight bits usually operated on as a unit.  
Caption 
Printed word or phrase to identify a data field. In exceptional circumstances, when multiple 
different official languages do not fit in the data field, numbers can be used. These 
numbers must be accompanied by explanatory text at another location in the MRP. 
Capture 
The method of taking a biometric sample from the end user. 
Card 
Medium according to ISO/IEC 7810, ISO/IEC 7811, ISO 7812 used to carry information. 
Certificate 
Electronic file attesting that a cryptographic key pair belongs to a person or a hardware or 
software component as identified in the certificate. A certificate is issued by a Certification 
Authority. By signing the certificate, the Certification Authority approves the link between 
the identity of a person or component and the cryptographic key pair. The certificate may 
be revoked if it no longer attests to the validity of this link. The certificate has a limited 
validity period.  
Certificate Revocation 
List (CRL) 
A list of certificates that have been revoked. Documents associated to (signed by) a 
certificate contained in a CRL shall thus no longer be trusted. 
Certification Authority  
(CA) 
A trustworthy body that issues digital certificates for PKI. 
Check algorithm 
Software components that enable the specific implementation of check routines 
(e.g. search for patterns). 
Check routine 
Testing procedure for a feature’s specific property (e.g. examination for the presence of 
the photo in IR-light). 
Chemical sensitizers 
Security reagents to guard against tampering by chemical erasure, such that irreversible 
colours develop when bleach and solvents come into contact with the document. 
Chin 
Central forward portion of the lower jaw. 
CIE Standard Illuminant 
D65 
Commonly used standard illuminant defined by the International Commission on 
Illumination (CIE) that is part of the D series of illuminants trying to portray standard 
illumination conditions at open-air in different parts of the world. 
Cipher 
Secret writing based on a key, or set of predetermined rules or symbols. 


 
Part 1.    Introduction 
11 
 
Collation marks 
See: Index marks. 
Colour shifting ink 
Inks changing their visual characteristic depending on the viewing angle and/or the quality 
of a stimulating (light) source. 
Comparison 
The process of comparing a biometric sample with a previously stored reference template 
or templates. See also “One-to-many” and “One-to-one”. 
Contactless integrated 
circuit 
A semi-conductor device that stores MRTD data and which communicates with a reader 
using radio frequency energy according to ISO/IEC 14443. 
Common Biometric 
Exchange Format 
Framework (CBEFF) 
A common file format that facilitates exchange and interoperability of biometric data.  
Control Number 
A number assigned to a document at the time of its manufacture for record-keeping and 
security purposes. 
Counterfeit 
An unauthorized copy or reproduction of a genuine security document made by whatever 
means. 
Country code 
A two- or three-letter code as defined in ISO 3166-1, used to designate a document 
issuing authority or nationality of the document holder.  
Crop factor 
Ratio of the diagonal of the full frame camera (43.3 mm) to that of a selected camera’s 
image sensor. The determination of an appropriate focal length lens for a field of view 
equivalent to a full frame camera can be made by considering the crop factor. 
Crown 
Top of the head ignoring any hair. 
Cryptography 
Science of transforming information into an enciphered, unintelligible form using an 
algorithm and a key.  
Data Encryption 
Standard (DES) 
A method of data encryption specified in FIPS 46-3.  
Data Feature  
The incorporation of encoded information into the document data or image structure, 
usually into the personalization data, especially the portrait.  
Data Group 
A series of related Data Elements grouped together within the Logical Data Structure. 
Data Page 
The page of the passport book, preferably the second or penultimate page, which contains 
the biographical data of the document holder. See “Biographical data”.  
Data To Be Signed 
(DTBS) 
The message that is given as input to a signature generation algorithm of a signature 
scheme. 
Decryption 
The act of restoring an encrypted file to its original state through the use of a key.  
Deviation List 
Signed list issued by an issuing State specifying non-conformities in travel documents 
and/or keys and certificates. 
Deviation List Signer 
An entity that digitally signs a Deviation List. The Deviation List Signer is authorized by its 
national CSCA to perform this function through the issuance of a Deviation List Signer 
certificate. 
 
 


 
12 
Machine Readable Travel Documents 
 
Diffractive Optically 
Variable Device 
A security feature containing a holographic or equivalent image within its construction, the 
image changing its appearance with angle of viewing or illumination.  
Diffractive Optically 
Variable Image Device 
(DOVID)Laminate 
or Overlay 
A laminate or overlay containing a DOVID either covering a whole area or located so as to 
protect key data on the document. 
Digital (cryptographic) 
signature 
The result of a cryptographic operation enabling the validation of information by electronic 
means. This is NOT the displayed signature of the MRTD holder in digital form. 
Digital Signature 
Algorithm (DSA) 
Asymmetric algorithm published by NIST in FIPS 186. This algorithm only provides digital 
signature function.  
Digital (cryptographic) 
Signature Scheme 
A tuple of three algorithms. The key-generation algorithm takes as input a security 
parameter and outputs a key pair consisting of a private and a public key. The signature 
algorithm takes as input a private key, and a message, and outputs a cryptographic 
signature. The verification algorithm takes as input a public key, a message, and a 
signature, and outputs “valid” if the signature was generated using the signature 
generation algorithm with the private key of the key pair and the message as input, and 
“invalid” otherwise. 
(Digital) Document 
Feature 
A property of a document thath can be used to verify the contents of the document. 
Examples are textual information such as the name of the holder, or the issuing date, or a 
printed image of the document holder. A digital document feature is the digitized version of 
a document feature. 
Digital Seal 
Short for Visible Digital Seal. 
Digital Travel 
Authorization 
An electronic visa issued and maintained within the issuing State. 
Digital Watermark 
See: Steganography. 
Directory/Public Key 
Directory (PKD) 
A repository for storing information. Typically, a directory for a particular PKI is a repository 
for the public key encryption certificates issued by that PKI’s Certification Authority, along 
with other client information. The directory also keeps cross-certificates, Certification 
Revocation Lists, and Authority Revocation Lists.  
Displayed signature 
The original written signature or the digitally printed reproduction of the original. 
Document blanks 
A document blank is a travel document that does not contain personalized data. Typically, 
document blanks are the base stock from which personalized travel documents are 
created. 
Document model 
The document model covers the document series of a nation, which have the same optical 
appearance (e.g. (D, P, 1, 2005), (D, P, 2, 2007) and (D, P, 3, 2010). One nation can have 
multiple valid document models in circulation at a given time (e.g. (GBR, P, 1, 2008) and 
(GBR, P, 2, 2010). 
Document number 
A number that uniquely identifies a document. It is recommended that the document 
number and the control number be identical. 
Document Signer  
A body that issues a biometric document and certifies that the data stored on the 
document is genuine in a way that will enable detection of fraudulent alteration.  


 
Part 1.    Introduction 
13 
 
Duplex design 
A design made up of an interlocking pattern of small irregular shapes, printed in two or 
more colours and requiring very close register printing in order to preserve the integrity of 
the image. 
Eavesdropping 
The unauthorized interception of data communication.  
Effective reading 
zone (ERZ) 
A fixed-dimensional area, common to all MRTDs, in which the machine readable data in 
the MRZ can be read by document readers. 
Electrically Erasable 
Programmable Read 
Only Memory (EEPROM) 
A non-volatile memory technology where data can be electrically erased and rewritten. 
Electronic Machine 
Readable Passport 
(eMRP) 
A TD3 size MRTD conforming to the specifications of Doc 9303-4 that additionally 
incorporates a contactless integrated circuit including the capability of biometric 
identification of the holder. Commonly referred to as “ePassport”. 
Electronic Machine 
Readable Official Travel 
Document (eMROTD) 
A TD1 or TD2 size MROTD conforming to the specifications of Doc 9303-5 or Doc 9303-6, 
respectively, that additionally incorporates a contactless integrated circuit including the 
capability of biometric identification of the holder.  
Electronic Machine 
Readable Travel 
Document (eMRTD) 
An MRTD (passport, visa or card) that has a contactless integrated circuit embedded in it 
and the capability of being used for biometric identification of the MRTD holder in 
accordance with the standards specified in the relevant Part of Doc 9303 — Machine 
Readable Travel Documents.  
Embedded image 
An image or information encoded or concealed within a primary visual image. Also see 
steganography. 
Encryption 
The act of disguising information through the use of a key so that it cannot be understood 
by an unauthorized person. 
End user 
A person who interacts with a biometric system to enroll or have one’s own identity 
checked. 
Enrollee 
A human being, i.e. natural person, assigned an MRTD by an issuing State or 
organization. 
Enrollment 
The process of collecting biometric samples from a person and the subsequent 
preparation and storage of biometric reference templates representing that person’s 
identity. 
ePassport 
Commonly used name for an eMRP. See Electronic Machine Readable Passport (eMRP). 
Exposure value (EV) 
Number that represents a combination of a camera's shutter speed and f-number, such 
that all combinations that yield the same exposure have the same EV. 
Extraction 
The process of converting a captured biometric sample into biometric data so that it can be 
compared to a reference template. 
 
 


 
14 
Machine Readable Travel Documents 
 
Eye centre 
Centre of the line connecting the inner and the outer corner of the eye. 
 
Note 1.— The eye centres are the feature points 12.1 and 12.2 as defined in ISO/IEC 
14496.--2. 
 
Note 2.— The inner and the outer corner of the eye are defined by ISO/IEC 14496-2. They 
are the feature points 3.12 and 3.8 for the right eye, and 3.11 and 3.7 for the left eye. 
Eye to mouth distance 
Distance between the face centre M and the mouth midpoint (feature point 2.3 from 
ISO/IEC 14496-2). 
Face centre 
Midpoint of the line connecting the two eye centres. 
Failure to acquire 
The failure of a biometric system to obtain the necessary biometric to enroll a person. 
Failure to enroll 
The failure of a biometric system to enroll a person. 
False Acceptance 
When a biometric system incorrectly identifies an individual or incorrectly verifies an 
impostor against a claimed identity.  
False Acceptance Rate 
(FAR) 
The probability that a biometric system will incorrectly identify an individual or will fail to 
reject an impostor. The rate given normally assumes passive impostor attempts. The false 
acceptance rate may be estimated as FAR = NFA/NIIA or FAR = NFA/NIVA where FAR is 
the false acceptance rate, NFA is the number of false acceptances, NIIA is the number of 
impostor identification attempts, and NIVA is the number of impostor verification attempts. 
False match rate 
Alternative to “false acceptance rate”; used to avoid confusion in applications that reject 
the claimants if their biometric data matches that of an enrollee. In such applications, the 
concepts of acceptance and rejection are reversed, thus reversing the meaning of “false 
acceptance” and “false rejection”. 
False non-match rate 
Alternative to “false rejection rate”; used to avoid confusion in applications that reject the 
claimants if their biometric data matches that of an enrollee. In such applications, the 
concepts of acceptance and rejection are reversed, thus reversing the meaning of “false 
acceptance” and “false rejection”. 
False rejection 
When a biometric system fails to identify an enrollee or fails to verify the legitimate claimed 
identity of an enrollee. 
False rejection rate 
(FRR) 
The probability that a biometric system will fail to identify an enrollee or verify the legitimate 
claimed identity of an enrollee. The false rejection rate may be estimated as follows: 
FRR = NFR/NEIA or FRR = NFR/NEVA where FRR is the false rejection rate, NFR is the 
number of false rejections, NEIA is the number of enrollee identification attempts, and 
NEVA is the number of enrollee verification attempts. This estimate assumes that the 
enrollee identification/verification attempts are representative of those for the whole 
population of enrollees. The false rejection rate normally excludes “failure to acquire” 
errors. 
Feature 
An element of the document that is suitable for the proof of authenticity (e.g. IR-absorbent 
photo). 
Fibres 
Small, thread-like particles embedded in a substrate during manufacture. 
Field 
Specified space for an individual data element within a zone. 
Fingerprint(s) 
One (or more) visual representation(s) of the surface structure of the holder’s fingertip(s). 


 
Part 1.    Introduction 
15 
 
Fluorescent ink 
Ink containing material that glows when exposed to light at a specific wavelength, usually 
UV. 
Forgery 
Fraudulent alteration of any part of the genuine document. 
Fraudulent Alteration 
Involves the alteration of a genuine document in an attempt to enable it to be used for 
travel by an unauthorized person or to an unauthorized destination. The biographical 
details of the genuine holder, particularly the portrait, form the prime target for such 
alteration. 
Front-to-back (see-
through) register 
A design printed on both sides of an inner page of the document which, when the page is 
viewed by transmitted light, forms an interlocking image. 
Full frontal (facial) image 
A portrait of the holder of the MRTD produced in accordance with the specifications 
established in Doc 9303. 
Full size (Format-A) 
machine readable 
visa (MRV-A) 
An MRV conforming with the dimensional specifications contained in Doc 9303-7, sized to 
completely fill a passport visa page. 
Gallery 
The database of biometric templates of persons previously enrolled, which may be 
searched to find a probe. 
Ghost Image 
See: Shadow Image. 
Global interoperability 
The capability of inspection systems (either manual or automated) in different States 
throughout the world to obtain and exchange data, to process data received from systems 
in other States, and to utilize that data in inspection operations in their respective States. 
Global interoperability is a major objective of the standardized specifications for placement 
of both eye readable and machine readable data in all eMRTDs. 
Globally Interoperable 
Biometric 
Refers to Face Image as set forth in Doc 9303-9. 
Guilloche design 
A pattern of continuous fine lines, usually computer generated, and forming a unique 
image that can only be accurately re-originated by access to the equipment, software and 
parameters used in creating the original design. 
Hash 
A mathematical formula that converts a message of any length into a unique fixed-length 
string of digits known as “message digest” that represents the original message. A hash is 
a one-way function, that is, it is infeasible to reverse the process to determine the original 
message. Also, a hash function will not produce the same message digest from two 
different inputs.  
Heat-sealed laminate 
A laminate designed to be bonded to the biographical data page of a passport book by the 
application of heat and pressure. 
 
 


 
16 
Machine Readable Travel Documents 
 
Holder 
A person possessing an MRTD, submitting a biometric sample for verification or 
identification whilst claiming a legitimate or false identity. A person who interacts with a 
biometric system to enroll or have one’s own identity checked. 
ICAO Public Key 
Directory 
The central database serving as the repository of Document Signer Certificates, CSCA 
Master Lists, Country Signing CA Link Certificates and Certificate Revocation Lists issued 
by Participants, together with a system for their distribution worldwide, maintained by ICAO 
on behalf of Participants in order to facilitate the validation of data in eMRTDs. 
Identification/Identify 
The one-to-many process of comparing a submitted biometric sample against all of the 
biometric reference templates on file to determine whether it matches any of the templates 
and, if so, the identity of the eMRTD holder whose template was matched. The biometric 
system using the one-to-many approach is seeking to find an identity amongst a database 
rather than verify a claimed identity. Contrast with “Verification”. 
Identification card 
(ID-card) 
A card used as an identity document. 
Identifier 
A unique data string used as a key in the biometric system to name a person’s identity and 
its associated attributes. An example of an identifier would be an MRTD number. 
Identity 
The collective set of distinct personal and physical features, data and qualities that enable 
a person to be definitively identified from others. In a biometric system, identity is typically 
established when the person is registered in the system through the use of so-called 
“breeder documents” such as birth certificate and citizenship certificate. 
Identity Document 
Document used to identify its holder and issuer, which may carry data required as input for 
the intended use of the document. 
Image 
A representation of a biometric as typically captured via a video, camera or scanning 
device. For biometric purposes, this is stored in digital form. 
Impostor 
A person who applies for and obtains a document by assuming a false identity, or a person 
who alters one’s own physical appearance to represent himself as another person for the 
purpose of using that person’s document. 
Index marks 
These marks are printed on the outside edge of each page in consecutive order starting 
from the top on the first page to a lower position on the following page and so on. The 
register mark of the last page appears at the bottom. This printing method leads to the 
appearance of a continuous stripe on the edge of the passport. Any page that has been 
removed will register as a gap. When printed in UV colour, this stripe becomes visible only 
under UV light. Also called collation marks. 
Infra-red drop-out ink 
An ink that forms a visible image when illuminated with light in the visible part of the 
spectrum and which cannot be detected in the infrared region. 
Infra-red ink 
An ink that is visible in the infrared light spectrum. 
Initialization  
(of a smart card) 
The process of populating persistent memory (EEPROM, etc.) with data that are common 
to a large number of cards while also including a minimal amount of card unique items 
(e.g. ICC serial number and Personalization keys). 
Inspection 
The act of a State or organization examining an MRTD presented to it by a traveller (the 
MRTD holder) and verifying its authenticity. 
 
 


 
Part 1.    Introduction 
17 
 
Inspection system 
A system used for inspecting MRTDs by any public or private entity having the need to 
validate the MRTD, and using this document for identity verification, e.g. border control 
authorities, airlines and other transport operators, financial institutions.  
Intaglio 
A printing process used in the production of security documents in which high printing 
pressure and special inks are used to create a relief image with tactile feel on the surface 
of the document. 
Integrated Circuit (IC) 
Electronic component designed to perform processing and/or memory functions.  
Integrated Circuit Card 
(IC card, ICC) 
A card into which one or more ICs have been inserted.  
Integrity 
The ability to confirm that the Logical Data Structure and its components have not been 
altered from those created by the issuing State or organization. 
Inter eye distance 
Length of the line connecting the eye centres of the left and right eye. 
Interface 
A standardized technical definition of the connection between two components.  
Interface device  
Any terminal, communication device or machine to which the ICC is connected during 
operation. 
Interoperability 
The ability of several independent systems or sub-system components to work together. 
Iris (printing) 
See: Rainbow Printing. 
Issuer 
Organization that issues MRTDs. 
Issuer data block 
A series of Data Groups that are written to the optional capacity expansion technology by 
the issuing State or organization. 
Issuing authority 
The entity accredited for the issuance of an MRTD to the rightful holder. 
Issuing State 
The country issuing the MRTD. 
Issuing organization 
Organization authorized to issue an official MRTD (e.g. the United Nations Organization, 
issuer of the laissez-passer). 
JPEG and JPEG2000 
Standards for the data compression of images, used particularly in the storage of facial 
images. 
Key exchange 
The process for getting session keys into the hands of the conversants.  
Key management 
The process by which cryptographic keys are provided for use between authorized 
communicating parties.  
Key pair 
A pair of digital keys — one public and one private — used for encrypting and signing 
digital information.  
Label 
A self-adhesive sticker that is used as the data page within the passport. This is not a 
generally recommended practice, particularly for longer-term validity documents. 
Laissez-passer 
A document, generally similar to a passport, issued under the auspices of a supranational 
entity (e.g. United Nations). 
Laminate 
A clear material, which may have security features designed to be securely bonded to 
protect the biographical data or other page of the document. 


 
18 
Machine Readable Travel Documents 
 
Laser engraving 
A process whereby personalized data are “burned” into the substrate with a laser. The 
data may consist of text, portraits and other security features.  
Laser perforation 
A process whereby numbers, letters or images are created by perforating the substrate 
with a laser. 
Latent image 
A hidden image formed within a relief image that is composed of line structures which vary 
in direction and profile resulting in the hidden image appearing at predetermined viewing 
angles, achieved by intaglio printing. 
Lenticular Feature 
Security feature in which a lens structure is integrated in the surface of the document or 
used as a verification device.  
Level 1 inspection 
Cursory examination for rapid inspection at the point of usage (easily identifiable visual or 
tactile features). 
Level 2 inspection 
Examination by trained inspectors with simple equipment. 
Level 3 inspection 
Inspection by forensic specialists. 
Live capture 
The process of capturing a biometric sample by an interaction between an MRTD holder 
and a biometric system. 
Locked (chip) 
After personalization, the chip MUST be locked. This means that personalization 
commands can no longer be executed , and personalization data can no longer be written 
to the chip. Only after successful execution of an authentication mechanism (TA) can data 
be written to the chip. A locked chip cannot be ”unlocked”. 
Logical Data Structure 
(LDS) 
The Logical Data Structure describes how data are stored and formatted in the contactless 
IC of an eMRTD. 
Machine Assisted 
Document  
Verification 
A process using a device to assist in the verification of the authenticity of the document in 
respect to data and/or security.  
Machine Readable 
Official Travel  
Document (MROTD) 
A document, usually in the form of a card of TD1 or TD2 size, that conforms to the 
specifications of Doc 9303-5 and Doc 9303-6 and may be used to cross international 
borders by agreement between the States involved.  
Machine Readable 
Passport (MRP) 
A passport conforming with the specifications contained in Doc 9303-4. Normally 
constructed as a TD3 size book containing pages with information on the holder and the 
issuing State or organization and pages for visas and other endorsements. Machine 
readable information is contained in two lines of OCR-B text, each with 44 characters.  
Machine Readable 
Travel Document 
(MRTD) 
Official document, conforming with the specifications contained in Doc 9303, issued by a 
State or organization which is used by the holder for international travel (e.g. MRP, MRV, 
MROTD) and which contains mandatory visual (eye readable) data and a separate 
mandatory data summary in a format which is capable of being read by machine. 
Machine Readable 
Visa (MRV) 
A visa conforming with the specifications contained in Doc 9303-7. The MRV is normally 
attached to a visa page in a passport. 
Machine Readable 
Zone (MRZ) 
Fixed dimensional area located on the MRTD, containing mandatory and optional data 
formatted for machine reading using OCR methods. 
 
 


 
Part 1.    Introduction 
19 
 
Machine-verifiable 
biometric feature 
A unique physical personal identification feature (e.g. facial image, fingerprint or iris) stored 
electronically in the chip of an eMRTD. 
Magnification distortion 
Image imperfection where the degree of magnification varies with the distance from the 
camera and the depth of the face. 
Master key 
Root of the derivation chain for keys.  
Master List 
A Master List is a digitally signed list of CSCA certificates that are ”trusted” by the 
Receiving State that issued the Master List (see Doc 9303-12). 
Master List Signer 
An entity that digitally signs a Master List of CSCA certificates. The Master List Signer is 
authorized by its national CSCA to perform this function through the issuance of a Master 
List Signer certificate. 
Match/Matching 
The process of comparing a biometric sample against a previously stored template and 
scoring the level of similarity. A decision to accept or reject is then based upon whether 
this score exceeds the given threshold. 
Message 
The smallest meaningful collection of information transmitted from sender to receiver. This 
information may consist of one or more card transactions or card transaction-related 
information. 
Message Authentication 
Code (MAC) 
A MAC is a message digest appended to the message itself. The MAC cannot be 
computed or verified unless a secret is known. It is appended by the sender and verified by 
the receiver, which is able to detect a message falsification.  
Metallic ink 
Ink exhibiting a metallic-like appearance. 
Metameric inks 
A pair of inks formulated to appear to be the same colour when viewed under specified 
conditions, normally daylight illumination, but which are a mismatch at other wavelengths. 
Microprint 
Printed text or symbols smaller than 0.25 mm/0.7 pica points. 
Moiré pattern 
Artefact resembling a wavy pattern caused by photographing a scene or object containing 
repetitive details (e.g. lines, dots, etc.) that exceed the sensor resolution of the camera. 
Morphing 
Image manipulation technique where two or more subjects’ faces are morphed or blended 
together to form a single face in a photograph. 
MP 
Measurement Pattern side length: the intensity measurement zones have a square shape 
and a size of 30% inter eye distance; they are used for measuring the lighting intensity on 
cheeks, forehead, and chin. 
MRP data page 
A fixed-dimensional page within the MRP containing a standardized presentation of visual 
and machine readable data.  
Multiple biometric 
The use of more than one biometric. 
Non-volatile memory 
A semiconductor memory that retains its content when power is removed (i.e. ROM, 
EEPROM). 
One-to-a-few 
A hybrid of one-to-many identification and one-to-one verification. Typically, the one-to-a-
few process involves comparing a submitted biometric sample against a small number of 
biometric reference templates on file. It is commonly referred to when matching against a 
“watch list” of persons who warrant detailed identity investigation or are known criminals, 
terrorists, etc. 


 
20 
Machine Readable Travel Documents 
 
One-to-many 
Synonym for “Identification”. 
One-to-one 
Synonym for “Verification”. 
Operating system 
A programme that manages the various application programmes used by a computer. 
Optically Variable Device 
(OVD) 
Security Feature displaying different colours or image appearance depending on viewing 
angle or verification conditions.  
Optically Variable 
Feature (OVF) 
An image or feature whose appearance in colour and/or design changes dependent upon 
the angle of viewing or illumination. Examples are: features including diffraction structures 
with high resolution (diffractive optically variable image device/DOVID), holograms, colour-
shifting inks (e.g. ink with optically variable properties) and other diffractive or reflective 
materials.  
Out-of-band 
Refers to communications that occur outside of a previously established communication 
method or channel. 
Overlay 
An ultra-thin film or protective coating that may be applied to the surface of a document in 
place of a laminate. 
Padding 
Appending extra bits to either side of a data string up to a predefined length. 
Parallax 
Displacement or difference in the apparent position of an object viewed along two different 
lines of sight, measured by the angle or semi-angle of inclination between those two lines. 
Penetrating 
numbering ink 
Ink containing a coloured component, which penetrates deep into a substrate. 
Personal Identification 
Number (PIN) 
A numeric security code used as a mechanism for local one-to-one verification with the 
purpose to ascertain whether the cardholder is in fact the natural person authorized to 
access or use a specific service such as the right to unlock certain information on the card. 
Personalization 
The process by which the portrait, signature and biographical data are applied to the 
document. 
Phosphorescent ink 
Ink containing a pigment that glows when exposed to light of a specific wavelength, the 
reactive glow remaining visible and then decaying after the light source is removed. 
Photo booth 
Automated system for digitally capturing identity photographs in either public or office 
environments; it encloses the subject in a highly controlled lighting environment and 
consists of a camera, lighting and peripheral devices, such as printers; it has entrances on 
one or both sides with reflective curtains protecting against ambient light. 
Photochromic ink 
An ink that undergoes a reversible colour change when exposed to light of a specified 
wavelength. 
Photo kiosk 
Semi-automated system for digitally capturing identity photographs in a counter-type 
environment; it consists of camera and lighting and usually has a separate panel placed 
behind the subject to provide the required background but is otherwise open. 
Photo-substitution 
A type of forgery in which the portrait in a document is substituted for a different one after 
the document has been issued. 
Physical visa 
A foil type travel document placed within the traveller’s passport. 
 
 


 
Part 1.    Introduction 
21 
 
Physical security 
The range of security measures applied during production and personalization to prevent 
theft and unauthorized access to the process. 
PKD participant 
An ICAO Member State or other entity issuing or intending to issue eMRTDs that follows 
the arrangements for participation in the ICAO PKD. 
Portrait 
A visual representation of the facial image of the holder of the MRTD in printed and 
electronically stored manner. 
Presentation attack 
Presentation of an artefact or human characteristic to the biometric capture subsystem in a 
fashion that could interfere with the intended policy of the biometric system. 
Presentation attack 
detection 
Automated determination of a presentation attack. 
Private Key 
The private component of an integrated asymmetric key pair (known only to the user), 
employed in public key cryptography in decrypting or signing information.  
Probe 
The biometric sample of the enrollee whose identity is sought to be established. 
Public Key 
The public component of an integrated asymmetric key pair, used in encrypting or verifying 
information.  
Public key certificate 
The public key information of an entity signed by the certification authority and thereby 
rendered unforgettable.  
Public key cryptography 
A form of asymmetric encryption where all parties possess a pair of keys, one private and 
one public, for use in encryption and digital signing of data.  
Public Key Infrastructure 
(PKI) 
A set of policies, processes and technologies used to verify, enrol and certify users of a 
security application. A PKI uses public key cryptography and key certification practices to 
secure communications.  
Public key system 
A cryptographic method using pairs of keys, one of which is private and one is public. If 
encipherment is done using the public key, decipherment requires application of the 
corresponding private key and vice versa.  
Radial distortion 
Image imperfection where the degree of magnification varies with the distance from the 
optical axis. 
Rainbow printing  
(iris or split fountain  
printing) 
A technique whereby two or more colours of ink are printed simultaneously on a press to 
create a continuous merging of the colours similar to the effect seen in a rainbow. Also 
called prismatic, or iris printing. 
Random access 
A means of storing data whereby specific items of data can be retrieved without the need 
to sequence through all the stored data. 
Random Access Memory 
(RAM) 
A volatile memory randomly accessible used in the IC that requires power to maintain 
data.  
Reactive inks 
Inks that contain security reagents to guard against attempts at tampering by chemical 
erasure (deletion), such that a detectable reaction occurs when bleach and solvents come 
into contact with the document. 
Read only memory 
(ROM) 
Non-volatile memory that is written once, usually during IC production. It is used to store 
operating systems and algorithms employed by the semiconductor in an integrated circuit 
card during transactions.  


 
22 
Machine Readable Travel Documents 
 
Read range 
The maximum practical distance between the contactless IC with its antenna and the 
reading device. 
Receiver data block 
A series of Data Groups that are written to the optional capacity expansion technology by a 
receiving State or authorized receiving organization. 
Receiving State 
The country inspecting the holder’s MRTD. 
Reference data set 
The visual-, IR-, and UV-pictures of a reference document define the check routines for a 
corresponding document model. 
Reference document set 
The set of documents, whose reference data sets are used to define check routines. 
Registration 
The process of making a person’s identity known to a biometric system, associating a 
unique identifier with that identity, and collecting and recording the person’s relevant 
attributes into the system. 
Registration Authority 
(RA) 
A person or organization responsible for the identification and authentication of an 
applicant for a digital certificate. An RA does not issue or sign certificates.  
Relief (3-D) design 
(Medallion) 
A security background design incorporating an image generated in such a way as to create 
the illusion that it is embossed or debossed on the substrate surface. 
Response 
A message returned by the slave to the master after the processing of a command 
received by the slave. 
Rivest, Shamir and 
Adleman (RSA) 
Asymmetric algorithm invented by Ron Rivest, Adi Shamir and Len Adleman. It is used in 
public-key cryptography and is based on the fact that it is easy to multiply two large prime 
numbers together, but hard to factor them out of the product.   
Score 
A number on a scale from low to high, measuring the success that a biometric probe 
record (the person being searched for) matches a particular gallery record (a person 
previously enrolled). 
Secondary image 
A repeat image of the holder’s portrait reproduced elsewhere in the document by whatever 
means. 
Secure hash algorithm 
(SHA) 
Hash function specified by NIST and published as a federal information-processing 
standard FIPS-180.  
Secured message 
A message that is protected against illegal alteration or origination.  
Security thread 
A thin strip of plastic or other material embedded or partially embedded in the substrate 
during the paper manufacturing process. The strip may be metallized or partially 
de-metallized. 
See-through register 
(front-to-back) 
See: front-to-back register. 
Sensitive Data 
These data are considered to be more privacy sensitive than non-sensitive data. Access to 
sensitive data SHOULD be more restricted. Doc 9303-11 specifies Terminal Authentication 
as an interoperable mechanism for accessing sensitive data. If no interoperability is 
required, other mechanisms can be used. 
Shadow Image 
Used as a synonym to Ghost Image: A second representation of the holder’s portrait on 
the document, reduced in contrast and/or saturation and/or size. 


 
Part 1.    Introduction 
23 
 
Sheet 
The individual piece of substrate in a passport that comprises more than one passport 
page. 
Size 1 machine 
readable official 
travel document (TD1) 
A card with nominal dimensions guided by those specified for the ID-1 type card 
(ISO/IEC 7810) (excluding thickness). 
Size 2 machine 
readable official 
travel document (TD2) 
 
A card or label conforming with the dimensions defined for the ID-2 type card 
(ISO/IEC 7810) (excluding thickness). 
Skimming 
Electronically reading the data stored in the contactless IC without authorizing this reading 
of the document. 
Small size  
(Format-B)  
machine readable 
visa (MRV-B) 
An MRV conforming with the dimensional specifications contained in Doc 9303-7, sized to 
maintain a clear area on the passport visa page.  
Spoofing 
Faking the sending address of a transmission to gain illegal entry into a secure system.  
 
Note.— Impersonating, masquerading, piggybacking, and mimicking are forms of spoofing.
Steganography 
An image or information encoded or concealed within a primary visual image. 
Structure feature 
A structure feature involves the incorporation of a measurable structure into or onto the 
MRTD. The presence of the structure may be detected and measured by the detection 
machine.  
Subject 
Person  to be displayed on the portrait; this person is intended to be the holder of the 
MRTD. 
Substance feature 
A substance feature involves the incorporation into the MRTD of a material, which would 
not normally be present and is not obviously present on visual inspection. The presence of 
the material may be detected by the presence and magnitude of a suitable property of the 
added substance.  
Symmetric algorithm 
A type of cryptographic operation using the same key or set of keys for encryption of plain 
text and decryption of associated cipher text. 
Synthetic 
A non-paper based material used for the biographical data page or cards. The term 
“synthetic” is used synonymously for “plastic”, which encompasses materials like 
polycarbonate, PET and similar materials and combinations thereof. 
System 
A specific IT installation, with a particular purpose and operational environment.  
System integration 
The process by which cardholder-facing, internal and partner-facing systems and 
applications are integrated with each other.  
 
 
 


 
24 
Machine Readable Travel Documents 
 
System security policy 
The set of laws, rules and practices that regulate how sensitive information and other 
resources are managed, protected and distributed within a specific system.  
Tactile feature 
A surface feature giving a distinctive “feel” to the document. 
(Feature) Tag 
A byte that uniquely identifies a document feature. The mapping between feature tags and 
features must be specified in a profile. 
Taggant 
A not-naturally occurring substance that can be added to the physical components of an 
MRTD, and is typically a Level 3 feature, requiring special equipment for detection. 
Tagged ink 
Inks containing compounds that are not naturally occurring substances and which can be 
detected using special equipment. 
Tamper resistance 
The capability of components within a document to withstand alteration. 
Template/Reference 
template 
Data that represent the biometric measurement of an enrollee used by a biometric system 
for comparison against subsequently submitted biometric samples. 
Template size 
The amount of computer memory taken up by the biometric data. 
Thermochromic ink 
An ink thatundergoes a reversible colour change when the printed image is exposed to a 
specific change in temperature. 
Threshold 
A “benchmark” score. The comparison of the result value of a check routine to a 
corresponding threshold leads to a Passed-/Failed-decision. 
Token image 
A portrait of the holder of the MRTD, typically a full frontal image, which has been adjusted 
in size to ensure a fixed distance between the eyes. It may also have been slightly rotated 
to ensure that an imaginary horizontal line drawn between the centres of the eyes is 
parallel to the top edge of the portrait rectangle if this has not been achieved when the 
original portrait was taken or captured.  
Trust Anchor 
In cryptographic systems with hierarchical structure, this is an authoritative entity for which 
trust is assumed and not derived. 
Usual Mark 
Symbol that replaces a holder’s written signature in case the holder is not able to sign. 
UV dull substrate 
A substrate that exhibits no visibly detectable fluorescence when illuminated with UV light. 
Validation 
The process of demonstrating that the system under consideration meets in all respects 
the specification of that system. 
Variable laser image 
A feature generated by laser engraving or laser perforation displaying changing 
information or images dependent upon the viewing angle. 
Verification/verify 
Biometrics: The process of comparing a submitted biometric sample against the biometric 
reference template of a single enrollee whose identity is being claimed, to determine 
whether it matches the enrollee’s template. Contrast with “Identification”. 
 
Machine Authentication: A verification describes the application of a check routine to a live 
data set of a document model. The result of a verification is often provided by a numeric 
result value. 
Visa Signer (VS) 
The authority that receives data from a visa personalization system and that uses a VS 
certificate and the corresponding private key to encode and sign a visible digital seal. 


 
Part 1.    Introduction 
25 
 
Visa Signer Certificate 
A certificate containing information identifying the entity that signed a visible digital seal on 
a visa, and containing the public key corresponding to the private key with which the 
signature was created. 
Visa Validation Authority 
(VVA) 
The authority that validates a visible digital seal based on a visa based on a validation 
policy. 
Visible Digital Seal (VDS) A cryptographically signed data structure containing document features, encoded as a 2D 
bar code and printed on a document. 
Visual inspection 
zone (VIZ) 
Those portions of the MRTD (data page in the case of MRP) designed for visual 
inspection, i.e. front and back (where applicable), not defined as the MRZ. 
Watermark 
A custom design, typically containing tonal gradation, formed in the paper or other 
substrate during its manufacture, created by the displacement of materials therein, and 
traditionally viewable by transmitted light. 
Wavelet Scalar 
Quantization (WSQ) 
A means of compressing data used particularly in relation to the storage of fingerprint 
images. 
Windowed or 
Transparent feature 
Security feature created by the construction of the substrate, whereby part of the substrate 
is removed or replaced by transparent material, which can incorporate additional security 
features such as lenses or tactile elements. 
X.509 v3 certificate 
The internationally recognized electronic document used to prove identity and public key 
ownership over a communication network. It contains the issuer’s name, user’s identifying 
information, and issuer’s digital signature. 
Zone 
An area containing a logical grouping of data elements on the MRTD. Seven (7) zones are 
defined for MRTDs. 
 
 
4.3    Key Words 
 
Key words are used to signify requirements. 
 
The key words “MUST”, “MUST NOT”, “REQUIRED”, “SHALL”, “SHALL NOT”, “SHOULD”, “SHOULD NOT”, 
“RECOMMENDED”, “MAY”, and “OPTIONAL” used in capitalized form in Doc 9303 are to be interpreted as described in 
[RFC 2119]: 
 
MUST 
This word, or the terms “REQUIRED” or “SHALL”, means that the definition is an 
absolute requirement of the specification. 
MUST NOT 
This phrase, or the phrase “SHALL NOT”, means that the definition is an absolute 
prohibition of the specification. 
SHOULD 
This word, or the adjective “RECOMMENDED”, means that there may exist valid 
reasons in particular circumstances to ignore a particular item, but the full implications 
must be understood and carefully weighed before choosing a different course. 
SHOULD NOT 
This phrase, or the phrase “NOT RECOMMENDED” means that there may exist valid 
reasons in particular circumstances when the particular behaviour is acceptable or even 
useful, but the full implications should be understood and the case carefully weighed 
before implementing any behaviour described with this label. 


 
26 
Machine Readable Travel Documents 
 
MAY 
This word, or the adjective “OPTIONAL”, means that an item is truly optional. One user 
may choose to include the item because a particular application requires it or because 
the user feels that it enhances the application while another user may omit the same 
item. An implementation that does not include a particular option MUST be prepared to 
interoperate with another implementation which does include the option, though perhaps 
with reduced functionality. In the same vein an implementation that does include a 
particular option MUST be prepared to interoperate with another implementation which 
does not include the option (except, of course, for the feature the option provides). 
CONDITIONAL 
The usage of an item is dependent on the usage of other items. It is therefore further 
qualified under which conditions the item is REQUIRED or RECOMMENDED. This is an 
additional key word used in Doc 9303 (not part of RFC 2119). 
 
Guidance in the use. Imperatives of the type defined here must be used with care and sparingly. In particular, they 
MUST be used only where it is actually required for interoperation or to limit behaviour that has potential for causing 
harm (e.g. limiting retransmissions). For example, they must not be used to try to impose a particular method on 
implementers where the method is not required for interoperability. 
 
Security considerations. These terms are frequently used to specify behaviour with security implications. The effects on 
security of not implementing a MUST or SHOULD, or doing something the specification says MUST NOT or SHOULD 
NOT be done, may be very subtle. Document authors should take the time to elaborate the security implications of not 
following recommendations or requirements, as most implementers will not have had the benefit of the experience and 
discussion that produced the specification. 
 
In case OPTIONAL features are implemented, they MUST be implemented as described in Doc 9303.  
 
In Doc 9303, the appendices are informative. If one claims compliancy to an (informative) appendix, the key words used 
in that appendix MUST be respected as specified. 
 
 
4.4    Object Identifiers 
 
In Parts 9303-10, 9303-11, and 9303-12, ICAO Object Identifiers are specified. This paragraph lists these actual ICAO 
Object Identifiers: 
 
-- ICAO security framework 
id-icao OBJECT IDENTIFIER::={joint-iso-itu-t(2) international(23) icao(136)} 
 
id-icao-mrtd OBJECT IDENTIFIER ::= {id-icao 1} 
 
id-icao-mrtd-security OBJECT IDENTIFIER ::= {id-icao-mrtd 1} 
 
-- LDS security object 
id-icao-mrtd-security-ldsSecurityObject OBJECT IDENTIFIER ::= {id-icao-mrtd-
security 1} 
 
-- CSCA master list 
id-icao-mrtd-security-cscaMasterList 
OBJECT 
IDENTIFIER 
::= 
{id-icao-mrtd-
security 2}  
 
id-icao-mrtd-security-cscaMasterListSigningKey OBJECT IDENTIFIER ::= {id-icao-
mrtd-security 3} 


 
Part 1.    Introduction 
27 
 
-- Active Authentication protocol 
id-icao-aaProtocolObject OBJECT IDENTIFIER ::= {id-icao-mrtd-security 5} 
 
-- CSCA name change 
id-icao-mrtd-security-extensions OBJECT IDENTIFIER ::= {id-icao-mrtd-security 
6} 
 
id-icao-mrtd-security-extensions-nameChange OBJECT IDENTIFIER ::= {id-icao-
mrtd-security-extensions 1} 
 
-- document type list, see TR “LDS and PKI Maintenance” 
id-icao-mrtd-security-extensions-documentTypeList OBJECT IDENTIFIER ::= {id-
icao-mrtd-security-extensions 2} 
 
-- Deviation List Base Object identifiers 
id-icao-mrtd-security-DeviationList OBJECT IDENTIFIER ::= {id-icao-mrtd-
security 7} 
 
id-icao-mrtd-security-DeviationListSigningKey OBJECT IDENTIFIER ::= {id-icao-
mrtd-security 8} 
 
id-Deviation-CertOrKey OBJECT IDENTIFIER ::= {id-icao-DeviationList 1} 
 
id-Deviation-CertOrKey-DSSignature OBJECT IDENTIFIER ::= {id-Deviation- 
CertOrKey 1} 
 
id-Deviation-CertOrKey-DSEncoding OBJECT IDENTIFIER ::= {id-Deviation- 
CertOrKey 2} 
 
id-Deviation-CertOrKey-CSCAEncoding OBJECT IDENTIFIER ::= {id-Deviation- 
CertOrKey 3} 
 
id-Deviation-CertOrKey-AAKeyCompromised OBJECT IDENTIFIER ::= {id- 
Deviation-CertOrKey 4} 
 
id-Deviation-LDS OBJECT IDENTIFIER ::= {id-icao-DeviationList 2} 
 
id-Deviation-LDS-DGMalformed OBJECT IDENTIFIER ::= {id-Deviation-LDS 1} 
 
id-Deviation-LDS-SODSignatureWrong OBJECT IDENTIFIER ::= {id-Deviation-LDS 3} 
 
id-Deviation-LDS-COMInconsistent OBJECT IDENTIFIER ::= {id-Deviation-LDS 4} 
 
id-Deviation-MRZ OBJECT IDENTIFIER ::= {id-icao-DeviationList 3} 
 
id-Deviation-MRZ-WrongData OBJECT IDENTIFIER ::= {id-Deviation-MRZ 1} 
 
id-Deviation-MRZ-WrongCheckDigit OBJECT IDENTIFIER ::= {id-Deviation-MRZ 2} 
 
id-Deviation-Chip OBJECT IDENTIFIER ::= {id-icao-DeviationList 4} 
 
id-Deviation-NationalUse OBJECT IDENTIFIER ::= {id-icao-DeviationList 5} 
 
 
 


 
28 
Machine Readable Travel Documents 
 
-- LDS2 Object Identifiers  
id-icao-mrtd-security-lds2 OBJECT IDENTIFIER ::= {id-icao-mrtd-security 9} 
 
id-icao-lds2Signer OBJECT IDENTIFIER ::= {id-icao-mrtd-security-lds2 8} 
 
id-icao-tsSigner OBJECT IDENTIFIER ::= {id-icao-lds2Signer 1} 
 
id-icao-vSigner OBJECT IDENTIFIER ::= {id-icao-lds2Signer 2} 
 
id-icao-bSigner OBJECT IDENTIFIER ::= {id-icao-lds2Signer 3} 
 
id-icao-lds2-travelRecords OBJECT IDENTIFIER ::= {id-icao-lds2 1} 
 
id-icao-lds2-travelRecords-application OBJECT IDENTIFIER ::= { id-icao-lds2-
travelRecords 1} 
 
id-icao-lds2-travelRecords-access OBJECT IDENTIFIER ::= { id-icao-lds2-
travelRecords 3} 
 
id-icao-lds2-visaRecords OBJECT IDENTIFIER ::= {id-icao-lds2 2} 
 
id-icao-lds2-visaRecords-application OBJECT IDENTIFIER ::= { id-icao-lds2-
visaRecords 1} 
 
id-icao-lds2-visaRecords-access OBJECT IDENTIFIER ::= { id-icao-lds2-visaRecords 
3} 
 
id-icao-lds2-additionalBiometrics OBJECT IDENTIFIER ::= {id-icao-lds2 3} 
 
id-icao-lds2- additionalBiometrics-application OBJECT IDENTIFIER ::= { id-icao-
lds2- additionalBiometrics 1} 
 
id-icao-lds2- additionalBiometrics-access OBJECT IDENTIFIER ::= { id-icao-lds2- 
additionalBiometrics 3} 
 
-- SPOC Object Identifiers  
id-icao-spoc OBJECT IDENTIFIER ::= {id-icao-mrtd-security 10} 
 
id-icao-spocClient OBJECT IDENTIFIER ::= {id-icao-spoc 1} 
 
id-icao-spocServer OBJECT IDENTIFIER ::= {id-icao-spoc 2} 
 
-- VDS Object Identifiers 
id-icao-vds OBJECT IDENTIFIER ::= { id-icao-mrtd-security 11} 
 
-- DTC Object Identifiers 
id-icao-dtc OBJECT IDENTIFIER ::= { id-icao-mrtd-security 12} 
 
id-icao-dtcSigner OBJECT IDENTIFIER ::= {id-icao-dtc 1} 
  
id-icao-dtcAttributes OBJECT IDENTIFIER ::= {id-icao-dtc 2} 
 
id-icao-dtcCapabilitiesInfo OBJECT IDENTIFIER ::= {id-icao-dtcAttributes 1} 
 
 
 


 
Part 1.    Introduction 
29 
 
-- EF.DIR Object Identifiers  
id-EFDIR OBJECT IDENTIFIER ::= { id-icao-mrtd-security 13} 
 
 
4.5    The Use of Notes 
 
While in ISO/IEC standards notes are informative, in Doc 9303 notes are part of the normative text and used to 
emphasize requirements or additional information. 
 
 
 
5.    GUIDANCE ON THE USE OF DOC 9303 
 
5.1    Doc 9303 Composition 
 
Doc 9303 is comprised of thirteen parts. Each part describes a specific aspect of the MRTD. The parts of Doc 9303 are 
composed in such way that the issuer of MRTDs can compose a complete set of relevant specifications, relevant to a 
specific type of MRTD (form factor). The relationship between these form factors and the parts of Doc 9303 is described 
in Section 5.2 of this Part 1. 
 
The following parts form the complete Doc 9303 specifications for Machine Readable Travel Documents: 
 
Part 1 — Introduction 
The document at hand is Part 1. 
 
Part 2 — Specifications for the Security of the Design, Manufacture and Issuance of MRTDs 
Part 2 provides mandatory and optional specifications for the precautions to be taken by travel document issuing 
authorities to ensure that their MRTDs, and their means of personalization and issuance to the rightful holders, are 
secure against fraudulent attack. Mandatory and optional specifications are also provided for the physical security to be 
provided at the premises where the MRTDs are produced, personalized and issued and for the vetting of personnel 
involved in these operations. 
 
Part 3 — Specifications common to all MRTDs 
Part 3 defines specifications that are common to TD1, TD2 and TD3 size Machine Readable Travel Documents (MRTDs) 
including those necessary for global interoperability using visual inspection and machine readable (optical character 
recognition) means. Detailed specifications applicable to each document type appear in Doc 9303, Parts 4 through 7. 
 
Part 4 — Specifications for Machine Readable Passports (MRPs) and other TD3 size MRTDs  
Part 4 defines specifications that are specific to TD3 size Machine Readable Passports (MRPs) and other TD3 size 
Machine Readable Travel Documents (MRTDs). For brevity, the term MRP has been used throughout Part 4 and, 
except where stated, all the specifications herein shall apply equally to all other TD3 size MRTDs. 
 
Part 5 — Specifications for TD1 size Machine Readable Official Travel Documents (MROTDs) 
Part 5 defines specifications that are specific to TD1 size Machine Readable Official Travel Documents (MROTDs). 
 
Part 6 — Specifications for TD2 size Machine Readable Official Travel Documents (MROTDs) 
Part 6 defines specifications that are specific to TD2 size Machine Readable Official Travel Documents (MROTDs). 
 
 
 


 
30 
Machine Readable Travel Documents 
 
Part 7 — Machine Readable Visas 
Part 7 defines the specifications for Machine Readable Visas (MRVs) which allow compatibility and global interchange 
using both visual (eye readable) and machine readable means. The specifications for visas can, where issued by a State 
and accepted by a receiving State, be used for travel purposes. The MRV shall, as a minimum, contain the data 
specified in a form that is legible both visually and by optical character recognition methods, as presented in Part 7.  
 
Part 7 contains specifications for both Format-A as well as Format-B types of visas, and is based on the Third Edition of 
Doc 9303, Part 2, Machine Readable Visas (2005). 
 
Part 8 — Emergency Travel Documents 
Part 8 provides guidance and specifications on Emergency Travel Documents (ETDs). The purpose of this guidance 
material is to promote a consistent approach in the issuance of ETDs in order to enhance the security of the document, 
protect the individual, promote greater confidence for border staff in handling ETDs at ports, and address the 
vulnerabilities presented by inconsistent practices and security features. Part 8 also specifies the use of Visible Digital 
Seals in ETDs. 
 
Part 9 — Deployment of Biometric Identification and Electronic Storage of Data in MRTDs 
Part 9 defines the specifications, additional to those for the basic MRTD set forth in Parts 3, 4, 5, 6, and 7 of Doc 9303, 
to be used by States wishing to issue an electronic Machine Readable Travel Document (eMRTD) capable of being 
used by any suitably equipped receiving State to read from the document a greatly increased amount of data relating to 
the eMRTD itself and its holder. This includes mandatory globally interoperable biometric data that can be used as an 
input to facial recognition systems, and, optionally, to fingerprint or iris recognition systems. The specifications require 
the globally interoperable biometric data to be stored in the form of high-resolution images. 
 
Part 10 — Logical Data Structure (LDS) for Storage of Biometrics and Other Data in the Contactless Integrated 
Circuit (IC) 
Part 10 defines a Logical Data Structure (LDS) for eMRTDs required for global interoperability. The contactless 
integrated circuit capacity expansion technology contained in an eMRTD selected by an issuing State or organization 
SHALL allow data to be accessible by receiving States. Part 10 defines the specifications for the standardized 
organization of these data. This requires the identification of all mandatory and optional Data Elements and a 
prescriptive ordering and/or grouping of Data Elements that SHALL be followed to achieve global interoperability for 
reading of details (Data Elements) recorded in the capacity expansion technology optionally included on an MRTD 
(eMRTD). 
 
Part 11 — Security Mechanisms for MRTDs 
Part 11 provides specifications to enable States and suppliers to implement cryptographic security features for Machine 
Readable Travel Documents (eMRTDs) offering ICC read-only access. 
 
Part 11 specifies cryptographic protocols to: 
 
• 
prevent skimming of data from the contactless IC; 
 
• 
prevent eavesdropping on the communication between the IC and reader; 
 
• 
provide authentication of the data stored on the IC based on the PKI described in Part 12, and provide 
authentication of the IC itself. 
 
Part 12 — Public Key Infrastructure for MRTDs 
Part 12 defines the Public Key Infrastructure (PKI) for the eMRTD application. Requirements for issuing States or 
organizations are specified, including operation of a Certification Authority (CA) that issues certificates and CRLs. 
Requirements for receiving States and their Inspection Systems validating those certificates and CRLs are also specified. 
 
 
 


 
Part 1.    Introduction 
31 
 
Part 13 — Visible Digital Seals for non-electronic documents 
Part 13 specifies a digital seal to ensure the authenticity and integrity of non-electronic documents in a comparatively 
inexpensive, but highly secure manner using asymmetric cryptography. The information on the non-electronic document 
is cryptographically signed, and the signature is encoded as a two-dimensional bar code and printed on the document 
itself.  
 
 
5.2    Relationship between MRTD Form Factors and relevant Doc 9303 Parts 
 
Table 1-1 describes which parts of Doc 9303 are relevant for specific types of MRTDs (form factors). 
 
 
Table 1-1.    Form factors cross-reference table 
 
 
Doc 9303 Part 
1 
2 
3 
4 
5 
6 
7 
8 
9 
10 
11 
12 
13 
TD3 size MRTD (MRP) 
√ 
√ 
√ 
√ 
 
 
 
 
 
 
 
 
 
TD3 size eMRTD (eMRP) 
√ 
√ 
√ 
√ 
 
 
 
 
√ 
√ 
√ 
√ 
 
TD1 size MROTD 
√ 
√ 
√ 
 
√ 
 
 
 
 
 
 
 
 
TD1 size eMROTD 
√ 
√ 
√ 
 
√ 
 
 
 
√ 
√ 
√ 
√ 
 
TD2 size MROTD 
√ 
√ 
√ 
 
 
√ 
 
 
 
 
 
 
 
TD2 size eMROTD 
√ 
√ 
√ 
 
 
√ 
 
 
√ 
√ 
√ 
√ 
 
MRV 
√ 
√ 
√ 
 
 
 
√ 
 
 
 
 
 
√ 
ETD 
√ 
√ 
√ 
 
 
 
 
√ 
 
 
 
 
√ 
 
 
 
 
6.    REFERENCES (NORMATIVE) 
 
Certain provisions of international Standards, referenced in this text, constitute provisions of Doc 9303. Where 
differences exist between the specifications contained in Doc 9303 and the referenced Standards, to accommodate 
specific construction requirements for machine readable travel documents, including machine readable visas, the 
specifications contained herein shall prevail. 
 
Annex 9 
Convention on International Civil Aviation (“Chicago Convention”), Annex 9 – Facilitation. 
 
RFC 2119 
RFC 2119, S. Bradner, “Key Words for Use in RFCs to Indicate Requirement Levels”, BCP 14, RFC2119, 
March 1997. 
 
 
 
 
— END — 

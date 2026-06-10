Approved by and published under the authority of the Secretary General
INTERNATIONAL CIVIL AVIATION ORGANIZATION
Doc 9303
Machine Readable Travel Documents
Part 8: Emergency Travel Documents
Eighth Edition, 2021


Approved by and published under the authority of the Secretary General
INTERNATIONAL CIVIL AVIATION ORGANIZATION
Doc 9303
Machine Readable Travel Documents
Part 8: Emergency Travel Documents
Eighth Edition, 2021


 
 
 
 
 
 
Published in separate English, Arabic, Chinese, French, Russian 
and Spanish editions by the 
INTERNATIONAL CIVIL AVIATION ORGANIZATION 
999 Robert-Bourassa Boulevard, Montréal, Quebec, Canada H3C 5H7 
 
 
Downloads and additional information are available at https://www.icao.int/publications/doc-series   
 
 
 
 
 
 
 
 
 
 
 
 
 
Doc 9303, Machine Readable Travel Documents 
Part 8 — Emergency Travel Documents 
Order No.: 9303P8 
ISBN 978-92-9265-374-3 (print version) 
ISBN 978-92-9275-988-9 (electronic version) 
 
 
 
 
 
© ICAO 2021 
 
All rights reserved. No part of this publication may be reproduced, stored in a 
retrieval system or transmitted in any form or by any means, without prior 
permission in writing from the International Civil Aviation Organization. 
 
 
 
6/2/26 
No. 2 
 


 
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
1 
20/3/24 
ICAO 
 
 
 
 
2 
6/2/26 
ICAO 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
The designations employed and the presentation of the material in this publication do 
not imply the expression of any opinion whatsoever on the part of ICAO concerning the 
legal status of any country, territory, city or area or of its authorities, or concerning the 
delimitation of its frontiers or boundaries. 
 


(v) 
TABLE OF CONTENTS 
Page 
1.
SCOPE .............................................................................................................................................. 
1 
2.
INTRODUCTION ................................................................................................................................ 
2 
2.1 
What is an Emergency Travel Document (ETD)? ................................................................. 
2 
2.2 
Problems arising from a lack of global standards or recommended best practices .............. 
2 
2.3 
Terminology used ................................................................................................................. 
3 
3.
BACKGROUND .................................................................................................................................. 
3 
4.
PRINCIPLES AND RECOMMENDED PRACTICES .......................................................................... 
3 
4.1 
Security/Issuance ................................................................................................................. 
3 
4.2 
Cost ...................................................................................................................................... 
6 
4.3 
Format .................................................................................................................................. 
7 
4.4 
Validity .................................................................................................................................. 
8 
4.5 
Document title/name ............................................................................................................. 
8 
4.6 
Post-issuance ....................................................................................................................... 
8 
5.
SUMMARY ......................................................................................................................................... 
9 
6.
USE OF OPTIONAL VISIBLE DIGITAL SEALS FOR ETDs ............................................................. 
13 
6.1 
Content and Encoding Rules ................................................................................................ 
13 
6.2 
Bar Code Signer and Seal Creation...................................................................................... 
14 
6.3 
Public Key Infrastructure (PKI) and Certificate Profiles ......................................................... 
14 
7.
REFERENCES (NORMATIVE) ........................................................................................................... 
14 
APPENDIX A TO PART 8.    ETD VALIDATION POLICY RULES (INFORMATIVE) .................................. 
App A-1 
APPENDIX B TO PART 8.    WORKED EXAMPLE VISIBLE DIGITAL SEAL FOR ETD (INFORMATIVE) ...  
App B-1 
______________________ 


 
 
 
 
 
 
1 
 
1.    SCOPE 
 
Part 8 of Doc 9303 provides guidance on Emergency Travel Documents (ETDs). The purpose of this guidance material 
is to promote a consistent approach in the issuance of ETDs in order to: 
 
● 
enhance the security of the document; 
● 
protect the individual; 
● 
promote greater confidence for border staff in handling ETDs at ports; and 
● 
address the vulnerabilities presented by inconsistent practices and security features. 
 
The guidance material covers travel documents issued by Issuing Authorities to travellers in distressed or unpredicted 
situations where it is not possible to issue a standard full-validity passport or travel document book and addresses the 
following areas: 
 
● 
security/issuance; 
● 
cost; 
● 
format; 
● 
validity; 
● 
document title/name; and 
● 
post-issuance. 
 
This guidance material does not cover: 
 
● 
standard full-validity passports delivered in emergency situations; 
● 
standard passports delivered with limited validity; 
● 
convention travel documents (which are covered under separate guidance on Issuing Machine Readable 
Convention Travel Documents for Refugees and Stateless Persons1), or “Laissez-passer” issued by the United 
Nations or the European Union; or 
● 
travel documents issued by humanitarian organizations such as the International Committee of the Red Cross 
(ICRC). 
 
However, it is intended that this guidance material can be used as a measure of best practice across all issuing 
organizations, such as humanitarian organizations who issue travel documents to stateless and displaced persons, and 
vulnerable migrants (including refugees and asylum seekers). Humanitarian organizations are encouraged to comply 
with its general principles to improve the standards and security of their documents. 
 
Part 8 also specifies the use of visible digital seals in ETDs, an optional feature which if implemented, shall be encoded 
as specified in this part. 
 
 
 
 
1.  See ICAO/UNHCR Guide for Issuing Machine Readable Convention Travel Documents for Refugees and Stateless Persons. 


 
2 
Machine Readable Travel Documents 
 
2.    INTRODUCTION 
 
 
2.1    What is an Emergency Travel Document (ETD)? 
 
Emergency travel documents are issued by States to travellers needing to travel urgently in distressed or unpredicted 
situations where it is not possible to issue a standard full-validity passport. 
 
Where the Issuing Authority considers that the person has a justified need to travel on urgent or compassionate grounds, 
a State may issue a specific type of document, commonly a passport-sized book (with fewer pages) or, depending on 
the circumstances outside the country of origin or in the country of issuance, a single sheet, with a restricted time and 
territorial validity, in order to facilitate scheduled travel back to the country of origin or to a named destination or to 
complete short-term travel. 
 
The terminology used for documents issued in these situations is confusing, and various terms are used by different 
Issuing Authorities for the same document. 
 
Some of the terms used are set out below, and it is not always clear what the specific term means: 
 
● 
emergency passport; 
● 
emergency travel document; 
● 
emergency travel certificate; 
● 
temporary passport; 
● 
temporary travel document; 
● 
provisional passport; and 
● 
provisional travel document. 
 
For the purposes of this guidance material, the term Emergency Travel Document (ETD) is used to describe this range 
of documents. This guidance material has been drafted to provide the flexibility for the Issuing Authority to determine the 
specific type of document to be issued (a limited-page passport-sized book or a single sheet), which can vary on a  
case-by-case basis. 
 
It is noted that the majority of Issuing Authorities do not issue ETDs to refugees or stateless persons or to anyone who is 
not a citizen of their own State/Member State. However, in exceptional, crisis situations, ETDs may be issued, usually in 
the form of a laissez-passer. As part of the provision of humanitarian aid, organizations such as the ICRC issue travel 
documents to asylum seekers, refugees, vulnerable migrants, and displaced or stateless persons in emergency 
situations. Such travel documents are issued for a one-way journey and after the completion of visa and travel 
requirements. They are issued only as a last resort when Issuing Authorities are not in a position to issue a full-validity 
passport or travel document. 
 
 
2.2    Problems arising from a lack of global standards or  
recommended best practices 
 
A specific ETD in a uniform format2 is issued by a number of Member States of the European Union to unrepresented 
EU citizens in third countries (i.e. EU citizens holding the nationality of a Member State which is not represented in a 
given third country), whose passports have been lost, stolen or destroyed or are temporarily unavailable. The document 
 
2.  96/409/CSFP: Decision of the Representatives of the Governments of the Member States, meeting within the Council of  
25 June 1996 on the establishment of an emergency travel document. 


 
Part 8.    Emergency Travel Documents 
3 
 
can be issued by any EU Member State under the authority of the Member State of nationality. It covers a single journey 
with a validity period barely longer than the minimum period required for completion of the journey for which it is issued. 
The purpose of the common-format EU ETD is to provide genuine assistance to unrepresented EU citizens in 
emergency situations in third countries. Some EU Member States issue their own national ETDs to unrepresented EU 
nationals for the same purpose. 
 
However, there were no global standards or recommended practices for the issuance of ETDs. Annex 9 — Facilitation of 
the Convention on International Civil Aviation (the “Chicago Convention”), provides an exemption for ETDs from ICAO 
minimum standards for MRTDs. As a result, varying standards are used by each individual Issuing Authority. There is no 
clear definition for ETDs, and they may have a lower security level attached to their deliverance. This can result in: 
 
● 
ETDs being issued routinely as a (standard) document to travel, especially in the cases where countries have 
centralized the production and issuance of their national passports to the home country when an application is 
made overseas (as this process is easier); 
● 
ETDs being targeted by potential fraudsters, considering the ETD’s limited security level; 
● 
Issuing Authorities being required to consider documentation that can be variable in terms of security and 
quality of issue; and 
● 
other humanitarian organizations that issue travel documents (for example to stateless and displaced persons, 
or vulnerable migrants including refugees and asylum seekers) not having guidance on issuance or acceptance 
by which to improve the standards and security of their documents. 
 
 
2.3    Terminology used 
 
It is recognized that States often issue more than one type of ETD to fulfil varying operational and policy requirements, 
and the terminology varies considerably. It is also recognized that, as a consequence of specific arrangements, in some 
cases a single, common-format ETD is issued by a number of States to citizens of any other of the States participating in 
such arrangements (e.g. the common-format ETD issued to unrepresented citizens of the EU). Therefore, this guidance 
material should establish a single name to be used (see also section 4.5). 
 
 
 
3.    BACKGROUND 
 
The Chicago Convention provides a mandate to develop and maintain Standards and Recommended Practices 
(SARPs). The SARPs developed are a means of ensuring that inspection authorities have a satisfactory level of 
confidence in the reliability of travel documents and can use their equipment to process presented travel documents in a 
globally interoperable manner. 
 
 
 
4.    PRINCIPLES AND RECOMMENDED PRACTICES 
 
 
4.1    Security/Issuance 
 
4.1.1 
Circumstances to issue ETDs 
 
Travellers may find that they are unable to obtain standard full-validity passports but need nevertheless to travel urgently. 
The issuance of ETDs by an Issuing Authority may be considered in relation to but not be limited to the following 
situations: 
 


 
4 
Machine Readable Travel Documents 
 
● 
emergency situation for the individual traveller (for example, a family illness; death of a relative) with 
inadequate time to apply for a standard full-validity passport, including urgent travel needs while a standard full-
validity passport has been lost, stolen or damaged/mutilated; 
● 
emergency situation abroad (for example, a conflict or natural disaster such as a flood or earthquake) and a 
need to travel home; 
● 
lost, stolen or damaged/mutilated passport while abroad; 
● 
contingency arrangements if a standard full-validity passport cannot be issued in-country; 
● 
deportation, removal, repatriation; and 
● 
unrepresented foreign nationals who cannot access their own consular services in case of emergency or are in 
personal emergency situations (for example, when their documents are lost, stolen, destroyed or inaccessible). 
 
The type of document issued in the above situations may not be the same in all cases. The traveller’s situation and the 
individual circumstances of each case should be taken into account when an Issuing Authority determines which travel 
document is most appropriate. The criteria for issuing an ETD should be made available on request to the traveller. 
 
ETDs are often issued in locations3 abroad4 where it is either impractical or inappropriate for an individual to apply for a 
standard full-validity passport. 
 
Ultimately, the type of travel document issued is dependent on the individual circumstances, the environment 
surrounding its issuance, and the practices of an Issuing Authority. In most cases, the security of the document often 
reflects the circumstances under which the ETDs are issued and the access to facilities and technology available at the 
time. 
 
4.1.2 
Issuance process of ETDs 
 
The issuance process of ETDs should stay as close as possible to that for standard MRTDs. In line with the Annex 9 
requirement for transparent processes, Issuing Authorities should define which steps of the issuance process can 
diverge, and under which circumstances. States of emergency may necessitate issuance of ETDs in less than ideal 
circumstances and at very short notice so it is important that issuing staff can be assured that they have the most robust 
process possible (given the circumstances). There may be different ways of achieving enhanced integrity in these 
situations: 
 
● 
Verification: It is recommended that the issuers satisfy themselves that proper checks are carried out against 
Interpol or other national databases wherever possible. Travel documents are only as secure as the identity 
assurance processes behind their production and issuance. 
 
 
3.  ETDs may be issued from a number of locations including but not limited to: 
 
Issuance overseas: 
i.  from an embassy, high commission or honorary consul; 
ii.  from a remote area in crisis, (e.g. mobile response unit) where the person issuing the documents must work in tandem with the 
person’s home office to ensure that all required eligibility and security procedures are met; 
iii.  from airports in crisis situations; and 
iv.  from a designated embassy, high commission or honorary consul of other countries where a special arrangement is in place. 
 
Issuance domestically: 
i.  from the airport; and 
ii.  from an office of the Issuing Authority. 
 
4.  There are examples of good practice whereby some States have special arrangements with partners to provide emergency 
services overseas through embassies, high commissions, honorary consuls or trusted third parties (private sector industry) in States 
where they do not have a presence. Although these partnerships are rare, this guidance material encourages States to explore this 
option on a bilateral basis. 


 
Part 8.    Emergency Travel Documents 
5 
 
● 
Enrolment/Application: It is recommended that details of the ETD application and of the document issued, are 
recorded on the applicant’s file for future reference. It is important that even (or perhaps especially) in cases of 
manual issuance this information forms part of the applicant’s case history. 
 
● 
Entitlement/Identity verification: It is recommended that, where possible, States request supporting identification 
documents to assist them in their decision to issue an ETD. Additionally, where biometric 
verification/identification may be used to support identity verification processes, States should make use of this. 
 
● 
Linking to the standard full-validity passport: Where a standard full-validity passport has previously been issued, 
it is recommended that States consider linking it to the ETD in order to establish the applicant’s case history 
and provide further identity assurance. This practice will also help ensure that the document is taken out of 
circulation at the final destination State (see section 4.6 on “post-issuance”). An alert flag may be raised for 
first-time applicants, where no previous passport record exists. It is advisable to keep record of all travel 
documents, including any ETDs, over a determined period of time. 
 
● 
Informing the applicant: It is recommended that applicants be informed of the need to apply for a standard full-
validity passport should they wish to travel at a future date. Applicants should also be made aware that Issuing 
Authorities may retain their ETD on arriving at the destination, depending on whether it has been issued for one 
journey or more than one. 
 
4.1.3 
Two types of ETDs 
 
There are two possible options when Issuing Authorities face the need to issue an ETD. Either they consider delivering: 
 
1. 
a (limited-page) passport-sized booklet; or 
2. 
a single-sheet travel document (normally a stand-alone A4-sized paper sheet or a fold-out document). 
 
The (limited-page) passport-sized booklet should be issued wherever possible and should comply with the relevant 
specifications in Doc 9303 relating to MRTDs. The advantages of issuing this type of booklet are: 
 
● 
the booklet can be personalized in a more secure manner than a single-sheet document; 
● 
it provides greater scope for inclusion of security features; 
● 
it offers more reliability because the inclusion of a Machine Readable Zone (MRZ) will ensure that the 
document can be swiped through a passport reader and automatically checked against watch lists and other 
systems; 
● 
it provides a broader acceptance/recognition level by other countries and international parties/entities; and 
● 
it entitles the holder to a wider range of travel options (although limited, the passport-sized document offers a 
longer validity and more pages than the single-sheet travel document valid for one trip only). 
 
In situations (for example, during a natural disaster or in a conflict situation) where it is not appropriate or practical to 
issue the (limited page) passport-sized MRTD booklet, it is also possible to produce/issue a single-sheet document. The 
advantages of issuing a single-sheet document in these types of situations are: 
 
● 
it may be issued in crisis situations where facilities to personalize a book are inaccessible or unavailable; 
● 
it may be quicker to personalize than the passport-sized book; 
● 
it may be a more cost-effective option; and 
● 
it will be subject to more scrutiny at borders. 
 
 


 
6 
Machine Readable Travel Documents 
 
4.1.4 
Principle 
 
Given the de facto circumstances, the most secure document that can be issued should be issued.5 
 
4.1.5 
Recommended best practice 
 
● 
A machine readable ETD is the preferred standard, primary document. 
● 
ETDs that exist in booklet form should have a limited number of pages (conform to its limited validity) and be 
consistent with the security features guidance contained in Doc 9303. 
● 
Effective 1 January 2026, machine readable booklet ETDs issued with a secondary document code shall use 
the document code ‘PE’. Effective 1 January 2028, all machine readable booklet ETDs shall be issued with the 
document code ‘PE’. The secondary document code refers to the second letter of the document code.6 
● 
States shall circulate specimen information to other States and concerned organizations such as airlines, 
including information on the design, security features and issuance procedures of ETDs.7 
● 
States should define that no person should hold more than one valid ETD concurrently. 
● 
An ETD should be issued as near to the date of travel as possible to ensure it is used for the specified purpose 
and exact journey for which it was issued. 
 
In cases where an MRTD ETD is not issued, the single-sheet travel document shall be issued instead, noting that: 
 
● 
Single-sheet ETDs should contain the minimum, basic security features, such as a watermark, security 
background printing or UV fluorescence ink or elements so as to counteract fraudsters' actions and to offer an 
adequate acceptance and recognition level. 
● 
The inclusion of a machine readable zone is an optional feature which, if implemented, shall be consistent with 
the technical specifications contained in Doc 9303, including document codes identifying the document type. 
Effective 1 January 2026, machine readable single-sheet ETDs issued with a secondary document code shall  
use the document code ‘PU’. Effective 1 January 2028, all machine readable single-sheet ETDs shall be issued 
with the document code ‘PU’. The secondary document code refers to the second letter of the document code.8 
● 
Whenever possible, receiving and/or transiting authorities should be informed about the travel plan of persons 
holding single-sheet ETDs, so as to ensure proper facilitation procedures (especially in case of transiting ports). 
● 
States shall circulate specimen information to other States and concerned organizations such as airlines, 
including information on the design, security features and issuance procedures of single-sheet ETDs. 
● 
States should define that no person should hold more than one valid ETD concurrently. 
● 
A single-sheet ETD should be issued as near to the date of travel as possible to ensure it is used for the 
specified purpose and exact journey for which it was issued. 
 
 
4.2    Cost 
 
The cost of issuing either type of ETD is a matter for the Issuing Authority, including any requirements on charging and 
fee waiving in its national legislation. The Issuing Authority should consider the level of charging at a rate that does not 
encourage the person to apply for an ETD rather than a standard full-validity passport. Also, the charge should be set at 
a level that discourages holders of standard full-validity passports from not taking sufficient care of their existing 
passport. The Issuing Authority may consider issuing an ETD free of charge, including in crisis situations (e.g. State of 
Emergency). Regardless of cost, in all cases the ETD should be issued only when all relevant checks have been 
completed. 
 
5.  Issuing Authorities may consider issuing a less secure document in conjunction with the receiving and/or transiting Authorities if the 
circumstances merit and justify this. 
6. Issuing States and organizations shall ensure machine readable booklet ETDs issued without the document code ‘PE’ expire before 
1 January 2038. Refer to Doc 9303-4 for further details regarding document codes. 
7.  Reference can be found on https://www.icao.int/icao-trip/publications - "Guide for Circulating Specimen Travel Documents" 
8. Issuing States and organizations shall ensure machine readable single-sheet ETDs issued without the document code ‘PU’ expire 
before 1 January 2038. Refer to Doc 9303-4 for further details regarding document codes. 
6/2/26 
No. 2 


 
Part 8.    Emergency Travel Documents 
7 
 
4.2.1 
Principle 
 
The charging structure within national frameworks for issuing ETDs should be clear, and applicants should be aware of 
the cost that will be applied. 
 
4.2.2 
Recommended best practice 
 
In the circumstances of a national or local crisis, the granting of an ETD may be free of charge. 
 
 
4.3    Format 
 
While there will always be the potential for situations to arise where it is impossible to produce the passport-sized 
machine readable booklet form of the ETD, this is to be regarded as the preferred standard primary document. Issuing 
Authorities should issue the most secure document that can be issued in the circumstances, while meeting all 
entitlement and security requirements. It is crucial that Issuing Authorities ensure the highest security level possible to 
deter fraudulent use. 
 
4.3.1 
Principle 
 
The document, if in booklet form, should be easily distinguishable from a standard full-validity passport but, as set out 
below, some format, security and design features should remain identical. 
 
4.3.2 
Recommended best practice 
 
Issuing Authorities should issue an ETD in a form that clearly distinguishes it from a standard full-validity passport.  
This may be a different-coloured cover and inner pages or the cover and pages might be the same but with an additional 
marking clearly indicating that they are different. It is recommended though that, for ease of recognition by border control 
authorities, a link be kept to the current standard passport. 
 
● 
It is recommended that there be fewer pages than in a standard full-validity passport to reflect the fact that 
these are short-term documents, preferably with a maximum of eight (8) visa/inner pages. 
● 
In accordance with Doc 9303, for the booklet form of the ETD, the photo, whether provided in paper or digital 
format, must be digitally printed in the ETD. Necessary measures shall be taken by the Issuing Authority or 
organization to ensure that the displayed photo is resistant to forgery and substitution. 
● 
Stick-on photos are not permitted in accordance with Doc 93039 in the booklet form of the ETD due to the ease 
with which stick-on photos can be removed. Given that ETDs may not contain the same or as many security 
safeguards or features as a standard full-validity passport, steps need to be taken to protect the ETD wherever 
possible. Consequently, the integration and printing of the photo into the ETD booklet should be a standard 
requirement given the widespread recognition of the weakness of stick-on photos. 
● 
The ETD should have a unique number printed pre-issuance which will enable an audit trail of which 
documents were issued to whom. This can be particularly important when documents are lost or stolen, either 
pre- or post-issuance. 
● 
To the extent possible single-sheet ETDs should incorporate and assimilate the same principle and best 
practices, noting that, where stick-on photos need to be used, Issuing Authorities should consider using 
sticker/vignette laminates, or wet and/or dry stamps on the single-sheet ETDs as a mitigating practice and to 
increase security. 
 
9.  In line with Doc 9303-4: “The use of affixed or stick-on portrait photos is not permitted and these shall not be used. Instead, the 
portrait image shall be integrated with the biodata page using a secure personalization technology.” 
6/2/26 
No. 2 


 
8 
Machine Readable Travel Documents 
 
4.4    Validity 
 
ETDs are issued for a variety of reasons, and it is no longer the case that they are used only for single journeys from 
one country back to the country of nationality, citizenship or residence. Many countries insist upon travellers having at 
least six (6) months’ validity in their travel documents in order to issue visas or give leave to enter. 
 
4.4.1 
Principle 
 
Issuing Authorities should restrict validity to the minimum period required consistent with the purpose for which the 
document was issued and in line with the security of the document. 
 
4.4.2 
Recommended best practice 
 
● 
ETDs in booklet form should be issued with an absolute maximum validity of twelve (12) months (including any 
six-month entry and visa requirements). 
● 
Single-sheet ETDs should be issued with a single journey restriction (which can include transit points). 
● 
All ETDs should have final destinations and fixed named transit points on the document, and these should 
reflect the ticketed route. 
● 
All ETDs should be replaced by a standard full-validity passport as soon as possible. (If time allows preferably 
during the validity of the ETD.) 
 
 
4.5    Document title/name 
 
In order to avoid confusion, the single term of “Emergency Travel Document (ETD)” should be used to describe this 
range of documents. This best reflects the idea of a distressed and unpredicted situation in an unequivocal manner. It 
thus mirrors the notions of urgent, critical, short-term and transitory. 
 
The term is also broad enough to be seen in the context of two different existing ETDs: a booklet format and a single-
sheet format. For the single-sheet ETD the words “single journey” should be inserted in the “validity” box. 
 
4.5.1 
Principle 
 
Issuing States or organizations should use a distinctive title or name on the ETDs so as to clearly identify the distressed 
and unpredicted situations in which such documents were issued (and to distinguish them from documents issued in 
situations where States choose to issue a regular passport or travel document book with limited validity, i.e., a temporary 
passport). 
 
4.5.2 
Recommended best practice 
 
● 
ETDs regardless of their format should be referred to as “Emergency Travel Documents” to clearly distinguish 
ETDs from standard full-validity passports and should include the word ”Emergency” in the title. 
● 
They can be issued in booklet or single-sheet format. 
● 
In case of the single-sheet format, they should mention “single journey” in the “validity” box. 
 
 
4.6    Post-issuance 
 
The practices for resolving used ETDs with issuance systems vary widely, particularly depending on whether or not 
documents need to be retained by the traveller in order to collect a standard full-validity passport, and also depending on 
whether ETDs are issued by a different ministry or department from that issuing standard full-validity passports. 
 


 
Part 8.    Emergency Travel Documents 
9 
 
4.6.1 
Principle 
 
Issuing States or organizations should take specific measures to prevent further use of post-use ETDs to minimize the 
chances of potential fraud. 
 
4.6.2 
Recommended best practice 
 
The document should be taken out of circulation at the border crossing point of the final destination, unless explicitly 
required or noted on the document by the Issuing Authorities.10 The document should ultimately be returned to the 
Issuing Authorities for physical cancellation and/or mutilation to prevent it being used for further travel by impostors or 
fraudsters. 
 
 
 
5.    SUMMARY 
 
The table below aims to emphasize the key drivers and the purpose for producing this guidance material, summarizing 
the scope, principles and best practice recommendations encompassed within it. 
 
KEY DRIVERS: To help promote security and improve traveller facilitation by: 
• 
minimizing fraud;  
• 
preventing potentially dangerous people from traveling;  
• 
removing potential vulnerabilities of Issuing Authorities. 
PURPOSE: To promote a consistent approach in the issuance of ETDs in order to: 
• 
enhance the security of the document;  
• 
protect the individual;  
• 
promote greater confidence for border staff in handling ETDs at ports;  
• 
address the vulnerabilities presented by inconsistent practices and security features. 
Scope 
Principles 
Recommended best practices 
Security/ 
Issuance 
1. 
Given the de facto circumstances,  
the most secure document that can be 
issued should be issued. 
i. 
A machine readable ETD is the preferred 
standard, primary document. 
ii. 
ETDs that exist in booklet form should 
have a limited number of pages (conform 
to its limited validity) and be consistent 
with the security features guidance 
contained in Doc 9303. 
iii. 
States shall circulate specimen 
information to other States and concerned 
organizations such as airlines, including 
information on the design, security 
features and issuance procedures of 
ETDs. 
 
 
10. For example, visa requirements (e.g. if an expired travel document contains a valid visa, the travel document, after invalidation, 
stays with its rightful holder). 
6/2/26 
No. 2 


 
10 
Machine Readable Travel Documents 
 
iv. 
States should define that no person 
should hold more than one valid ETD 
concurrently. 
v. 
An ETD should be issued as near to the 
date of travel as possible to ensure it is 
used for the specified purpose and 
journey for which it was issued. 
vi. 
In cases where an MRTD ETD is not 
issued, the single-sheet travel document 
shall be issued instead, noting that: 
vii. 
Single-sheet ETDs should contain 
minimum, basic security features, such as 
a watermark, security background printing 
or UV fluorescence ink or elements so as 
to counteract fraudsters' actions and to 
offer an adequate acceptance and 
recognition level; 
viii. 
Whenever possible, receiving and/or 
transiting authorities should be informed 
about the travel plan of persons holding 
single-sheet ETDs, so as to ensure proper 
facilitation procedures (especially in case 
of transiting ports); 
ix. 
States shall circulate specimen 
information to other States and concerned 
organizations such as airlines, including 
information on the design, security 
features and issuance procedures of 
single-sheet ETDs; 
x. 
States should define that no person 
should hold more than one valid ETD 
concurrently; 
xi. 
A single-sheet ETD should be issued as 
near to the date of travel as possible to 
ensure it is used for the specified purpose 
and journey for which it was issued. 
Cost 
2. 
The charging structure within national 
frameworks for issuing ETDs should be 
clear and applicants should be aware 
of the cost that will be applied. 
xii. 
In the circumstances of a national or local 
crisis, the granting of an ETD may be free 
of charge. 
Format 
3. 
The document, if in booklet form, 
should be easily differentiated from a 
standard full-validity passport but some 
format, security and design features 
should remain identical. 
xiii. 
Issuing Authorities should issue ETDs in a 
form that clearly distinguishes them from 
standard full-validity passports. This may 
be a different coloured cover and inner 
pages or the cover and pages might be 
the same but with an additional marking 
clearly indicating that they are different. 
 


 
Part 8.    Emergency Travel Documents 
11 
 
xiv. 
It is recommended though that, for ease 
of its recognition by border control 
authorities, a link be kept to the current 
standard passport. 
xv. 
It is recommended that there be fewer 
pages than in a standard full-validity 
passport to reflect the fact that these are 
short-term documents, preferably with a 
maximum of 8 visa/inner pages. 
xvi. 
In accordance with Doc 9303, for the 
booklet form of the ETD, the photo, 
whether provided in paper or digital 
format, must be digitally printed in the 
MRTD. Necessary measures shall be 
taken by the Issuing Authority or 
organization to ensure that the displayed 
photo is resistant to forgery and 
substitution. 
xvii. For the booklet form, stick-on photos are 
not permitted in accordance with Doc 
9303 due to the ease with which they can 
be removed. Given that ETDs may not 
contain the same or as many security 
safeguards or features as a standard full-
validity passport, steps need to be taken 
to protect the ETD wherever possible. 
Consequently, the integration and printing 
of the photo into the ETD booklet should 
be a standard requirement given the 
widespread recognition of the weakness 
of stick-on photos. 
xviii. The ETD should have a unique number 
printed pre-issuance to enable an audit 
trail of which documents were issued to 
whom. This can be particularly important 
where documents are lost or stolen, either 
pre- or post-issuance. 
xix. 
To the extent possible, single-sheet ETDs 
should incorporate and assimilate the 
same principle and best practices, noting 
that, where stick-on photos need to be 
used, Issuing Authorities should consider 
using sticker/vignette laminates, or wet 
and/or dry stamps on the single-sheet 
ETDs as a mitigating practice and to 
increase security. 


 
12 
Machine Readable Travel Documents 
 
Validity 
4. 
Issuing Authorities should restrict 
validity to the minimum period 
required, consistent with the purpose 
for which the document was issued 
and in line with the security of the 
document. 
xx. 
ETDs in booklet form should be issued 
with an absolute maximum validity of 12 
months (including any six-month entry 
and visa requirements). 
xxi. 
Single-sheet ETDs should be issued with 
a single journey restriction (which can 
include transit points). 
xxii. All ETDs should have final destinations 
and fixed named transit points on the 
document, and these should reflect the 
ticketed route. 
xxiii. All ETDs should be replaced by a 
standard full-validity passport as soon as 
possible (if time allows preferably during 
the validity of the ETD) with the standard 
robust application process being followed. 
Document 
title/name 
5. 
Issuing States or organizations should 
use a distinctive title or name on the 
ETDs so as to clearly identify the 
distressed and unpredicted situations 
in which such documents were issued 
(and to distinguish them from 
documents issued in situations where 
States choose to issue a regular 
passport or travel document book with 
limited validity, i.e., a temporary 
passport). 
xxiv. ETDs, regardless of their format, should 
be referred to as “Emergency Travel 
Documents” to clearly distinguish ETDs 
from standard full-validity passports and 
should include the word “Emergency” in 
the title. 
xxv. They can be issued in booklet or single-
sheet format. 
xxvi. In case of the single-sheet format, they 
should mention “single journey” in the 
“validity” box. 
Post-issuance 
6. 
Issuing States or organizations should 
take specific measures to prevent 
further use of post-use ETDs to 
minimize the chances of potential 
fraud. 
xxvii. The document should be taken out of 
circulation at the border crossing point of 
the final destination, unless explicitly 
required or noted on the document by the 
Issuing Authorities. The document should 
ultimately be returned to the Issuing 
Authorities for physical cancellation and/or 
mutilation to prevent it from being used for 
further travel by impostors or fraudsters. 
 
 
 


 
Part 8.    Emergency Travel Documents 
13 
 
6.    USE OF OPTIONAL VISIBLE DIGITAL SEALS FOR ETDS 
 
 
This section specifies the profile for digital seals in ETDs.  
 
A Visible Digital Seal (VDS) is a 2D barcode that includes a cryptographically-signed data structure, which can be 
printed on a non-electronic document to increase its security. Doc 9303-13 specifies VDS for non-electronic documents. 
 
Considering the ETD’s limited security level compared to eMRTDs, they are being targeted by potential fraudsters. 
Digital seals are a means to ensure the integrity and authenticity of ETD data in situations where it is not possible to 
issue a standard full validity passport or other regular travel documents. A worked example for the MRZ of an ETD is 
described in Appendix B. 
 
 
6.1    Content and Encoding Rules 
 
 
6.1.1    Header 
 
The Document Feature Definition Reference for this use-case is 0x5E.  
The Document Type Category for ETDs is 0x03. 
Otherwise, the content of the header is the same as defined in Doc 9303-13. 
 
6.1.2    Document Features of a Digital Seal for ETDs 
 
For the document feature set including only the MRZ as below, the Document Feature Definition Reference value is 
94dec. 
 
Machine Readable Zone (REQUIRED) 
 
Basic information is encoded using a Machine Readable Zone (MRZ) of a TD2 size MROTD, see Doc 9303-6. The MRZ 
of ETDs contains the following information: 
 
• 
document code11; 
• 
issuing State or organization; 
• 
primary and secondary identifiers of the document holder; 
• 
document number; 
• 
nationality of the document holder; 
• 
date of birth of the document holder; 
• 
sex of the document holder; and 
• 
date of expiry. 
 
Additional Document Features (Future Use) 
 
In future versions of this specification additional (OPTIONAL and/or REQUIRED) feature fields may be defined. In case 
additional fields are present, a new unique Document Feature Definition Reference MUST be assigned for each 
combined set of OPTIONAL and REQUIRED feature fields. 
 
11.  Effective 1 January 2026, single-sheet ETDs containing a machine readable zone shall reflect the designated PU document code. 
See section 4.1.5. 
6/2/26 
No. 2 


 
14 
Machine Readable Travel Documents 
 
6.1.3    Encoding Rules for Document Features 
 
In the following, the digital encoding of document features of the ETD seal is defined. 
 
MRZ (TD2 Size, Doc 9303, Part 6: Specifications for TD2 Size Machine Readable Official Travel Documents 
(MROTDs)) 
 
Tag: 
 
0x02  
Min. Length:   
48 Byte  
Max. Length:  
48 Byte 
Value Type:  
Alphanumeric  
Required: 
 
Required 
Content: 
 
The first and second lines of the MRZ of a TD2-MROTD (2*36 characters). 
 
 
The filler character (<) in the MRZ is replaced by <SPACE> prior to encoding by C40. 
 
 
6.1.4    Signature 
 
Appropriate key lengths offering protection against attacks SHALL be chosen for the hashing and signature algorithms. 
Suitable cryptographic catalogues SHOULD be taken into account. 
 
 
6.2    Bar Code Signer and Seal Creation 
 
A possible architecture and implementation for the ETD signer and its client is described in Doc 9303-13. For the 
security of the ETD signing system, see Doc 9303-13. 
 
 
6.3    Public Key Infrastructure (PKI) and Certificate Profiles 
 
For the ETD, the requirements which are mentioned in Doc 9303-12 apply. The following deviations are given for the 
specific ETD profile. 
 
6.3.1    Key Requirements (Validity Period)  
 
ETD Signer Certificates 
 
Private Key Usage Time:  1 year + 2 months (the 2 months are meant for smooth roll-over)  
Certificate Validity: 
 
Private Key Usage Time + ETD Validity Timeframe 
 
 
 
7.    REFERENCES (NORMATIVE) 
 
Annex 9 — Facilitation, Convention on International Civil Aviation (“Chicago Convention”) 
 
 
 
 
—  —  —  —  —  —  —  — 


 
 
 
 
 
 
App A-1 
 
APPENDIX A TO PART 8 — ETD VALIDATION  
POLICY RULES (INFORMATIVE) 
 
The Validation Policy Rules outlined in Doc 9303-13 apply. In addition to these rules, there are further validation rules for 
the ETD which are described in the following paragraphs. 
 
In addition to the generic document Validation Policy, the policy for ETDs considers the following questions: 
1. 
Is the MRZ printed on the ETD valid? 
2. 
Does the MRZ of the ETD match with the MRZ stored in the digital seal? 
 
Further validation steps (e.g. utilizing additionally encoded data) are out of the scope of this profile. Outlined below are 
ETD-specific validation rules for each type of control, a list of the validation criteria, expected results for each criteria, 
and resulting status sub-indications. 
 
Visible Digital Seal Validation 
 
1. 
Format Validation 
 
2. 
Digital Seal MRZ Validation: 
• 
if the checksums of the MRZ stored in the seal are not compliant/valid, then the status is INVALID with 
sub-indication INVALID_SEAL_MRZ. 
 
If all checks above do not result in INVALID and the reader is not capable of processing the printed MRZ, the 
status is VALID. If the reader is capable of processing the printed MRZ, the next checks MUST be conducted: 
 
3. 
Printed MRZ Validation (depending on reader capability): 
• 
if the checksums of the printed MRZ are not compliant/valid, then the status is INVALID with  
sub-indication INVALID_PRINTED_MRZ; 
• 
if the checksums of the printed MRZ are compliant/valid, then the printed MRZ should be compared 
character by character with the MRZ stored in the seal (note that for storing the MRZ in the seal, the filler 
character (<) is replaced by <SPACE>. If any characters mismatch, then the status is INVALID with sub-
indication SEAL_DOCUMENT_MISMATCH; and 
• 
Otherwise, the result is VALID. 
 
The above step covers a comparison of the data stored in the seal against data stored on the MRZ of the document. If 
an automatic check is impossible since the printed data of the document cannot be processed during validation, a 
manual inspection should be conducted by comparing the printed MRZ with the one stored in the (valid) seal. 
 
 


 
App A-2 
Machine Readable Travel Documents 
 
Table A-1.    Trust Levels of the ETD Policy 
 
Status indication 
Sub-status indication 
Trust level 
INVALID 
INVALID_SEAL_MRZ 
High fraud potential 
INVALID_PRINTED_MRZ 
SEAL_DOCUMENT_MISMATCH 
 
 
 
 
—  —  —  —  —  —  —  — 


 
 
 
 
 
 
App B-1 
 
APPENDIX B TO PART 8 — WORKED EXAMPLE  
VISIBLE DIGITAL SEAL FOR ETD (INFORMATIVE) 
 
The following example shows a visible digital seal. To generate the signature ECDSA256 with the curve brainpool256r1 
must be used. This example only contains the header and data of the document. 
 
 
 
 
Figure B-1.    Example Visible Digital Seal for ETD 
 
 
 
 
— END — 
6/2/26 
No. 2 
Header
Issuing Country 
UTO
Three-letter country code
Document Issue Date 
13.06.2026
Signing Certificate
UTTS5B
Status
Datamatrix contains 134 bytes of data.
SignerCertRef
UTTS025B
Encoded RAW data
Select seal type
Emergency Travel Document
Emergency Travel Document
MRZ 1st line 
PUU OERIKSSON
ANNA MARIA
T
<<
<
<<<<<<<<<<<
MRZ 2nd line 
D231458907UTO7408122F2606277
8
<<<<<<<
Submit
DC
5E
58
4D
13
AC
F1
E9
32
03
03
13
0D
3C
16
0A
8
0
7A
D9
02
5C
4A
13
73
97
3A
4E
C5
30
6F
32
45
2D
9
8
7F
0E
CA
B3
FC
C1
40
E2
1
5
6F
ED
D9
A
B
57
B0
FF
7E
0D
20
E6
C8
D2
13
1A
39
C2
1C
04
A7
B3
3C
E6
03
0D
3C
FB
5D
CD
13
27
DA
7B
8
4
DB
99
49
3C
84
5
8
EF
B9
AF
91
1D
3C
5
1
18
38
07
8A
3A
A9
6B
3F
3C
1C
A4
B9
3A
C5
13
26
4E
7A
47
35
57
D4
8A
C
3
D3
09
7C
93
9C
5B
20
45
C0
E5
F6
8A
7D
3C
38
7C
1C
0A
D0
65

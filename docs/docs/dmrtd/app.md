# Mobile App
<div class="mobile-apps">

The Passport Reader app is a mobile application designed to read and verify Machine Readable Travel Documents (MRTDs) such as passports. It utilizes the NFC capabilities of modern smartphones to read the data stored in the passport's chip, including personal information, biometric data, and security features.
## Step 1 - Choose Reading Mode
When you open the Passport Reader app, you will be presented with two options to read the passport:
Users get the choose between two different modes of reading the passport:
- **Camera Mode**: Uses the device's camera to scan the Machine Readable Zone (MRZ) of the passport. The app automatically detects the MRZ and extracts the relevant data.
- **Manual Mode**: Allows users to manually enter the passport details if the camera mode is not available or if the MRZ cannot be read.

![alt text](/images/home.png)

## Step 2 - Scan the MRZ
The **camera mode** uses the device's camera to scan the Machine Readable Zone (MRZ) of the passport. The app automatically detects the MRZ and extracts the relevant data. This mode is useful for quickly reading passports without needing to manually enter information.

![alt text](/images/mrz.png)

## Step 3 - Allign NFC chip
Once the MRZ is scanned the app will request the user to place the passport on the back of the device. The app will then attempt to read the data from the passport's chip using NFC technology.
Make sure NFC is enabled on your device and that the passport is placed correctly on the back of the device.

:::note
1. Ensure NFC is enabled on your device.
2. Place the passport on the back of the device.
3. The passport should be on the photo side facing the device.
4. Allign the phone's NFC area with the chip (usually located near the photo).
5. Remove any phone case or cover that might interfere with NFC reading.
6. Keep the passport and phone still during the reading process.
7. If the reading fails, try adjusting the position of the passport.
:::

![alt text](/images/nfc.png)

## Step 4 - Reading NFC chip
Authentication and reading of the NFC chip is done in the background. The app will display a progress indicator while it attempts to read the data from the passport's chip. If successful, it will extract the personal information and security information stored in the passport.

:::warning
No personal data is sent to any server or third party. All processing is done locally on the device.
:::

Reading the NFC chip may take a few seconds. The app will notify you once the reading is complete. If the reading fails, you may need to adjust the position of the passport or try again. The photo inside the passport is quite large, so it may take a few seconds to read the data.


![alt text](/images/reading.png)

## Step 5 - Inspect results
Once the reading is complete, the app will display the extracted data from the passport. This includes personal information such as name, date of birth, and nationality, as well as facial images and security information.

![alt text](/images/result.png)
</div>
#import <Foundation/Foundation.h>

#import "IOSToObjCppExceptions.hpp"
#import "wConfiguration.hpp"
#import "wComparison.hpp"
#import "wDetection.hpp"
#import "wEnrollment.hpp"
#import "wFaceVector.hpp"
#import "wPerson.hpp"
#import "wBiometric.hpp"

@interface TwentyfaceBridge : NSObject

// ObjectiveC functions with their customized swift function declaration
// ==== MISCELLANEOUS FUNCTIONS ===============================================
/// Set the license of the SDK, checks if license is correct
///
/// - Parameter license: License as a base64 encoded string (can be hardware-based).
///
/// - Throws: `twentyface::LicenseException` if the license is expired
/// - Throws: `twentyface::LicenseException` if the license is invalid
/// - Throws: `twentyface::EndOfSupportException` if the SDK has reached the end-of-support date
/// - Throws: `twentyface::EndOfSupportNearingException` if the SDK has ALMOST reached the end-of-support date, mere as a warning to integrate a newer version of the SDK. This exception can be suppressed to continue the usage of the SDK, but it is strongly advices to renew the SDK before the EOL date is actually surpassed.
- (void) setLicense:(NSString *)license error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error)));
/// Initialization of the SDK, checks if license is correct
///
/// - Parameters:
///    - license_file: License file with encrypted string
///    - license_str: License as a base64 encoded string
///    - allow_fallback: If true, fallback to default license file location
///
/// - Throws: `twentyface::LicenseException` if the license is expired
/// - Throws: `twentyface::LicenseException` if the license is invalid
/// - Throws: `twentyface::EndOfSupportException` if the SDK has reached the end-of-support date
/// - Throws: `twentyface::EndOfSupportNearingException` if the SDK has ALMOST reached the end-of-support date, mere as a warning to integrate a newer version of the SDK. This exception can be suppressed to continue the usage of the SDK, but it is strongly advices to renew the SDK before the EOL date is actually surpassed.
- (void) initLibrary:(NSString *)license_file license_str:(NSString *)license_str allow_fallback:(BOOL)allow_fallback error:(NSError **)errorPtr __attribute__((deprecated("This function will be deprecated in the future, use `setLicense(license)` instead"))) __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(initLibrary(license_file:license_str:allow_fallback:));
- (void) modelAssetsToInternalWithOverwrite:(BOOL)overwrite NS_SWIFT_NAME(modelAssetsToInternalWithOverwrite(overwrite:));
- (void) licenseAssetsToInternalWithOverwrite:(BOOL)overwrite NS_SWIFT_NAME(licenseAssetsToInternalWithOverwrite(overwrite:));
- (NSString *) getVersion;
- (NSString *) getModelVersion;
- (NSNumber *) getCurrentLicenseExpiryDate:(NSError **)errorPtr __attribute__((swift_error(nonnull_error)));
- (void)setInitialConfiguration:(wConfiguration *)configuration;
- (NSString *) getHardwareID:(NSError **)errorPtr __attribute__((swift_error(nonnull_error)));

// ==== CORE FUNCTIONS ========================================================
- (wEnrollment*) enrollFromPath:(NSString*)path configuration:(wConfiguration*)configuration group_id:(NSNumber*)group_id error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(enroll(path:configuration:group_id:));
- (wEnrollment*) enrollFromImage:(UIImage*)image configuration:(wConfiguration*)configuration group_id:(NSNumber*)group_id error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(enroll(image:configuration:group_id:));
- (wEnrollment*) updateEnrollFromPath:(NSString*)uuid path:(NSString*)path configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(updateEnroll(uuid:path:configuration:));
- (wEnrollment*) updateEnrollFromImage:(NSString*)uuid image:(UIImage*)image configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(updateEnroll(uuid:image:configuration:));
- (void) unenroll:(NSString*)uuid error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(unenroll(uuid:));
- (NSArray<wPerson*>*) recognizeFromPath:(NSString *)imagePath configuration:(wConfiguration*)configuration group_id:(NSNumber*)group_id error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(recognize(path:configuration:group_id:));
- (NSArray<wPerson*>*) recognizeFromImage:(UIImage *)image configuration:(wConfiguration*)configuration group_id:(NSNumber*)group_id error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(recognize(image:configuration:group_id:));
- (wComparison*) compareFromPath:(NSString*)first_path second_path:(NSString*)second_path configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(compare(first_path:second_path:configuration:));
- (wComparison*) compareFromImage:(UIImage*)firstImage secondImage:(UIImage*)secondImage configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(compare(firstImage:secondImage:configuration:));
- (NSArray<wDetection*>*) detectFacesFromPath:(NSString*)path configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(detectFaces(path:configuration:));
- (NSArray<wDetection*>*) detectFacesFromImage:(UIImage*)image configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(detectFaces(image:configuration:));
- (NSArray<wFaceVector*>*) getFaceVectorsFromPath:(NSString*)path configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getFaceVectors(path:configuration:));
- (NSArray<wFaceVector*>*) getFaceVectorsFromImage:(UIImage*)path configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getFaceVectors(image:configuration:));

// ==== DATABASE SYNCHRONIZATION FUNCTIONS ====================================
- (void) addBiometricsToDB:(NSArray<wBiometric*>*)biometrics configuration:(wConfiguration*)configuration error:(NSError **)errorPtr __attribute__((deprecated("This function will be deprecated in the future but its behavior is not fully replicated by the AddOrUpdateBiometricsInDB(). Additional features will be added in future releases to cover the functionality of this function."))) __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(addBiometricsToDB(biometrics:configuration:));
- (void) addOrUpdateBiometricsInDB:(NSArray<wBiometric*>*)biometrics error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(addOrUpdateBiometricsInDB(biometrics:));

- (void) removeBiometricsFromDBWithBiometrics:(NSArray<wBiometric*>*)biometrics error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(removeBiometricsFromDBWithBiometrics(biometrics:));
- (void) removeBiometricsFromDBWithUUIDs:(NSArray<NSString*>*)uuids error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(removeBiometricsFromDBWithUUIDs(uuids:));

- (NSArray<wBiometric*>*) getAllBiometricsFromDB:(NSError **)errorPtr __attribute__((swift_error(nonnull_error)));
- (wBiometric*) getBiometricFromDB:(NSString*)uuid error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getBiometricFromDB(uuid:));
- (NSArray<wBiometric*>*) getBiometricsFromDB:(NSDate*)time error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getBiometricsFromDB(time:));
- (NSArray<wBiometric*>*) getAllBiometricsFromGroup:(NSNumber*)group_id error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getAllBiometricsFromGroup(group_id:));

- (void) resetDB: (NSError **)errorPtr __attribute__((swift_error(nonnull_error)));
- (NSString *) getLicenseExpiryDateFileAndString:(NSString *)license_file license_str:(NSString *)license_str allow_fallback:(BOOL)allow_fallback error:(NSError **)errorPtr __attribute__((deprecated("This function will be deprecated in the future. Please use setLicense(license) and getLicenseExpiryDate(license) instead"))) __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getLicenseExpiryDate(_:license_str:allow_fallback:));
- (NSString *) getLicenseExpiryDateJWT:(NSString *)license error:(NSError **)errorPtr __attribute__((swift_error(nonnull_error))) NS_SWIFT_NAME(getLicenseExpiryDate(_));

@end

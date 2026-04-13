#ifndef wBiometric_h
#define wBiometric_h

#import <Foundation/Foundation.h>
#import "wRecognizerStatus.hpp"

@interface wBiometric : NSObject {
@private
void* myBiometric;
}

typedef NSMutableArray<NSNumber *> wMutableFaceVector;

// constructors
- (wBiometric*) init;
- (wBiometric*) init: (wRecognizerStatus*)status;
- (wBiometric*) init: (NSString*)uuid faceVector:(NSArray<NSNumber*>*)faceVector modelVersion:(NSString*)modelVersion createdAt:(NSDate*)createdAt updatedAt:(NSDate*)updatedAt groupId:(NSNumber*)groupId;
- (wBiometric*) init: (NSString*)uuid faceVector:(NSArray<NSNumber*>*)faceVector modelVersion:(NSString*)modelVersion createdAt:(NSDate*)createdAt updatedAt:(NSDate*)updatedAt status:(wRecognizerStatus*)status groupId:(NSNumber*)groupId;
- (wBiometric*) initWithBiometric: (void*)Biometric;

// destructors
- (void) dealloc;

// properties
@property (readwrite, retain) NSString *uuid;
@property (readwrite, retain) NSArray<NSNumber*> *face_vector;
@property (readwrite, retain) NSDate *created_at;
@property (readwrite, retain) NSDate *updated_at;
@property (readwrite, retain) NSString *model_version;
@property (readwrite, retain) NSNumber *group_id;

// functions
- (NSString*) getUuid;
- (NSArray<NSNumber*>*) getFaceVector;
- (NSDate*) getCreatedAt;
- (NSDate*) getUpdatedAt;
- (NSString*) getModelVersion;
- (wRecognizerStatus*) getStatus;
- (NSNumber*) getGroupId;

// helpers
- (void*) getCPPbiometric;     // !NOTE: Always copy the returned object as object will be destroyed when the wBiometric instance is destroyed

@end

#endif /* wBiometric_h */

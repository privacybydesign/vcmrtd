#ifndef wFacevector_h
#define wFacevector_h

#import <Foundation/Foundation.h>
#import "wStatus.hpp"

@interface wFaceVector : NSObject {
@private
void* thisFaceVector;
}

// constructors
- (wFaceVector*) init;
- (wFaceVector*) init:status:(wStatus*)status;
- (wFaceVector*) init:(NSArray*)face_vector status:(wStatus*)status;
- (wFaceVector*) initWithFaceVector: (void*)FaceVector;

// properties
@property (readwrite) wStatus *status;
@property (readwrite) NSArray<NSNumber*> *face_vector;

// destructors
- (void) dealloc;

//helpers
- (void*) getCPPFaceVector;

@end

#endif /* wFacevector_h */

#ifndef wPerson_h
#define wPerson_h

#import <Foundation/Foundation.h>
#import "wStatus.hpp"
#import "wRectangle.hpp"

@interface wPerson : NSObject {
@private
void* myPerson;
}

// constructors
- (wPerson*) init;
- (wPerson*) init:(NSString*)uuid confidence:(NSNumber*)confidence recognitionDistance:(NSNumber*)recognitionDistance rectangle:(wRectangle*)rectangle status:(wStatus*)status;
- (wPerson*) initWithPerson: (void*)Person;

// destructors
- (void) dealloc;

// functions
- (NSString*) getUuid;
- (NSNumber*) getConfidence;
- (NSNumber*) getRecognitionDistance;
- (wRectangle*) getRectangle;
- (wStatus*) getStatus;

// helpers
- (void*) getCPPperson;     // !NOTE: Always copy the returned object as object will be destroyed when the wBiometric instance is destroyed

@end

#endif /* wPerson_h */
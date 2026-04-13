#ifndef wEnrollment_h
#define wEnrollment_h

#import <Foundation/Foundation.h>
#import "wStatus.hpp"

@interface wEnrollment : NSObject {
@private
void* thisEnrollment;
}

// constructors;
- (wEnrollment*) init:(wStatus*)status;
- (wEnrollment*) init:(NSString*)uuid status:(wStatus*)status;
- (wEnrollment*) initWithEnrollment: (void*)Enrollment;

// properties
@property (readwrite) NSString *uuid;
@property (readwrite) wStatus *status;

// destructors
- (void) dealloc;

//helpers
- (void*) getCPPEnrollment;

@end

#endif /* wEnrollment_h */

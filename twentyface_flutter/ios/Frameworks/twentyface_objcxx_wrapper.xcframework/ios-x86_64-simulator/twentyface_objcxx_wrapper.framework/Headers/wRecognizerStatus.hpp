#ifndef wRecognizerStatus_h
#define wRecognizerStatus_h

#import <Foundation/Foundation.h>

@interface wRecognizerStatus : NSObject {
@private
void* thisRecognizerStatus;
}

// status booleans
@property (readonly) BOOL facevector_too_similar_in_db;
@property (readonly) BOOL facevector_not_recognized;
@property (readonly) BOOL facevector_failed_to_create;
@property (readonly) BOOL is_overall_ok;

// constructors
- (wRecognizerStatus*) init;
- (wRecognizerStatus*) initWithRecognizerStatus: (void*)RecognizerStatus;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPrecognizerstatus;      // !NOTE: Always copy the returned object as object will be destroyed when the wConfiguration instance is destroyed
- (void) syncRecognizerStatusFromCpp;  // Sets the values from the cpp object to this object
- (void) syncRecognizerStatusFromSelf; // Sets the values from this object to the cpp object


@end

#endif /* wStatus_h */

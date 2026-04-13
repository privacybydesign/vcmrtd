#ifndef wRecognizerConfiguration_h
#define wRecognizerConfiguration_h

#import <Foundation/Foundation.h>

@interface wRecognizerConfiguration : NSObject {
    @private
    void* myRecognizerConfiguration;
}

// recognition parameters
@property (readwrite) NSNumber *add_threshold;
@property (readwrite) NSNumber *recognize_threshold;
@property (readwrite) NSString *connection_string;
@property (readwrite) NSNumber *log_level;

// constructors
- (wRecognizerConfiguration*) init;
- (wRecognizerConfiguration*) initWithRecognizerConfiguration: (void*)RecognizerConfiguration;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPrecognizerconfiguration;      // !NOTE: Always copy the returned object as object will be destroyed when the wRecognizerConfiguration instance is destroyed
- (void) syncRecognizerConfigurationFromCpp;  // Sets the values from the cpp object to this object
- (void) syncRecognizerConfigurationFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wRecognizerConfiguration_h */

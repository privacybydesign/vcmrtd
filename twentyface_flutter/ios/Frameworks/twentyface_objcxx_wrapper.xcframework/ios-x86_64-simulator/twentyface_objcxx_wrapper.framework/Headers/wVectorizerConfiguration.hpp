#ifndef wVectorizerConfiguration_h
#define wVectorizerConfiguration_h

#import <Foundation/Foundation.h>

@interface wVectorizerConfiguration : NSObject {
    @private
    void* myVectorizerConfiguration;
}

// recognition parameters
@property (readwrite) NSNumber *log_level;

// constructors
- (wVectorizerConfiguration*) init;
- (wVectorizerConfiguration*) initWithVectorizerConfiguration: (void*)VectorizerConfiguration;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPvectorizerconfiguration;      // !NOTE: Always copy the returned object as object will be destroyed when the wVectorizerConfiguration instance is destroyed
- (void) syncVectorizerConfigurationFromCpp;  // Sets the values from the cpp object to this object
- (void) syncVectorizerConfigurationFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wVectorizerConfiguration_h */

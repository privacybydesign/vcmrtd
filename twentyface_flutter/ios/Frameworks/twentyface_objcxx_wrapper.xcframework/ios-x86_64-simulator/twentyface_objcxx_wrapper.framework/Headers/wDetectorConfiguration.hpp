#ifndef wDetectorConfiguration_h
#define wDetectorConfiguration_h

#import <Foundation/Foundation.h>

@interface wDetectorConfiguration : NSObject {
    @private
    void* myDetectorConfiguration;
}

// recognition parameters
@property (readwrite) NSString *detection_method;
@property (readwrite) NSNumber *min_face_width;
@property (readwrite) NSNumber *mtcnn_scale_factor;
@property (readwrite) NSNumber *log_level;

// constructors
- (wDetectorConfiguration*) init;
- (wDetectorConfiguration*) initWithDetectorConfiguration: (void*)DetectorConfiguration;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPdetectorconfiguration;      // !NOTE: Always copy the returned object as object will be destroyed when the wDetectorConfiguration instance is destroyed
- (void) syncDetectorConfigurationFromCpp;  // Sets the values from the cpp object to this object
- (void) syncDetectorConfigurationFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wDetectorConfiguration_h */

#ifndef wConfiguration_h
#define wConfiguration_h

#import <Foundation/Foundation.h>
#import "wDetectorConfiguration.hpp"
#import "wRecognizerConfiguration.hpp"
#import "wVectorizerConfiguration.hpp"

@interface wConfiguration : NSObject {
    @private
    void* myConfiguration;
}

@property (readwrite) wDetectorConfiguration *detector_configuration;
@property (readwrite) wRecognizerConfiguration *recognizer_configuration;
@property (readwrite) wVectorizerConfiguration *vectorizer_configuration;

@property (readwrite) NSNumber *log_level;

// recognition parameters
@property (readwrite) NSNumber *source_handler_crop_margin;    ///< Only change if advised to do so by 20face (used for internal testing)

//Feature extraction parameters
@property (readwrite) NSNumber *max_simultaneous_networks;     ///< Maximum number of simultaneously processed (batch processed) face images. Setting this to a higher value will improve the speed when more faces are visible but costs a 100 MB memory extra per addition (e.g. 1 = 100mb, 2 = 200mb, 3 = 300mb, etc...)

// Anti spoof parameters
@property (readwrite) BOOL anti_spoof_deep_learning;           ///< Suggests the method used for anti-spoofing: use the deep learning model.
@property (readwrite) NSNumber *as_padding_factor;             ///< Sets the padding factor around the crop, optimal value determined by 'research', it is advised to not change this value
@property (readwrite) NSNumber *as_spoof_threshold;            ///< The threshold under which a face is considered spoofed, only has effect when using deep learning anti spoofing
@property (readwrite) BOOL as_anti_spoof_depth_camera;         ///< Suggests the method used for anti-spoofing: use the depth camera.
@property (readwrite) NSNumber *distance_threshold;            ///< Distance nose landmark to the camera in mm, more than 2000 mm not recommended. Will only affect the maximum recognition distance when using realsense cameras.
@property (readwrite) BOOL as_temporal_anti_spoofing_depth;    ///< If we should apply temporal anti spoofing when using depth images which reduces errors but increases time before someone is marked as not spoofed

 // Quality Checker parameters
@property (readwrite) NSNumber *qc_max_horizontal_rotation;    ///< The maximum rotation of the face in the horizontal plane in degrees. If the rotation of a face is more than this value the functions with check_quality set to true will not recognize that face or throw an error.
@property (readwrite) NSNumber *qc_max_vertical_rotation;      ///< The maximum rotation of the face in the vertical plane in degrees. If the rotation of a face is more than this value the functions with check_quality set to true will not recognize that face or throw an error.
@property (readwrite) NSNumber *qc_min_detection_score;        ///< The detection threshold. A lower score will detect more faces but also produces more false positives and vice versa. It is recommended to not change this value.
@property (readwrite) NSNumber *qc_min_sharpness;              ///< The minimum sharpness, a value between 0 and 12. Where 0 is extremely blurry, 3.0 [default] is not so blurry and 12 is only extremely sharp images. If the sharpness of a face is less than this value the functions with check_quality set to true will not recognize that face or throw an error.
@property (readwrite) NSNumber *qc_max_face_size;              ///< The maximum number of pixels in width and height of a face to pass the quality check. If the height of a face in pixels is more than this value the functions with check_quality set to true will not recognize that face or throw an error.
@property (readwrite) NSNumber *qc_max_exposure;               ///< Maximum percentage of overexposed pixels on the quality check. The Q.C. will fail for values higher or equal. Recommended value of 4 (represents percentage, values of more than 100 will always pass).

 // Settings for the detector
@property (readwrite) BOOL detect_closest_only;                ///< If we should only return the largest detect face

 // Settings for anti spoofing
@property (readwrite) BOOL anti_spoofing;                      ///< Whether to apply anti spoofing
@property (readwrite) BOOL as_temporal_anti_spoofing;          ///< Whether to apply temporal antispoofing. Reduces number of successful spoof attempts, but makes the system lag by 3 frames and reduces the number of valid non spoofs.
@property (readwrite) NSNumber *as_max_horizontal_rotation;    ///< Max horizontal rotation in degrees for passing anti spoofing
@property (readwrite) NSNumber *as_max_vertical_rotation;      ///< Max vertical rotation in degrees for passing anti spoofing
@property (readwrite) NSNumber *as_distance_threshold;         ///< Max distance nose landmark to the camera in mm, more than 2000 mm not recommended

 // Settings for passive anti spoofing
@property (readwrite) BOOL passive_anti_spoofing;              ///< Whether to apply passive anti spoofing
@property (readwrite) NSNumber *passive_anti_spoofing_threshold; ///< The threshold under which a face is considered spoofed, only has effect when using passive anti spoofing

 // Settings for normalization
@property (readwrite) NSString *image_normalization_method;    ///< Image normalization method that is used to normalize the crop before it is vectorized

 // Setting related to flexible model and license location
@property (readwrite) NSString *model_path;                    ///< Set full path location for models
@property (readwrite) NSString *license_file;                  ///< Set full path location for license file

// constructors
- (wConfiguration*) init;
- (wConfiguration*) initWithConfiguration: (void*)Configuration;

// destructors
- (void) dealloc;

// helpers
- (void*) getCPPconfiguration;     // !NOTE: Always copy the returned object as object will be destroyed when the wConfiguration instance is destroyed
- (void) syncConfigurationFromCpp;  // Sets the values from the cpp object to this object
- (void) syncConfigurationFromSelf; // Sets the values from this object to the cpp object

@end

#endif /* wConfiguration_h */

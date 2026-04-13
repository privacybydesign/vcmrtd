#ifndef wDetection_h
#define wDetection_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "wStatus.hpp"
#import "wRectangle.hpp"
#import "wLandmarks.hpp"
#import "wPose.hpp"

@interface wDetection : NSObject {
@private
    void* myDetection;
}

// constructors
- (wDetection*) init:(NSNumber*)id status:(wStatus*)status score:(NSNumber*)score rectangle:(wRectangle*)rectangle landmarks:(wLandmarks*)landmarks pose:(wPose*)pose frame_width:(NSNumber*)frame_width frame_height:(NSNumber*)frame_height stream_number:(NSNumber*)stream_number crop_tight:(UIImage*)crop_tight crop_wide:(UIImage*)crop_wide crop_normalized:(UIImage*)crop_normalized crop_passive:(UIImage*)crop_passive  track:(NSNumber*)track;
- (wDetection*) initWithDetection: (void*)Detection;

// properties
@property (readwrite) NSNumber *id;
@property (readwrite) wStatus *status;
@property (readwrite) NSNumber *score;
@property (readwrite) wRectangle *rectangle;
@property (readwrite) wLandmarks *landmarks;
@property (readwrite) wPose *pose;
@property (readwrite) NSNumber *frame_width;
@property (readwrite) NSNumber *frame_height;
@property (readwrite) NSNumber *stream_number;
@property (readwrite) NSNumber *frame_number;
@property (readwrite) UIImage *crop_tight;
@property (readwrite) UIImage *crop_wide;
@property (readwrite) UIImage *crop_normalized;
@property (readwrite) NSNumber *track;

// destructors
- (void) dealloc;

//helpers
- (void*) getCPPDetection;

@end

#endif /* wDetection_h */

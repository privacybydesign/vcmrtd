#import <UIKit/UIKit.h>

/**
 * Customize the shadow that can be applied to the Frame and Feedback Bar.
 * Note: These properties and their behaviors correlate to the shadow-related attributes available for CALayer objects.
 */
__attribute__((visibility("default")))
@interface FaceTecShadow : NSObject

/**
 * Control the shadow's color.
 * Default is black.
 */
@property (nonatomic) UIColor * _Nonnull color;
/**
 * Control the shadow's opacity.
 * Default is 0.
 */
@property (nonatomic) float opacity;
/**
 * Control the shadow's radius.
 * Default is 0.
 */
@property (nonatomic) float radius;
/**
 * Control the shadow's offset.
 * Default is CGSizeZero.
 */
@property (nonatomic) CGSize offset;
/**
 * Control the insets from the parent's view frame for configuring the shadow's path.
 * Default is UIEdgeInsetsZero.
 */
@property (nonatomic) UIEdgeInsets insets;

- (nonnull instancetype) init;
- (nonnull instancetype) initWithColor:(UIColor * _Nonnull)color opacity:(float)opacity radius:(float)radius offset:(CGSize)offset insets:(UIEdgeInsets)insets;
@end

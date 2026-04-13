#ifndef wRectangle_h
#define wRectangle_h

#import <Foundation/Foundation.h>

@interface wRectangle : NSObject {
@private
void* myRectangle;
}

// constructors
- (wRectangle*) init;
- (wRectangle*) init:(NSNumber*)x y:(NSNumber*)y w:(NSNumber*)w h:(NSNumber*)h;
- (wRectangle*) initWithRectangle: (void*)Rectangle;

// destructors
- (void) dealloc;

// functions
- (NSNumber*) x;
- (NSNumber*) y;
- (NSNumber*) width;
- (NSNumber*) height;

// helpers
- (void*) getCPPrectangle;     // !NOTE: Always copy the returned object as object will be destroyed when the wRectangle instance is destroyed

@end

#endif /* wRectangle_h */

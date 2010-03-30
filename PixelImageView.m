#import "PixelImageView.h"

@implementation PixelImageView

- (void)drawRect:(NSRect)rect{
	// Draw our background color
	[[NSColor grayColor] set];
	NSRectFill(rect);

	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone]; //disable interpolation
	[[NSGraphicsContext currentContext] setShouldAntialias:NO]; // disable antialiasing

	// now allow NSImageView to draw the image itself
	[super drawRect:rect];
}

@end

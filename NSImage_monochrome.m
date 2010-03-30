//
//  NSImage_monochrome.m
//  Black and White
//
//  Created by jcr on Wed Aug 21 2002.
//  Copyright (c) 2002 Apple Computer, Inc. All rights reserved.
//

#import "NSImage_monochrome.h"

typedef struct _monochromePixel{
	unsigned char grayValue;
	unsigned char alpha;
} monochromePixel;

@implementation NSImage (monochrome)

- (NSImage *) monochromeImage{
	NSSize mySize = [self size];
	NSImage *monochromeImage = [[[self class] alloc] initWithSize:mySize];
	int row, column, widthInPixels = mySize.width, heightInPixels = mySize.height;
		
	// Need a place to put the monochrome pixels.
	NSBitmapImageRep *blackAndWhiteRep = [[NSBitmapImageRep alloc] 
										  initWithBitmapDataPlanes: nil  // Nil pointer tells the kit to allocate the pixel buffer for us.
										  pixelsWide: widthInPixels 
										  pixelsHigh: heightInPixels
										  bitsPerSample: 8
										  samplesPerPixel: 2  
										  hasAlpha: YES
										  isPlanar: NO 
										  colorSpaceName: NSCalibratedWhiteColorSpace // 0 = black, 1 = white in this color space.
										  bytesPerRow: 0     // Passing zero means "you figure it out."
										  bitsPerPixel: 16];  // This must agree with bitsPerSample and samplesPerPixel.

	monochromePixel *pixels = (monochromePixel *)[blackAndWhiteRep bitmapData];

	[self lockFocus]; // necessary for NSReadPixel() to work.
	for (row = 0; row < heightInPixels; row++){
		for (column = 0; column < widthInPixels; column++){
			monochromePixel *thisPixel = &(pixels[((widthInPixels * row) + column)]);
			NSColor *pixelColor = NSReadPixel(NSMakePoint(column, heightInPixels - (row + 1)));
			// use this line for negative..
		//	thisPixel->grayValue = 1.0 - rint(255 *
			// use this line for positive...
			thisPixel->grayValue = rint(255 * (0.299 * [pixelColor redComponent] + 0.587 * [pixelColor greenComponent] + 0.114 * [pixelColor blueComponent]));
			thisPixel->alpha = ([pixelColor alphaComponent]  * 255); // handle the transparency, too
		}
	}
	[self unlockFocus];
	
	[monochromeImage addRepresentation:blackAndWhiteRep];
	[blackAndWhiteRep release];

	return [monochromeImage autorelease];
}

@end

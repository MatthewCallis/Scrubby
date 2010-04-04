
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@interface NSString (HexColorAdditions)

- (NSColor *)hexColor;

@end

@interface NSColor (HexColorAdditions)

- (NSData *)hexData;
- (NSString *)hexString;
- (NSString *)stringRepresentation;
- (CGFloat)randomFloatBetween:(CGFloat)low high:(CGFloat)high;
- (NSColor *)colorToGrayScale:(NSColor *)aColor;
- (NSColor *)colorToFakeComplementaryColor:(NSColor *)aColor;
- (NSColor *)readPixelsAverage:(NSBitmapImageRep *)bitmapImageRep;
- (NSColor *)readPixelsAverageForRect:(NSRect)aRect;

@end

@interface NSData (HexColorAdditions)

- (NSUInteger)colorCount;
- (NSArray *)colors;

@end

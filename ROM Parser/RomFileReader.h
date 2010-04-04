#import <Cocoa/Cocoa.h>

@interface RomFileReader : NSObject{
	NSString *fullPath;
	NSImage *image;
}

+ (RomFileReader *) parseFile:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded;

- (id) initWithFile:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded;
- (void) buildImage:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded;
- (NSArray *) getSpriteDataFromChrBank:(NSData *)chrData number:(NSUInteger)number mode:(NSUInteger)mode;
- (NSArray *) getSpriteDataRangeFromChrBank:(NSData *)chrData start:(NSUInteger)startIndex end:(NSUInteger)endIndex mode:(NSUInteger)mode mapping:(NSUInteger)mapping;
- (NSArray *) makeCompoundSprite:(NSArray *)spriteData size:(NSUInteger)size columns:(NSUInteger)columns mode:(NSUInteger)mode;
- (NSBitmapImageRep *) makeBitmapData:(NSArray *)compoundData palette:(NSMutableArray *)palette;

- (void) encodeImage:(NSImage *)imageObject thingsNeeded:(NSDictionary *)thingsNeeded;

@property (retain) NSString *fullPath;

@end

#import "NSData_EVBitmap.h"

@implementation NSData (EVBitmap)

- (int)colorCount{
	NSMutableArray *colorCounter = [[NSMutableArray alloc] init];
	unsigned char bitmapColor;
	int i;
	int offset = 54;
	int colorsUsed = 0;
	for(i = 0; i < 16384; i++){
		[self getBytes:&bitmapColor range:NSMakeRange(offset, 3)];
		NSData *subData = [NSData data];
		subData = [self subdataWithRange:NSMakeRange(offset, 3)];
		if(![colorCounter containsObject: subData]){
			[colorCounter addObject: subData];
			colorsUsed++;
		}
		offset += 3;
	}
	[colorCounter release];
	return colorsUsed;
}

@end

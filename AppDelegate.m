#import "AppDelegate.h"
#import "RomFileReader.h"
#import "HexColorAdditions.h"
#import "NSImage_BMPData.h"
#import "NSData_EVBitmap.h"

@interface AppDelegate ()

@property (readwrite,copy) NSNumber* offset;
@property (readwrite,copy) NSString* filename;
@property (readwrite,copy) NSString* layout;
@property (readwrite,copy) NSString* mode;
@property (readwrite,copy) NSMutableArray* palette;

@end

@implementation AppDelegate

@synthesize offset;
@synthesize filename;
@synthesize layout;
@synthesize mode;
@synthesize palette;


- (void)dealloc{
	[super dealloc];
}

/**
- (IBAction) encodeFile:(id)sender{
	NSOpenPanel *sourceDir = [NSOpenPanel openPanel];
	[sourceDir setAllowsMultipleSelection:NO];
	[sourceDir setCanChooseDirectories:NO];
	[sourceDir setCanChooseFiles:YES];
	[sourceDir setCanCreateDirectories:NO];
	[sourceDir setResolvesAliases:YES];
	[sourceDir setTitle: NSLocalizedString(@"Import File", nil)];
	[sourceDir setPrompt: NSLocalizedString(@"Choose File", nil)];
	if([sourceDir runModalForTypes:nil] == NSFileHandlingPanelOKButton){
		filename = [sourceDir filename];
	}

	NSLog(@"[1] Filename:\t%@", filename);

	NSData *fileData = [NSData dataWithContentsOfFile:filename];
	NSImage *snesImage = [[NSImage alloc] init];
	[snesImage initWithData: fileData];
	[mainImageView setImage: snesImage];

	NSMutableData *bitmapData = [NSMutableData dataWithData: [snesImage BMPData]];
//	NSLog(@"[2] Data:\t\t%@", [bitmapData description]);

	NSUInteger x;
	NSUInteger y;
	offset = 54;
	unsigned char imagemap[16384];	// 128 x 128 Pixels
	unsigned char bitmapColor;

	NSMutableArray *colorCounter = [[NSMutableArray alloc] init];
	NSUInteger colorsUsed = 0;
	for(y = 0; y < 16384; y++){
		[bitmapData getBytes:&bitmapColor range:NSMakeRange(offset, 3)];
		NSData *subData = [bitmapData subdataWithRange:NSMakeRange(offset, 3)];
		if(![colorCounter containsObject: subData]){
			[colorCounter addObject: subData];
			colorsUsed++;
		}
		offset += 3;
	}

	NSLog(@"Colors In Bitmap: %d", colorsUsed);

	offset = 54;
	for(y = 0; y < 128; y++){
		for(x = 0; x < 128; x++){
			NSUInteger colorCode;
			NSData *subData = [bitmapData subdataWithRange:NSMakeRange(offset, 3)];
			if([subData isEqualToData: [colorCounter objectAtIndex:0]]){		colorCode = 0;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:1]]){	colorCode = 1;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:2]]){	colorCode = 2;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:3]]){	colorCode = 3;	}
			else{
				NSLog(@"Too Many Colors!");
				NSLog(@"SubData:\t\t%@", [subData description]);
				NSLog(@"Current Pixel: %d", offset);
				colorCode = 3;
			}
			imagemap[y * 128 + x] = colorCode;
			offset += 3;
		}
	}

	NSLog(@"[3] Made CHR");

	NSMutableData *chrBuffer = [NSMutableData data];
	unsigned char colorByte;
	NSUInteger i;
	NSUInteger j;
	for(j = 0; j < 128; j += 8){
		for(i = 0; i < 128; i += 8){
			// Low Bit
			for(y = j; y < j + 8; y++){
				colorByte = 0;
				for(x = i; x < i + 8; x++){
					colorByte *= 2;
					colorByte += (imagemap[y * 128 + x] & 1);
				}
				[chrBuffer appendBytes:&colorByte length:1];
			}
			// High Bit
			for(y = j; y < j + 8; y++){
				colorByte = 0;
				for(x = i; x < i + 8; x++){
					colorByte *= 2;
					colorByte += ((imagemap[y * 128 + x] >> 1) & 1);
				}
				[chrBuffer appendBytes:&colorByte length:1];
			}
		}
	}

	NSLog(@"[4] CHR Data:\t\t%@", [chrBuffer description]);

	[chrBuffer writeToFile:@"CHR Test.raw" atomically:YES];

	// Write to a temporary file
//	NSString * path = [NSTemporaryDirectory() stringByAppendingPathComponent:[filename lastPathComponent]];
//	if (![bitmapData writeToURL:[NSURL fileURLWithPath:path] options:NSAtomicWrite error:nil]) {
//		NSLog(@"Couldn't write to temporary file.");
//	}

}
*/

// 524800 = Zelda 4BPP
// 553472 = Zelda 3BPP
// 196608 = GB Zelda 2BPP

- (IBAction) openDirectory:(id)sender{
	NSOpenPanel *sourceDir = [NSOpenPanel openPanel];
	[sourceDir setAllowsMultipleSelection:NO];
	[sourceDir setCanChooseDirectories:NO];
	[sourceDir setCanChooseFiles:YES];
	[sourceDir setCanCreateDirectories:NO];
	[sourceDir setResolvesAliases:YES];
	[sourceDir setTitle: NSLocalizedString(@"Import File", nil)];
	[sourceDir setPrompt: NSLocalizedString(@"Choose File", nil)];
	if([sourceDir runModalForTypes:nil] == NSFileHandlingPanelOKButton){
		[self setOffset: [NSNumber numberWithInt: 0]];
		[self setLayout: [layoutComboBox titleOfSelectedItem]];
		[self setMode: [modeComboBox titleOfSelectedItem]];
		[self setFilename: [sourceDir filename]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
	}
}

- (IBAction) incrementOffsetByOne:(id)sender{
//	if([currentOffset intValue] >= 1){
		[self setOffset: [NSNumber numberWithInt:[offset intValue] + 1]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
//	}
}

- (IBAction) decrementOffsetByOne:(id)sender{
	if([offset intValue] >= 1){
		[self setOffset: [NSNumber numberWithInt:[offset intValue] - 1]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
	}
}

- (IBAction) incrementOffsetByPage:(id)sender{
//	if([offset intValue] >= 1){
		[self setOffset: [NSNumber numberWithInt:[offset intValue] + 4096]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
//	}
}

- (IBAction) decrementOffsetByPage:(id)sender{
	if([offset intValue] >= 4096){
		[self setOffset: [NSNumber numberWithInt:[offset intValue] - 4096]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
	}
}

- (IBAction) offsetEntered:(id)sender{
	if(![offset isEqualToNumber:[NSNumber numberWithInt:[offsetField intValue]]]){
		[self setOffset: [NSNumber numberWithInt:[offsetField intValue]]];
		[offsetField setStringValue:[offset stringValue]];
		[self generateImage];
	}
}

- (IBAction) modeChanged:(id)sender{
	if(![mode isEqualToString:[modeComboBox titleOfSelectedItem]]){
		[self setMode: [modeComboBox titleOfSelectedItem]];
		[self generateImage];
	}
}

- (IBAction) colorChanged:(id)sender{
//	rgb[0] = (color & 0x000000FF);
//	rgb[1] = (color & 0x0000FF00)>>8;
//	rgb[2] = (color & 0x00FF0000)>>16;
	[palette replaceObjectAtIndex:[sender tag] withObject:[[sender color] hexData]];
	[self generateImage];
	NSLog(@"Pallete %d: %@", [sender tag], [[[self palette] objectAtIndex: [sender tag]] description]);
//	unsigned char color[3];
//	[[[self palette] objectAtIndex: [sender tag]] getBytes:&color length:3];
//	NSLog(@"Color: %02x %02x %02x", color[0], color[1], color[2]);
	
}

- (IBAction) saveImage:(id)sender{
	NSImage *image = [mainImageView image];
	[image setScalesWhenResized:NO];
	[image setSize:NSMakeSize(128.0, 128.0)];
	NSBitmapImageRep *imageRep = [[image representations] objectAtIndex: 0];

	NSData *imageData;
	imageData = [imageRep representationUsingType: NSPNGFileType properties: nil];

	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setCanCreateDirectories:YES];
	[savePanel setRequiredFileType:nil];
	[savePanel setNameFieldLabel:@"Save Image"];
	if([savePanel runModalForDirectory:NSHomeDirectory() file:@""] == NSFileHandlingPanelOKButton){
		[imageData writeToFile:[savePanel filename] atomically:YES];
	}
}

- (void) generateImage{
	NSMutableDictionary *thingsNeeded = [NSMutableDictionary dictionary];
	[thingsNeeded setObject:offset forKey:@"offset"];
	[thingsNeeded setObject:mode forKey:@"mode"];
	[thingsNeeded setObject:@"1" forKey:@"layout"];
	[thingsNeeded setObject:palette forKey:@"palette"];

	RomFileReader *imageReader = [RomFileReader parseFile:filename thingsNeeded:thingsNeeded];

	NSImage *snesImage = [[NSImage alloc] init];
	[snesImage addRepresentation: [imageReader valueForKey:@"image"]];
	[mainImageView setImage: snesImage];

	NSLog(@"[*] Image Done!");
}

/* Application Functions */
+ (void) initialize{}

- (void) awakeFromNib{
	[NSApp activateIgnoringOtherApps:YES];
	[[NSColorPanel sharedColorPanel] setShowsAlpha:NO];

	[self setOffset:0];
	[self setMode:@"2BPP GB/SNES"];
	[self setLayout:@"1"];

	unsigned char magicA[3] = { 0xF0, 0xA0, 0x68 };	// Light Skin
	unsigned char magicB[3] = { 0x28, 0x28, 0x28 };	// Black Border
	unsigned char magicC[3] = { 0xF8, 0x78, 0x00 };	// Hat Orange
	unsigned char magicD[3] = { 0xC0, 0x18, 0x20 };	// Red Boots
	unsigned char magicE[3] = { 0xE8, 0x60, 0xB0 };	// Hat Pink
	unsigned char magicF[3] = { 0x38, 0x90, 0x68 };	// Dark Seafoam Green Shirt
	unsigned char magicG[3] = { 0x40, 0xD8, 0x70 };	// Light Seafoam Green Shirt
	unsigned char magicH[3] = { 0x50, 0x90, 0x10 };	// Hat Dark Green
	unsigned char magicI[3] = { 0x78, 0xB8, 0x20 };	// Hat Light Green
	unsigned char magicJ[3] = { 0xE4, 0x90, 0x50 };	// Hand Skin
	unsigned char magicK[3] = { 0x8C, 0x58, 0x28 };	// Sleeve Brown
	unsigned char magicL[3] = { 0xFF, 0x00, 0xFF };	// ???
	unsigned char magicM[3] = { 0x00, 0x00, 0xFF };	// Alpha
	unsigned char magicN[3] = { 0xF8, 0xF8, 0xF8 };	// Eye White
	unsigned char magicO[3] = { 0xF0, 0xD8, 0x40 };	// Yellow Belt
	unsigned char magicP[3] = { 0xB8, 0x68, 0x20 };	// Dark Skin

	palette = [[NSMutableArray alloc] init];
	[palette addObject: [NSData dataWithBytes:magicA length:3]];
	[palette addObject: [NSData dataWithBytes:magicB length:3]];
	[palette addObject: [NSData dataWithBytes:magicC length:3]];
	[palette addObject: [NSData dataWithBytes:magicD length:3]];
	[palette addObject: [NSData dataWithBytes:magicE length:3]];
	[palette addObject: [NSData dataWithBytes:magicF length:3]];
	[palette addObject: [NSData dataWithBytes:magicG length:3]];
	[palette addObject: [NSData dataWithBytes:magicH length:3]];
	[palette addObject: [NSData dataWithBytes:magicI length:3]];
	[palette addObject: [NSData dataWithBytes:magicJ length:3]];
	[palette addObject: [NSData dataWithBytes:magicK length:3]];
	[palette addObject: [NSData dataWithBytes:magicL length:3]];
	[palette addObject: [NSData dataWithBytes:magicM length:3]];
	[palette addObject: [NSData dataWithBytes:magicN length:3]];
	[palette addObject: [NSData dataWithBytes:magicO length:3]];
	[palette addObject: [NSData dataWithBytes:magicP length:3]];
}

- (void) parsePalette:(NSString *)paletteFile{
	NSData *data = [NSData dataWithContentsOfFile:paletteFile];
	NSString *string = [NSString stringWithUTF8String:[data bytes]];

	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	for(NSString *line in lines){
		NSRange searchString = [line rangeOfString:@" "];
		NSUInteger index = 1;
		if(searchString.location != NSNotFound){
			NSArray *lineElements = [line componentsSeparatedByString:@" "];
			NSLog(@"Items: %@ %@ %@", [lineElements objectAtIndex:0], [lineElements objectAtIndex:1], [lineElements objectAtIndex:2]);
		}
	}
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification{
	[window makeKeyAndOrderFront:nil];
}

@synthesize menu;
@synthesize window;
@synthesize mainImageView;
@synthesize offsetField;
@synthesize modeComboBox;
@synthesize layoutComboBox;
@synthesize addOneByte;
@synthesize addOnePage;
@synthesize removeOneByte;
@synthesize removeOnePage;

@end

#import "AppDelegate.h"
#import "RomFileReader.h"
#import "HexColorAdditions.h"
#import "NSData+RSHexDump.h"
#import "NSBitmapImageRep+Gray.h"
#import "NSImage_BMPData.h"

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

#pragma mark -
#pragma mark Interface Functions

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
		NSImage *image = [[[NSImage alloc] initWithContentsOfFile:[sourceDir filename]] autorelease];
		[self processImage:image];
	}
}

- (IBAction) copy:(id)sender{
	NSImage* image = [mainImageView image]; 
	if(image != nil){
		NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
		[pasteboard clearContents];
		NSArray *copiedObjects = [NSArray arrayWithObject: image];
		[pasteboard writeObjects:copiedObjects];
	}
}

- (IBAction) paste:(id)sender{
	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	NSArray *classArray = [NSArray arrayWithObject:[NSImage class]];
	NSDictionary *options = [NSDictionary dictionary];
	if([pasteboard canReadObjectForClasses:classArray options:options]){
		NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
		NSImage *image = [objectsToPaste objectAtIndex:0];
		[self processImage:image];
	}
}

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
	[palette replaceObjectAtIndex:[sender tag] withObject:[[sender color] hexData]];
	[self generateImage];
	NSLog(@"Pallete %d: %@", [sender tag], [[[self palette] objectAtIndex: [sender tag]] description]);
//	unsigned char color[3];
//	rgb[0] = (color & 0x000000FF);
//	rgb[1] = (color & 0x0000FF00)>>8;
//	rgb[2] = (color & 0x00FF0000)>>16;	
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

- (IBAction) importPalette:(id)sender{
	NSOpenPanel *sourceDir = [NSOpenPanel openPanel];
	[sourceDir setAllowsMultipleSelection:NO];
	[sourceDir setCanChooseDirectories:NO];
	[sourceDir setCanChooseFiles:YES];
	[sourceDir setCanCreateDirectories:NO];
	[sourceDir setResolvesAliases:YES];
	[sourceDir setTitle: NSLocalizedString(@"Import Palette File", nil)];
	[sourceDir setPrompt: NSLocalizedString(@"Choose Palette", nil)];
	if([sourceDir runModalForTypes:nil] == NSFileHandlingPanelOKButton){
		[self parsePalette:[sourceDir filename]];
//		[self generateImage];
		[palettePanel makeKeyAndOrderFront:nil];
	}
}

#pragma mark -
#pragma mark Application Functions

- (void) processImage:(NSImage *)image{
	NSMutableDictionary *thingsNeeded = [NSMutableDictionary dictionary];
	[thingsNeeded setObject:offset forKey:@"offset"];
	[thingsNeeded setObject:mode forKey:@"mode"];
	[thingsNeeded setObject:@"1" forKey:@"layout"];
	[thingsNeeded setObject:palette forKey:@"palette"];
	
	imageReader = [RomFileReader parseFile:filename thingsNeeded:thingsNeeded];
	[imageReader encodeImage:image thingsNeeded:thingsNeeded];

//	NSImage *snesImage = [[[NSImage alloc] init] autorelease];
//	[snesImage addRepresentation: [imageReader valueForKey:@"image"]];
	[mainImageView setImage: image];
	
	NSLog(@"[*] Image Done!");
}

- (void) generateImage{
	NSMutableDictionary *thingsNeeded = [NSMutableDictionary dictionary];
	[thingsNeeded setObject:offset forKey:@"offset"];
	[thingsNeeded setObject:mode forKey:@"mode"];
	[thingsNeeded setObject:@"1" forKey:@"layout"];
	[thingsNeeded setObject:palette forKey:@"palette"];

	imageReader = [RomFileReader parseFile:filename thingsNeeded:thingsNeeded];
	NSImage *snesImage = [[[NSImage alloc] init] autorelease];
	[snesImage addRepresentation: [imageReader valueForKey:@"image"]];
	[mainImageView setImage: snesImage];

	NSLog(@"[*] Image Done!");
}

+ (void) initialize{}

- (void) awakeFromNib{
	[NSApp activateIgnoringOtherApps:YES];
	[[NSColorPanel sharedColorPanel] setShowsAlpha:NO];

	[self setOffset:[NSNumber numberWithInt: 0]];
	[self setMode:@"2BPP GB/SNES"];
	[self setLayout:@"1"];

	palette = [[NSMutableArray alloc] init];
	NSUInteger i = 1;
	NSView *content = [palettePanel contentView];
	unsigned char magic[3];
	for(i = 1; i <= 256; i++){
		magic[0] = random() % 256;
		magic[1] = random() % 256;
		magic[2] = random() % 256;
		[[content viewWithTag:i] setColor:[NSColor colorWithCalibratedRed:(magic[0] / 255.0) green:(magic[1] / 255.0) blue:(magic[2] / 255.0) alpha:1.0]];
		[palette addObject: [NSData dataWithBytes:magic length:3]];
	}
}

- (void) parsePalette:(NSString *)paletteFile{
	NSString *string = [[[NSString alloc] initWithContentsOfFile:paletteFile encoding:NSUTF8StringEncoding error:nil] autorelease];
	NSArray *lines = [string componentsSeparatedByString:@"\n"];
	NSUInteger index = 0;
	NSView *content = [palettePanel contentView];
	for(NSString *line in lines){
		NSRange searchString = [line rangeOfString:@" "];
		if(searchString.location != NSNotFound){
			NSArray *lineElements = [line componentsSeparatedByString:@" "];
			unsigned char magic[3] = {[[lineElements objectAtIndex:0] integerValue], [[lineElements objectAtIndex:1] integerValue], [[lineElements objectAtIndex:2] integerValue] };
			[[content viewWithTag:index+1] setColor:[NSColor colorWithCalibratedRed:(magic[0] / 255.0) green:(magic[1] / 255.0) blue:(magic[2] / 255.0) alpha:1.0]];
			[palette replaceObjectAtIndex:index withObject:[NSData dataWithBytes:magic length:3]];
			index++;
		}
	}
}

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification{
	[window makeKeyAndOrderFront:nil];
}

- (void)dealloc{
	[super dealloc];
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

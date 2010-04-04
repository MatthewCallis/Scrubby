#import "RomFileReader.h"
#import "NSImage_BMPData.h"
#import "HexColorAdditions.h"

#define NESspritesPerChr	512		// Sprites Stored in each CHR
#define NESromSpriteSize		16	// Datasize from ROM file (.nes) - 16 bytes
#define NESromSpriteChannelSize	8	// Half of the romSpriteSize (NESromSpriteSize / 2) = 8 bytes
#define RawSpriteWidth		8
#define RawSpriteSize		64		// Datasize from RAW file (.raw) - 8 x 8 bytes


@implementation RomFileReader

+ (RomFileReader *) parseFile:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded{
	NSParameterAssert(nil != inFullPath);
	RomFileReader *result = nil;

	result = [[self alloc] initWithFile:inFullPath thingsNeeded:thingsNeeded];
	return [result autorelease];
}

- (id) initWithFile:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded{
	if((self = [super init])){
		fullPath = [inFullPath retain];
		[self buildImage:fullPath thingsNeeded:thingsNeeded];
		return self;
	}
	return nil;
}

- (void) dealloc{
	[fullPath release];

	[super dealloc];
}

- (void) buildImage:(NSString *)inFullPath thingsNeeded:(NSDictionary *)thingsNeeded{
	NSDictionary *thingsIllNeed = thingsNeeded;
	NSUInteger offset = [[thingsIllNeed objectForKey:@"offset"] intValue];
	NSString *layout = [thingsIllNeed objectForKey:@"layout"];
	NSString *mode = [thingsIllNeed objectForKey:@"mode"];
	NSMutableArray *palette = [thingsIllNeed objectForKey:@"palette"];
	
	NSUInteger dataLength = 0;
	NSUInteger modeValue = 0;


	if([mode isEqualToString:@"1BPP Generic"]){
		// 1BPP
		NSUInteger columnCount = 16;
		NSUInteger chrIndex = 1;
		NSUInteger fromIndex = 0;
		NSUInteger toIndex = 255;
		modeValue = 0;
		dataLength = 2048;
	}
	else if([mode isEqualToString:@"2BPP NES"]){
		// NES
		NSUInteger columnCount = 16;
		NSUInteger chrIndex = 1;
		NSUInteger fromIndex = 1;
		NSUInteger toIndex = 512;
		modeValue = 1;
		dataLength = 4096;	// (16 rows * 16 bytes) x 16 columns = 4096 bytes
	}	
	else if([mode isEqualToString:@"2BPP GB/SNES"]){
		// Gameboy 2BPP
		NSUInteger columnCount = 16;
		NSUInteger chrIndex = 1;
		NSUInteger fromIndex = 0;
		NSUInteger toIndex = 255;
		modeValue = 2;
		dataLength = 4096;	// (16 rows * 16 bytes) x 16 columns = 4096 bytes
	}
	else if([mode isEqualToString:@"3BPP SNES"]){
		// SNES 3BPP
		modeValue = 3;
		dataLength = 6144;	// (16 rows * 24 bytes) * 16 columns = 6144 bytes
	}
	else if([mode isEqualToString:@"4BPP SNES"]){
		// SNES
		modeValue = 4;
		dataLength = 8192;	// (16 rows * 32 bytes) * 16 columns = 8192 bytes
	}
	else if([mode isEqualToString:@"8BPP SNES"]){
		// SNES
		modeValue = 8;
		dataLength = 16384;	// (16 rows * 64 bytes) * 16 columns = 16384 bytes
	}
	else{
		// Unknown
	}

	NSUInteger columnCount = 16;
	NSUInteger chrIndex = 1;
	NSUInteger fromIndex = 0;
	NSUInteger toIndex = 255;
	
	//	if(mode == 0)	columnCount = 16;
	//	else			columnCount = 8;
	
	NSLog(@"\tFile Name:\t %@", fullPath);
	NSLog(@"\tColumn Count:\t%d", columnCount);
	NSLog(@"\tCHR Index:\t%d", chrIndex);
	NSLog(@"\tFrom Index:\t%d", fromIndex);
	NSLog(@"\tTo Index:\t%d", toIndex);
	
	NSUInteger dataSize = ((toIndex - fromIndex + 1) * RawSpriteSize);
	NSLog(@"\tData Size:\t%d", dataSize);
	
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:fullPath];
	NSData *chrBank;
	if(!offset) offset = 0;
	[fileHandle seekToFileOffset: offset];
	chrBank = [fileHandle readDataOfLength: dataLength];
//	NSLog(@"%@", [chrBuffer description]);
	NSLog(@"[*] Got Sprite Bank!");
	
	NSArray *spriteData = [self getSpriteDataRangeFromChrBank:chrBank start:fromIndex end:toIndex mode:modeValue mapping:0];
	if([spriteData count] <= 0) NSLog(@"Can't retrieve sprite data from file!");

	NSArray *cSprite = [self makeCompoundSprite:spriteData size:dataSize columns:columnCount mode:modeValue];
	if([cSprite count] <= 0) NSLog(@"Can't create compound sprite!");
	
	[self setValue:[self makeBitmapData:cSprite palette:palette] forKey:@"image"];

	NSLog(@"[*] Image Done!");
}

- (NSArray *) getSpriteDataFromChrBank:(NSData *)chrData number:(NSUInteger)number mode:(NSUInteger)mode{
	NSLog(@"Number: %d", number);
	NSLog(@"Data Size: %d", [chrData length]);
	// gets the nth sprite from the CHR data and returns the composite data
	// first sprite = 0
	NSMutableArray *compositeArray = [NSMutableArray array];
	const unsigned char *chrBuffer = [chrData bytes];

	if(number < 0 || (number > 255 && mode != 1) || number > 512 || [chrData length] <= 0){
		return NULL;
	}

	NSUInteger i = 0;
	NSUInteger j = 0;
	unsigned char tile_a;
	unsigned char tile_b;
	unsigned char tile_c;
	unsigned char tile_d;
	unsigned char tile_e;
	unsigned char tile_f;
	unsigned char tile_g;
	unsigned char tile_h;
	unsigned char colorBit;
	unsigned char mask = 0x80;

	if(mode == 0){
		// 1BPP Generic
		for(j = 0; j < 8; j++){
			mask = 0x80;
			tile_a = chrBuffer[number * 8 + j * 2];
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	else if(mode == 1){
		// NES 2BPP
		unsigned char channel_a[8], channel_b[NESromSpriteChannelSize];

		for(i = 0; i < 8; i++){
			channel_a[i] = chrBuffer[NESromSpriteSize * number + i];
			channel_b[i] = chrBuffer[NESromSpriteSize * number + i + 8];
		}

		for(i = 0; i < 8; i++){
			for(j = 7; j < -1; j--){
				[compositeArray addObject: [NSNumber numberWithInt:(((channel_a[i] >> j) & 1) | (((channel_b[i] >> j) & 1) << 1)) + 1]];
			}
		}
	}
	else if(mode == 2){
		// Gameboy 2BPP		
		for(j = 0; j < 8; j++){
			mask = 0x80;
			tile_a = chrBuffer[number * 16 + j * 2];
			tile_b = chrBuffer[number * 16 + j * 2 + 1];
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				colorBit += ((tile_b & mask) ? 2 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	else if(mode == 3){
		// SNES 3BPP
		/*	3Bit Bitplane: 8x8, 8 colors, 24 bytes
		 Zelda:
		 553472 / 87200	Weapons
		 Final Fantasy 2:
		 295424 / 48200	Enemies
		 374040 / 5B518	Characters
		 407744 / 638C0	More Characters
		 */
		for(j = 0; j < 8; j++){
			mask = 0x80;
			// Step 2. Parse the bitplanes
			tile_a = chrBuffer[number * 24 + j * 2];
			tile_b = chrBuffer[number * 24 + j * 2 + 1];
			tile_c = chrBuffer[number * 24 + j + 16];
			// Step 3. Compute one row of pixels
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				colorBit += ((tile_b & mask) ? 2 : 0);
				colorBit += ((tile_c & mask) ? 4 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	else if(mode == 4){
		// SNES 4BPP
		/*	4Bit Bitplane: 8x8, 16 colors, 32 bytes
		 Zelda:
		 524800 / 80200	Link
		 Final Fantasy 2:
		 852480 / D0200	Characters
		 */
		// Step 1. Do one row of pixels
		for(j = 0; j < 8; j++){
			mask = 0x80;
			// Step 2. Parse the bitplanes
			tile_a = chrBuffer[number * 32 + j * 2];
			tile_b = chrBuffer[number * 32 + j * 2 + 1];
			tile_c = chrBuffer[number * 32 + j * 2 + 16];
			tile_d = chrBuffer[number * 32 + j * 2 + 17];
			// Step 3. Compute one row of pixels
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				colorBit += ((tile_b & mask) ? 2 : 0);
				colorBit += ((tile_c & mask) ? 4 : 0);
				colorBit += ((tile_d & mask) ? 8 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	else if(mode == 3){
		// SNES 8BPP
		// Step 1. Do one row of pixels
		for(j = 0; j < 8; j++){
			mask = 0x80;
			// Step 2. Parse the bitplanes
			tile_a = chrBuffer[number * 32 + j * 2];
			tile_b = chrBuffer[number * 32 + j * 2 + 1];
			tile_c = chrBuffer[number * 32 + j * 2 + 16];
			tile_d = chrBuffer[number * 32 + j * 2 + 17];
			tile_e = chrBuffer[number * 32 + j * 2 + 32];
			tile_f = chrBuffer[number * 32 + j * 2 + 33];
			tile_g = chrBuffer[number * 32 + j * 2 + 48];
			tile_h = chrBuffer[number * 32 + j * 2 + 49];
			// Step 3. Compute one row of pixels
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				colorBit += ((tile_b & mask) ? 2 : 0);
				colorBit += ((tile_c & mask) ? 4 : 0);
				colorBit += ((tile_d & mask) ? 8 : 0);
				colorBit += ((tile_e & mask) ? 16 : 0);
				colorBit += ((tile_f & mask) ? 32 : 0);
				colorBit += ((tile_g & mask) ? 64 : 0);
				colorBit += ((tile_h & mask) ? 128 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	return compositeArray;
}

- (NSArray *) getSpriteDataRangeFromChrBank:(NSData *)chrData start:(NSUInteger)startIndex end:(NSUInteger)endIndex mode:(NSUInteger)mode mapping:(NSUInteger)mapping{
	NSLog(@"[*] Extracting Sprite Range...");
	NSLog(@"[*] Start to Finish: %d ... %d", startIndex, endIndex);
//	if(!chrData || startIndex < 0 || endIndex > NESspritesPerChr) return NULL;
	if(!chrData || startIndex < 0 || endIndex > 255){
		NSLog(@"[!] Something missing or out of bounds!");
		return NULL;
	}

	/*
	 AB EF
	 CD GH	*/
	unsigned char var16x16a[256] = { 
		0,   1,   4,   5,   8,   9,   12,  13,  16,  17,  20,  21,  24,  25,  28,  29,
		2,   3,   6,   7,   10,  11,  14,  15,  18,  19,  22,  23,  26,  27,  30,  31,
		32,  33,  36,  37,  40,  41,  44,  45,  48,  49,  52,  53,  56,  57,  60,  61,
		34,  35,  38,  39,  42,  43,  46,  47,  50,  51,  54,  55,  58,  59,  62,  63,
		64,  65,  68,  69,  72,  73,  76,  77,  80,  81,  84,  85,  88,  89,  92,  93,
		66,  67,  70,  71,  74,  75,  78,  79,  82,  83,  86,  87,  90,  91,  94,  95,
		96,  97,  100, 101, 104, 105, 108, 109, 112, 113, 116, 117, 120, 121, 124, 125,
		98,  99,  102, 103, 106, 107, 110, 111, 114, 115, 118, 119, 122, 123, 126, 127,
		128, 129, 132, 133, 136, 137, 140, 141, 144, 145, 148, 149, 152, 153, 156, 157,
		130, 131, 134, 135, 138, 139, 142, 143, 146, 147, 150, 151, 154, 155, 158, 159,
		160, 161, 164, 165, 168, 169, 172, 173, 176, 177, 180, 181, 184, 185, 188, 189,
		162, 163, 166, 167, 170, 171, 174, 175, 178, 179, 182, 183, 186, 187, 190, 191,
		192, 193, 196, 197, 200, 201, 204, 205, 208, 209, 212, 213, 216, 217, 220, 221,
		194, 195, 198, 199, 202, 203, 206, 207, 210, 211, 214, 215, 218, 219, 222, 223,
		224, 225, 228, 229, 232, 233, 236, 237, 240, 241, 244, 245, 248, 249, 252, 253,
		226, 227, 230, 231, 234, 235, 238, 239, 242, 243, 246, 247, 250, 251, 254, 255	};
	/*
	 AC EG
	 BD FH	*/
	unsigned char var16x16b[256] = {
		0,   2,   4,   6,   8,   10,  12,  14,  16,  18,  20,  22,  24,  26,  28,  30,
		1,   3,   5,   7,   9,   11,  13,  15,  17,  19,  21,  23,  25,  27,  29,  31,
		32,  34,  36,  38,  40,  42,  44,  46,  48,  50,  52,  54,  56,  58,  60,  62,
		33,  35,  37,  39,  41,  43,  45,  47,  49,  51,  53,  55,  57,  59,  61,  63,
		64,  66,  68,  70,  72,  74,  76,  78,  80,  82,  84,  86,  88,  90,  92,  94,
		65,  67,  69,  71,  73,  75,  77,  79,  81,  83,  85,  87,  89,  91,  93,  95,
		96,  98,  100, 102, 104, 106, 108, 110, 112, 114, 116, 118, 120, 122, 124, 126,
		97,  99,  101, 103, 105, 107, 109, 111, 113, 115, 117, 119, 121, 123, 125, 127,
		128, 130, 132, 134, 136, 138, 140, 142, 144, 146, 148, 150, 152, 154, 156, 158,
		129, 131, 133, 135, 137, 139, 141, 143, 145, 147, 149, 151, 153, 155, 157, 159,
		160, 162, 164, 166, 168, 170, 172, 174, 176, 178, 180, 182, 184, 186, 188, 190,
		161, 163, 165, 167, 169, 171, 173, 175, 177, 179, 181, 183, 185, 187, 189, 191,
		192, 194, 196, 198, 200, 202, 204, 206, 208, 210, 212, 214, 216, 218, 220, 222,
		193, 195, 197, 199, 201, 203, 205, 207, 209, 211, 213, 215, 217, 219, 221, 223,
		224, 226, 228, 230, 232, 234, 236, 238, 240, 242, 244, 246, 248, 250, 252, 254,
		225, 227, 229, 231, 233, 235, 237, 239, 241, 243, 245, 247, 249, 251, 253, 255	};

	NSMutableArray *spriteData = [NSMutableArray array];
	NSUInteger i = 0;
	NSUInteger j = 0;
	for(i = startIndex; i <= endIndex; i++){
		// In what order are we building the sprites?
		NSUInteger buildIndex;
		switch(mapping){
			case 0:
				buildIndex = i;
				break;
			case 1:
				buildIndex = var16x16a[i];
				break;
			case 2:
				buildIndex = var16x16b[i];
				break;
			default:
				buildIndex = i;
				break;
		}

		// Get the Sprite
		NSArray *sprite = [self getSpriteDataFromChrBank:chrData number:buildIndex mode:mode];
		if(!sprite) return NULL;

		// Write it to the buffer
		for(j = 0; j < RawSpriteSize; j++){
			NSUInteger spriteIndex = ((i - startIndex) * RawSpriteSize + j);
			[spriteData insertObject:[sprite objectAtIndex:j] atIndex:spriteIndex];
		}
		//	NSLog(@"spriteData: %d", [spriteData count] / 64);
	}
	NSLog(@"[*] All Sprites Retrieved!");
	return spriteData;
}

- (NSArray *) makeCompoundSprite:(NSArray *)spriteData size:(NSUInteger)size columns:(NSUInteger)columns mode:(NSUInteger)mode{
	if([spriteData count] <= 0) return NULL;
	
	NSUInteger finalWidth = columns * RawSpriteWidth;	// Columns * Sprite Width
	NSUInteger totalSprites = (size / RawSpriteSize);	// Size / Raw Sprite Size
	NSUInteger rows = (totalSprites / columns);
	
//	NSLog(@"[*] Compound Sprite: mode         %@", mode);
	NSLog(@"[*] Compound Sprite: rows         %d", rows);
	NSLog(@"[*] Compound Sprite: columns      %d", columns);
	NSLog(@"[*] Compound Sprite: finalWidth   %d", finalWidth);
	NSLog(@"[*] Compound Sprite: totalSprites %d", totalSprites);
	NSLog(@"[*] Compound Sprite: size         %d", size);
	
	// Where the big sprite will be drawn
	NSMutableArray *finalData = [NSMutableArray array];
	NSUInteger curCol = 0;			// Column of sprites (0 based indexes)
	NSUInteger currentRow = 0;		// Row of sprites (0 based indexes)
	NSUInteger spriteRow = 0;		// What row of pixels we're on on the sprite (0 based index)
	NSUInteger i = 0;				// Which pixel in the row
	NSUInteger curSprite = 0;		// The sprite we are currently on.
	NSUInteger spriteWidth = 8;

	NSLog(@"[*] Compound Sprite starting...");
	for(currentRow = 0; currentRow < rows; currentRow++){				// Row of sprites
		for(spriteRow = 0; spriteRow < spriteWidth; spriteRow++){		// Row of pixels
			for(curCol = 0; curCol < columns; curCol++){				// Column of sprites
				// Depending on what the mode is, set the current sprite.
				//	if(mode == 0)	curSprite = (currentRow * columns) + curCol;
				//	else			curSprite = (currentRow * columns) + curCol;
				
				curSprite = (currentRow * columns) + curCol;
				
				// Pixel
				for(i = 0; i < spriteWidth; i++){
					NSUInteger spriteIndex = ((curSprite * RawSpriteSize) + (spriteRow * spriteWidth) + i);
					NSUInteger finalIndex = ((currentRow * RawSpriteSize * columns) + (spriteRow * finalWidth) + (curCol * spriteWidth) + i);
					[finalData insertObject: [spriteData objectAtIndex: spriteIndex] atIndex: finalIndex];
				}
			}
		}
	}
	NSLog(@"[*] Compound Sprite Finished!");
	return finalData;
}

- (NSBitmapImageRep *) makeBitmapData:(NSArray *)compoundData palette:(NSMutableArray *)palette{
	NSLog(@"[*] Building Bitmap...");
	
	//	Gameboy Palette
	unsigned char magicBlack[3] = { 0x00, 0x00, 0x01 };	// Black
	unsigned char magicDGray[3] = { 0x78, 0x78, 0x78 };	// Dark Gray
	unsigned char magicLGray[3] = { 0xB0, 0xB0, 0xB0 };	// Light Gray
	unsigned char magicWhite[3] = { 0xFF, 0xFF, 0xFE };	// White

	// SNES Zelda Palette
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

	// NES Super Mario Bros. Palette
	unsigned char magicRed[3] =		{ 0xE0, 0x50, 0x00 };
	unsigned char magicBrown[3] =	{ 0x88, 0x88, 0x00 };
	unsigned char magicYellow[3] =	{ 0xFF, 0xA0, 0x00 };
	unsigned char magicBlue[3] =	{ 0x50, 0x80, 0xFF };

	NSMutableData *imageBuffer = [NSMutableData data];
	NSUInteger rawDataLength = [compoundData count];
	for(id loopItem2 in compoundData){
		NSUInteger currentPixel = [loopItem2 charValue];
		//		NSLog(@"Pixel: %@", currentPixel);
		switch(currentPixel){
			case 0:  [imageBuffer appendData:[palette objectAtIndex:1]]; break;
			case 1:  [imageBuffer appendData:[palette objectAtIndex:2]]; break;
			case 2:  [imageBuffer appendData:[palette objectAtIndex:3]]; break;
			case 3:  [imageBuffer appendData:[palette objectAtIndex:4]]; break;
			case 4:  [imageBuffer appendData:[palette objectAtIndex:5]]; break;
			case 5:  [imageBuffer appendData:[palette objectAtIndex:6]]; break;
			case 6:  [imageBuffer appendData:[palette objectAtIndex:7]]; break;
			case 7:  [imageBuffer appendData:[palette objectAtIndex:8]]; break;
			case 8:  [imageBuffer appendData:[palette objectAtIndex:9]]; break;
			case 9:  [imageBuffer appendData:[palette objectAtIndex:10]]; break;
			case 10: [imageBuffer appendData:[palette objectAtIndex:11]]; break;
			case 11: [imageBuffer appendData:[palette objectAtIndex:12]]; break;
			case 12: [imageBuffer appendData:[palette objectAtIndex:13]]; break;
			case 13: [imageBuffer appendData:[palette objectAtIndex:14]]; break;
			case 14: [imageBuffer appendData:[palette objectAtIndex:15]]; break;
			case 15: [imageBuffer appendData:[palette objectAtIndex:16]]; break;
			case 16: [imageBuffer appendData:[palette objectAtIndex:17]]; break;
			case 17: [imageBuffer appendData:[palette objectAtIndex:18]]; break;
			case 18: [imageBuffer appendData:[palette objectAtIndex:19]]; break;
			case 19: [imageBuffer appendData:[palette objectAtIndex:20]]; break;
			case 20: [imageBuffer appendData:[palette objectAtIndex:21]]; break;
			case 21: [imageBuffer appendData:[palette objectAtIndex:22]]; break;
			case 22: [imageBuffer appendData:[palette objectAtIndex:23]]; break;
			case 23: [imageBuffer appendData:[palette objectAtIndex:24]]; break;
			case 24: [imageBuffer appendData:[palette objectAtIndex:25]]; break;
			case 25: [imageBuffer appendData:[palette objectAtIndex:26]]; break;
			case 26: [imageBuffer appendData:[palette objectAtIndex:27]]; break;
			case 27: [imageBuffer appendData:[palette objectAtIndex:28]]; break;
			case 28: [imageBuffer appendData:[palette objectAtIndex:29]]; break;
			case 29: [imageBuffer appendData:[palette objectAtIndex:30]]; break;
			case 30: [imageBuffer appendData:[palette objectAtIndex:31]]; break;
			case 31: [imageBuffer appendData:[palette objectAtIndex:32]]; break;
			case 32: [imageBuffer appendData:[palette objectAtIndex:33]]; break;
			case 33: [imageBuffer appendData:[palette objectAtIndex:34]]; break;
			case 34: [imageBuffer appendData:[palette objectAtIndex:35]]; break;
			case 35: [imageBuffer appendData:[palette objectAtIndex:36]]; break;
			case 36: [imageBuffer appendData:[palette objectAtIndex:37]]; break;
			case 37: [imageBuffer appendData:[palette objectAtIndex:38]]; break;
			case 38: [imageBuffer appendData:[palette objectAtIndex:39]]; break;
			case 39: [imageBuffer appendData:[palette objectAtIndex:40]]; break;
			case 40: [imageBuffer appendData:[palette objectAtIndex:41]]; break;
			case 41: [imageBuffer appendData:[palette objectAtIndex:42]]; break;
			case 42: [imageBuffer appendData:[palette objectAtIndex:43]]; break;
			case 43: [imageBuffer appendData:[palette objectAtIndex:44]]; break;
			case 44: [imageBuffer appendData:[palette objectAtIndex:45]]; break;
			case 45: [imageBuffer appendData:[palette objectAtIndex:46]]; break;
			case 46: [imageBuffer appendData:[palette objectAtIndex:47]]; break;
			case 47: [imageBuffer appendData:[palette objectAtIndex:48]]; break;
			case 48: [imageBuffer appendData:[palette objectAtIndex:49]]; break;
			case 49: [imageBuffer appendData:[palette objectAtIndex:50]]; break;
			case 50: [imageBuffer appendData:[palette objectAtIndex:51]]; break;
			case 51: [imageBuffer appendData:[palette objectAtIndex:52]]; break;
			case 52: [imageBuffer appendData:[palette objectAtIndex:53]]; break;
			case 53: [imageBuffer appendData:[palette objectAtIndex:54]]; break;
			case 54: [imageBuffer appendData:[palette objectAtIndex:55]]; break;
			case 55: [imageBuffer appendData:[palette objectAtIndex:56]]; break;
			case 56: [imageBuffer appendData:[palette objectAtIndex:57]]; break;
			case 57: [imageBuffer appendData:[palette objectAtIndex:58]]; break;
			case 58: [imageBuffer appendData:[palette objectAtIndex:59]]; break;
			case 59: [imageBuffer appendData:[palette objectAtIndex:60]]; break;
			case 60: [imageBuffer appendData:[palette objectAtIndex:61]]; break;
			case 61: [imageBuffer appendData:[palette objectAtIndex:62]]; break;
			case 62: [imageBuffer appendData:[palette objectAtIndex:63]]; break;
			case 63: [imageBuffer appendData:[palette objectAtIndex:64]]; break;
			case 64: [imageBuffer appendData:[palette objectAtIndex:65]]; break;
			case 65: [imageBuffer appendData:[palette objectAtIndex:66]]; break;
			case 66: [imageBuffer appendData:[palette objectAtIndex:67]]; break;
			case 67: [imageBuffer appendData:[palette objectAtIndex:68]]; break;
			case 68: [imageBuffer appendData:[palette objectAtIndex:69]]; break;
			case 69: [imageBuffer appendData:[palette objectAtIndex:70]]; break;
			case 70: [imageBuffer appendData:[palette objectAtIndex:71]]; break;
			case 71: [imageBuffer appendData:[palette objectAtIndex:72]]; break;
			case 72: [imageBuffer appendData:[palette objectAtIndex:73]]; break;
			case 73: [imageBuffer appendData:[palette objectAtIndex:74]]; break;
			case 74: [imageBuffer appendData:[palette objectAtIndex:75]]; break;
			case 75: [imageBuffer appendData:[palette objectAtIndex:76]]; break;
			case 76: [imageBuffer appendData:[palette objectAtIndex:77]]; break;
			case 77: [imageBuffer appendData:[palette objectAtIndex:78]]; break;
			case 78: [imageBuffer appendData:[palette objectAtIndex:79]]; break;
			case 79: [imageBuffer appendData:[palette objectAtIndex:80]]; break;
			case 80: [imageBuffer appendData:[palette objectAtIndex:81]]; break;
			case 81: [imageBuffer appendData:[palette objectAtIndex:82]]; break;
			case 82: [imageBuffer appendData:[palette objectAtIndex:83]]; break;
			case 83: [imageBuffer appendData:[palette objectAtIndex:84]]; break;
			case 84: [imageBuffer appendData:[palette objectAtIndex:85]]; break;
			case 85: [imageBuffer appendData:[palette objectAtIndex:86]]; break;
			case 86: [imageBuffer appendData:[palette objectAtIndex:87]]; break;
			case 87: [imageBuffer appendData:[palette objectAtIndex:88]]; break;
			case 88: [imageBuffer appendData:[palette objectAtIndex:89]]; break;
			case 89: [imageBuffer appendData:[palette objectAtIndex:90]]; break;
			case 90: [imageBuffer appendData:[palette objectAtIndex:91]]; break;
			case 91: [imageBuffer appendData:[palette objectAtIndex:92]]; break;
			case 92: [imageBuffer appendData:[palette objectAtIndex:93]]; break;
			case 93: [imageBuffer appendData:[palette objectAtIndex:94]]; break;
			case 94: [imageBuffer appendData:[palette objectAtIndex:95]]; break;
			case 95: [imageBuffer appendData:[palette objectAtIndex:96]]; break;
			case 96: [imageBuffer appendData:[palette objectAtIndex:97]]; break;
			case 97: [imageBuffer appendData:[palette objectAtIndex:98]]; break;
			case 98: [imageBuffer appendData:[palette objectAtIndex:99]]; break;
			case  99: [imageBuffer appendData:[palette objectAtIndex:100]]; break;
			case 100: [imageBuffer appendData:[palette objectAtIndex:101]]; break;
			case 101: [imageBuffer appendData:[palette objectAtIndex:102]]; break;
			case 102: [imageBuffer appendData:[palette objectAtIndex:103]]; break;
			case 103: [imageBuffer appendData:[palette objectAtIndex:104]]; break;
			case 104: [imageBuffer appendData:[palette objectAtIndex:105]]; break;
			case 105: [imageBuffer appendData:[palette objectAtIndex:106]]; break;
			case 106: [imageBuffer appendData:[palette objectAtIndex:107]]; break;
			case 107: [imageBuffer appendData:[palette objectAtIndex:108]]; break;
			case 108: [imageBuffer appendData:[palette objectAtIndex:109]]; break;
			case 109: [imageBuffer appendData:[palette objectAtIndex:110]]; break;
			case 110: [imageBuffer appendData:[palette objectAtIndex:111]]; break;
			case 111: [imageBuffer appendData:[palette objectAtIndex:112]]; break;
			case 112: [imageBuffer appendData:[palette objectAtIndex:113]]; break;
			case 113: [imageBuffer appendData:[palette objectAtIndex:114]]; break;
			case 114: [imageBuffer appendData:[palette objectAtIndex:115]]; break;
			case 115: [imageBuffer appendData:[palette objectAtIndex:116]]; break;
			case 116: [imageBuffer appendData:[palette objectAtIndex:117]]; break;
			case 117: [imageBuffer appendData:[palette objectAtIndex:118]]; break;
			case 118: [imageBuffer appendData:[palette objectAtIndex:119]]; break;
			case 119: [imageBuffer appendData:[palette objectAtIndex:120]]; break;
			case 120: [imageBuffer appendData:[palette objectAtIndex:121]]; break;
			case 121: [imageBuffer appendData:[palette objectAtIndex:122]]; break;
			case 122: [imageBuffer appendData:[palette objectAtIndex:123]]; break;
			case 123: [imageBuffer appendData:[palette objectAtIndex:124]]; break;
			case 124: [imageBuffer appendData:[palette objectAtIndex:125]]; break;
			case 125: [imageBuffer appendData:[palette objectAtIndex:126]]; break;
			case 126: [imageBuffer appendData:[palette objectAtIndex:127]]; break;
			case 127: [imageBuffer appendData:[palette objectAtIndex:128]]; break;
			case 128: [imageBuffer appendData:[palette objectAtIndex:129]]; break;
			case 129: [imageBuffer appendData:[palette objectAtIndex:130]]; break;
			case 130: [imageBuffer appendData:[palette objectAtIndex:131]]; break;
			case 131: [imageBuffer appendData:[palette objectAtIndex:132]]; break;
			case 132: [imageBuffer appendData:[palette objectAtIndex:133]]; break;
			case 133: [imageBuffer appendData:[palette objectAtIndex:134]]; break;
			case 134: [imageBuffer appendData:[palette objectAtIndex:135]]; break;
			case 135: [imageBuffer appendData:[palette objectAtIndex:136]]; break;
			case 136: [imageBuffer appendData:[palette objectAtIndex:137]]; break;
			case 137: [imageBuffer appendData:[palette objectAtIndex:138]]; break;
			case 138: [imageBuffer appendData:[palette objectAtIndex:139]]; break;
			case 139: [imageBuffer appendData:[palette objectAtIndex:140]]; break;
			case 140: [imageBuffer appendData:[palette objectAtIndex:141]]; break;
			case 141: [imageBuffer appendData:[palette objectAtIndex:142]]; break;
			case 142: [imageBuffer appendData:[palette objectAtIndex:143]]; break;
			case 143: [imageBuffer appendData:[palette objectAtIndex:144]]; break;
			case 144: [imageBuffer appendData:[palette objectAtIndex:145]]; break;
			case 145: [imageBuffer appendData:[palette objectAtIndex:146]]; break;
			case 146: [imageBuffer appendData:[palette objectAtIndex:147]]; break;
			case 147: [imageBuffer appendData:[palette objectAtIndex:148]]; break;
			case 148: [imageBuffer appendData:[palette objectAtIndex:149]]; break;
			case 149: [imageBuffer appendData:[palette objectAtIndex:150]]; break;
			case 150: [imageBuffer appendData:[palette objectAtIndex:151]]; break;
			case 151: [imageBuffer appendData:[palette objectAtIndex:152]]; break;
			case 152: [imageBuffer appendData:[palette objectAtIndex:153]]; break;
			case 153: [imageBuffer appendData:[palette objectAtIndex:154]]; break;
			case 154: [imageBuffer appendData:[palette objectAtIndex:155]]; break;
			case 155: [imageBuffer appendData:[palette objectAtIndex:156]]; break;
			case 156: [imageBuffer appendData:[palette objectAtIndex:157]]; break;
			case 157: [imageBuffer appendData:[palette objectAtIndex:158]]; break;
			case 158: [imageBuffer appendData:[palette objectAtIndex:159]]; break;
			case 159: [imageBuffer appendData:[palette objectAtIndex:160]]; break;
			case 160: [imageBuffer appendData:[palette objectAtIndex:161]]; break;
			case 161: [imageBuffer appendData:[palette objectAtIndex:162]]; break;
			case 162: [imageBuffer appendData:[palette objectAtIndex:163]]; break;
			case 163: [imageBuffer appendData:[palette objectAtIndex:164]]; break;
			case 164: [imageBuffer appendData:[palette objectAtIndex:165]]; break;
			case 165: [imageBuffer appendData:[palette objectAtIndex:166]]; break;
			case 166: [imageBuffer appendData:[palette objectAtIndex:167]]; break;
			case 167: [imageBuffer appendData:[palette objectAtIndex:168]]; break;
			case 168: [imageBuffer appendData:[palette objectAtIndex:169]]; break;
			case 169: [imageBuffer appendData:[palette objectAtIndex:170]]; break;
			case 170: [imageBuffer appendData:[palette objectAtIndex:171]]; break;
			case 171: [imageBuffer appendData:[palette objectAtIndex:172]]; break;
			case 172: [imageBuffer appendData:[palette objectAtIndex:173]]; break;
			case 173: [imageBuffer appendData:[palette objectAtIndex:174]]; break;
			case 174: [imageBuffer appendData:[palette objectAtIndex:175]]; break;
			case 175: [imageBuffer appendData:[palette objectAtIndex:176]]; break;
			case 176: [imageBuffer appendData:[palette objectAtIndex:177]]; break;
			case 177: [imageBuffer appendData:[palette objectAtIndex:178]]; break;
			case 178: [imageBuffer appendData:[palette objectAtIndex:179]]; break;
			case 179: [imageBuffer appendData:[palette objectAtIndex:180]]; break;
			case 180: [imageBuffer appendData:[palette objectAtIndex:181]]; break;
			case 181: [imageBuffer appendData:[palette objectAtIndex:182]]; break;
			case 182: [imageBuffer appendData:[palette objectAtIndex:183]]; break;
			case 183: [imageBuffer appendData:[palette objectAtIndex:184]]; break;
			case 184: [imageBuffer appendData:[palette objectAtIndex:185]]; break;
			case 185: [imageBuffer appendData:[palette objectAtIndex:186]]; break;
			case 186: [imageBuffer appendData:[palette objectAtIndex:187]]; break;
			case 187: [imageBuffer appendData:[palette objectAtIndex:188]]; break;
			case 188: [imageBuffer appendData:[palette objectAtIndex:189]]; break;
			case 189: [imageBuffer appendData:[palette objectAtIndex:190]]; break;
			case 190: [imageBuffer appendData:[palette objectAtIndex:191]]; break;
			case 191: [imageBuffer appendData:[palette objectAtIndex:192]]; break;
			case 192: [imageBuffer appendData:[palette objectAtIndex:193]]; break;
			case 193: [imageBuffer appendData:[palette objectAtIndex:194]]; break;
			case 194: [imageBuffer appendData:[palette objectAtIndex:195]]; break;
			case 195: [imageBuffer appendData:[palette objectAtIndex:196]]; break;
			case 196: [imageBuffer appendData:[palette objectAtIndex:197]]; break;
			case 197: [imageBuffer appendData:[palette objectAtIndex:198]]; break;
			case 198: [imageBuffer appendData:[palette objectAtIndex:199]]; break;
			case 199: [imageBuffer appendData:[palette objectAtIndex:200]]; break;
			case 200: [imageBuffer appendData:[palette objectAtIndex:201]]; break;
			case 201: [imageBuffer appendData:[palette objectAtIndex:202]]; break;
			case 202: [imageBuffer appendData:[palette objectAtIndex:203]]; break;
			case 203: [imageBuffer appendData:[palette objectAtIndex:204]]; break;
			case 204: [imageBuffer appendData:[palette objectAtIndex:205]]; break;
			case 205: [imageBuffer appendData:[palette objectAtIndex:206]]; break;
			case 206: [imageBuffer appendData:[palette objectAtIndex:207]]; break;
			case 207: [imageBuffer appendData:[palette objectAtIndex:208]]; break;
			case 208: [imageBuffer appendData:[palette objectAtIndex:209]]; break;
			case 209: [imageBuffer appendData:[palette objectAtIndex:210]]; break;
			case 210: [imageBuffer appendData:[palette objectAtIndex:211]]; break;
			case 211: [imageBuffer appendData:[palette objectAtIndex:212]]; break;
			case 212: [imageBuffer appendData:[palette objectAtIndex:213]]; break;
			case 213: [imageBuffer appendData:[palette objectAtIndex:214]]; break;
			case 214: [imageBuffer appendData:[palette objectAtIndex:215]]; break;
			case 215: [imageBuffer appendData:[palette objectAtIndex:216]]; break;
			case 216: [imageBuffer appendData:[palette objectAtIndex:217]]; break;
			case 217: [imageBuffer appendData:[palette objectAtIndex:218]]; break;
			case 218: [imageBuffer appendData:[palette objectAtIndex:219]]; break;
			case 219: [imageBuffer appendData:[palette objectAtIndex:220]]; break;
			case 220: [imageBuffer appendData:[palette objectAtIndex:221]]; break;
			case 221: [imageBuffer appendData:[palette objectAtIndex:222]]; break;
			case 222: [imageBuffer appendData:[palette objectAtIndex:223]]; break;
			case 223: [imageBuffer appendData:[palette objectAtIndex:224]]; break;
			case 224: [imageBuffer appendData:[palette objectAtIndex:225]]; break;
			case 225: [imageBuffer appendData:[palette objectAtIndex:226]]; break;
			case 226: [imageBuffer appendData:[palette objectAtIndex:227]]; break;
			case 227: [imageBuffer appendData:[palette objectAtIndex:228]]; break;
			case 228: [imageBuffer appendData:[palette objectAtIndex:229]]; break;
			case 229: [imageBuffer appendData:[palette objectAtIndex:230]]; break;
			case 230: [imageBuffer appendData:[palette objectAtIndex:231]]; break;
			case 231: [imageBuffer appendData:[palette objectAtIndex:232]]; break;
			case 232: [imageBuffer appendData:[palette objectAtIndex:233]]; break;
			case 233: [imageBuffer appendData:[palette objectAtIndex:234]]; break;
			case 234: [imageBuffer appendData:[palette objectAtIndex:235]]; break;
			case 235: [imageBuffer appendData:[palette objectAtIndex:236]]; break;
			case 236: [imageBuffer appendData:[palette objectAtIndex:237]]; break;
			case 237: [imageBuffer appendData:[palette objectAtIndex:238]]; break;
			case 238: [imageBuffer appendData:[palette objectAtIndex:239]]; break;
			case 239: [imageBuffer appendData:[palette objectAtIndex:240]]; break;
			case 240: [imageBuffer appendData:[palette objectAtIndex:241]]; break;
			case 241: [imageBuffer appendData:[palette objectAtIndex:242]]; break;
			case 242: [imageBuffer appendData:[palette objectAtIndex:243]]; break;
			case 243: [imageBuffer appendData:[palette objectAtIndex:244]]; break;
			case 244: [imageBuffer appendData:[palette objectAtIndex:245]]; break;
			case 245: [imageBuffer appendData:[palette objectAtIndex:246]]; break;
			case 246: [imageBuffer appendData:[palette objectAtIndex:247]]; break;
			case 247: [imageBuffer appendData:[palette objectAtIndex:248]]; break;
			case 248: [imageBuffer appendData:[palette objectAtIndex:249]]; break;
			case 249: [imageBuffer appendData:[palette objectAtIndex:250]]; break;
			case 250: [imageBuffer appendData:[palette objectAtIndex:251]]; break;
			case 251: [imageBuffer appendData:[palette objectAtIndex:252]]; break;
			case 252: [imageBuffer appendData:[palette objectAtIndex:253]]; break;
			case 253: [imageBuffer appendData:[palette objectAtIndex:254]]; break;
			case 254: [imageBuffer appendData:[palette objectAtIndex:255]]; break;
			case 255: [imageBuffer appendData:[palette objectAtIndex:256]]; break;
				
			default: [imageBuffer appendBytes:magicLGray length:3];
		}
	}
	
	//	NSLog(@"%@", [imageBuffer description]);
	//	unsigned char lsbCharA = (((rawDataLength * 3) + 40) & 0x000000FF);
	//	unsigned char lsbCharB = ((((rawDataLength * 3) + 40) & 0x0000FF00) >> 8);
	//	unsigned char lsbCharC = ((((rawDataLength * 3) + 40) & 0x00FF0000) >> 16);
	//	unsigned char lsbCharD = ((((rawDataLength * 3) + 40) & 0xFF000000) >> 24);
	
	NSLog(@"[*] BMP Data Length: %d", (rawDataLength * 3));
	
	NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
								initWithBitmapDataPlanes:NULL	// Means it should allocate the data
								pixelsWide: 128
								pixelsHigh: 128
								bitsPerSample:8
								samplesPerPixel:3
								hasAlpha:NO
								isPlanar:NO
								colorSpaceName: NSCalibratedRGBColorSpace// NSDeviceRGBColorSpace
								bytesPerRow: 384	//0 "Don't care"
								bitsPerPixel: 0];
	
	// This tells NSBitmapImageRep the properties of the bitmap you want.
	// You don't supply the actual bitmap memory, so it should allocate this for you
	// You can then fill this by getting the bitmap data:
	
	NSUInteger width = 128;
	NSUInteger height = 384;
	
	unsigned char *destData = [bitmap bitmapData]; // For "planar" data you would use getBitmapDataPlanes: and filling it in, one byte at a time, something like:
	const unsigned char *srcData = [imageBuffer bytes];
    NSUInteger n = 1;
	NSUInteger x, y;
	
	for(y = 0; y < height; y++){
		for(x = 0; x < width; x++){
			destData[y * width + x] = srcData[y * width + x];
		}
	}

//	NSData *data = [bitmap representationUsingType:NSBMPFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat: 2.0 ], NSImageCompressionFactor, nil]];
//	[data writeToFile:@"testsnes.bmp" atomically:YES];

	NSLog(@"[*] Made Bitmap!");
	return bitmap;
}

- (void) encodeImage:(NSImage *)imageObject thingsNeeded:(NSDictionary *)thingsNeeded{
	NSLog(@"[*] Encoding Image");
	NSMutableData *bitmapData = [NSMutableData dataWithData:[imageObject BMPData]];
	NSUInteger colorCount = [bitmapData colorCount];
	NSArray *colorCounter = [bitmapData colors];

	NSLog(@"Width:  %f x %f", [imageObject size].width, [imageObject size].height);
	NSLog(@"Colors: %i : %@", colorCount, [colorCounter description]);

	NSUInteger x = 0;
	NSUInteger y = 0;
	NSUInteger offset = 54;
	unsigned char imagemap[16384];	// 128 x 128 Pixels

	offset = 54;
	for(y = 0; y < 128; y++){
		for(x = 0; x < 128; x++){
			NSUInteger colorCode;
			NSData *subData = [bitmapData subdataWithRange:NSMakeRange(offset, 4)];
			if([subData isEqualToData: [colorCounter objectAtIndex:0]]){		colorCode = 0;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:1]]){	colorCode = 1;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:2]]){	colorCode = 2;	}
			else if([subData isEqualToData: [colorCounter objectAtIndex:3]]){	colorCode = 3;	}
			else{
				NSLog(@"Too Many Colors!");
//				NSLog(@"SubData:\t\t%@", [subData description]);
//				NSLog(@"Current Pixel: %d", offset);
				colorCode = 3;
			}
			imagemap[y * 128 + x] = colorCode;
			offset += 4;
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

@synthesize fullPath;

@end

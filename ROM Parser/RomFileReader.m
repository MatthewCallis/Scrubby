#import "RomFileReader.h"

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
	// gets the nth sprite from the CHR data and returns the composite data
	// first sprite = 0
	NSMutableArray *compositeArray = [NSMutableArray array];
	const unsigned char *chrBuffer = [chrData bytes];

	if(number < 0 || (number > 255 && mode != 1) || number > 512 || [chrData length] <= 0){
		return NULL;
	}

	NSUInteger i = 0;
	NSUInteger j = 0;
	NSUInteger k = 0;
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
		for(j = 0; j < 8; j++){
			mask = 0x80;
			tile_a = chrBuffer[number * 16 + j * 2];
			for(i = 0; i < 8; i++){
				colorBit =  ((tile_a & mask) ? 1 : 0);
				[compositeArray addObject: [NSNumber numberWithUnsignedChar:colorBit]];
				mask >>= 1;
			}
		}
	}
	else if(mode == 1){
		// NES 2BPP
		unsigned char channel_a[NESromSpriteChannelSize], channel_b[NESromSpriteChannelSize];

		for(i = 0; i < NESromSpriteChannelSize; i++){
			channel_a[i] = chrBuffer[NESromSpriteSize * number + i];
			channel_b[i] = chrBuffer[NESromSpriteSize * number + i + NESromSpriteChannelSize];
		}

		for(i = 0; i < NESromSpriteChannelSize; i++){
			for(j = 7; j >= 0; j--){
				NSNumber *combinedBits = [NSNumber numberWithInt:(((channel_a[i] >> j) & 1) | (((channel_b[i] >> j) & 1) << 1)) + 1];
				[compositeArray addObject: combinedBits];
				k++;
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
				colorBit =  ((tile_e & mask) ? 16 : 0);
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
//	if(!chrData || startIndex < 0 || endIndex > NESspritesPerChr) return NULL;
	if(!chrData || startIndex < 0 || endIndex > 255) return NULL;

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
			case 0:
				[imageBuffer appendData:[palette objectAtIndex:1]];
				break;
			case 1:
				[imageBuffer appendData:[palette objectAtIndex:2]];
				break;
			case 2:
				[imageBuffer appendData:[palette objectAtIndex:3]];
				break;
			case 3:
				[imageBuffer appendData:[palette objectAtIndex:4]];
				break;
			case 4:
				[imageBuffer appendBytes:magicA length:3];
				break;
			case 5:
				[imageBuffer appendBytes:magicB length:3];
				break;
			case 6:
				[imageBuffer appendBytes:magicC length:3];
				break;
			case 7:
				[imageBuffer appendBytes:magicD length:3];
				break;
			case 8:
				[imageBuffer appendBytes:magicE length:3];
				break;
			case 9:
				[imageBuffer appendBytes:magicF length:3];
				break;
			case 10:
				[imageBuffer appendBytes:magicG length:3];
				break;
			case 11:
				[imageBuffer appendBytes:magicH length:3];
				break;
			case 12:
				[imageBuffer appendBytes:magicI length:3];
				break;
			case 13:
				[imageBuffer appendBytes:magicJ length:3];
				break;
			case 14:
				[imageBuffer appendBytes:magicK length:3];
				break;
			case 15:
				[imageBuffer appendBytes:magicL length:3];
				break;
			default:
				[imageBuffer appendBytes:magicLGray length:3];
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
    unsigned char *p1, *p2;
    NSUInteger n = 1;
	NSUInteger x, y;
	
	for(y = 0; y < height; y++){
		for(x = 0; x < width; x++){
			p1 = (unsigned char *)srcData + n * (y * width + x);
			p2 = destData + y * width + x;
			
			destData[y * width + x] = srcData[y * width + x];
		}
	}
	
//	NSData *data = [bitmap representationUsingType:NSBMPFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat: 2.0 ], NSImageCompressionFactor, nil]];
//	[data writeToFile:@"testsnes.bmp" atomically:YES];
	
	NSLog(@"[*] Made Bitmap!");
	return bitmap;
}

@synthesize fullPath;

@end

//  NSImage_BMPData.h
//  Florent Pillet, Code Segment 
//
//  Created by Florent Pillet, Code Segment on Wed Oct 08 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>

@interface NSImage(BMPData)

Handle myCreateHandleDataRef(Handle dataHandle, Str255 fileName, OSType fileType, StringPtr mimeTypeString, Ptr initDataPtr, Size initDataByteCount);
- (NSData *)BMPData;

@end

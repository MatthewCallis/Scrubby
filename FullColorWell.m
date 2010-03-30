#import "FullColorWell.h"

@implementation FullColorWell

- (IBAction)chooseColor:(id)sender{
	[self activate:YES];
	[[NSColorPanel sharedColorPanel] makeKeyAndOrderFront:self];
}

- (void)drawWellInside:(NSRect)insideRect{
	[[self color] set];
	insideRect = NSMakeRect(1,1,14,14);
	NSRectFill(insideRect);
	[myOverlayView displayRectIgnoringOpacity:[self convertRect:insideRect toView:myOverlayView]];
}

@synthesize myOverlayView;

@end

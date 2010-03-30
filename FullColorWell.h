#import <Cocoa/Cocoa.h>

@interface FullColorWell : NSColorWell {
    IBOutlet NSView* myOverlayView;
}

- (IBAction)chooseColor:(id)sender;

@property (retain) NSView* myOverlayView;

@end

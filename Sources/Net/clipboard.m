#import "clipboard.h"
#import <AppKit/AppKit.h>

NSString *blm_clipboard_string(void) {
    @try {
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        if (pb == nil) return nil;
        NSArray<NSPasteboardType> *types = [pb types];
        if (types == nil || types.count == 0) return nil;
        NSString *s = nil;
        if ([types containsObject:NSPasteboardTypeString]) {
            id obj = [pb stringForType:NSPasteboardTypeString];
            if ([obj isKindOfClass:[NSString class]]) s = obj;
        }
        if (s == nil || s.length == 0) {
            NSData *d = [pb dataForType:NSPasteboardTypeString];
            if (d != nil && d.length > 0) {
                s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            }
        }
        if (s == nil || s.length == 0) return nil;
        return s;
    } @catch (NSException *ex) {
        return nil;
    }
}

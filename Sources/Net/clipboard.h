#ifndef BLM_CLIPBOARD_H
#define BLM_CLIPBOARD_H

#ifdef __OBJC__
@class NSString;
NSString *blm_clipboard_string(void);
#else
typedef struct objc_object NSString;
NSString *blm_clipboard_string(void);
#endif

#endif

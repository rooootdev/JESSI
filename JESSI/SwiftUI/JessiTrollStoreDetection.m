#import "JessiTrollStoreDetection.h"
#import <Foundation/Foundation.h>
#import <unistd.h>

bool jessi_trollstore_marker_exists(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    if (bundlePath.length == 0) return false;

    NSString *tsPath = [bundlePath stringByAppendingPathComponent:@"../_TrollStore"];
    return access(tsPath.UTF8String, F_OK) == 0;
}

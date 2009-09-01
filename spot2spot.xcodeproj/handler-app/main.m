#import <Cocoa/Cocoa.h>

@interface NTHandlerAppDelegate : NSObject {
  BOOL processInitiatedByOpenFiles;
}
- (void) cancelOpenedDirectlyTimer;
- (void) applicationWasOpenedDirectly;
@end


@implementation NTHandlerAppDelegate

- (id) init {
  self = [super init];
  if (self != nil) {
    processInitiatedByOpenFiles = NO;
  }
  return self;
}

- (void) cancelOpenedDirectlyTimer {
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:@selector(applicationWasOpenedDirectly)
                                             object:nil];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)path {
  if (!processInitiatedByOpenFiles)
    [self cancelOpenedDirectlyTimer];
  NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:path];
  if (!d)
    return NO;
  NSURL *url = [NSURL URLWithString:[d objectForKey:(NSString *)kMDItemURL]];
  return [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)paths {
  processInitiatedByOpenFiles = YES;
  [self cancelOpenedDirectlyTimer];
  for (NSString *path in paths) {
    if (![self application:sender openFile:path])
      break;
  }
  [NSApp terminate:self];
}

- (void) applicationWasOpenedDirectly {
  // todo: check if mdimporter and SIMBL + plugin is installed, if not; 
  // prompt the user for confirmation and perform installation.
  [NSApp terminate:self];
}

@end


int main(int argc, char *argv[]) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [NSApplication sharedApplication];
  NTHandlerAppDelegate *appDelegate = [[NTHandlerAppDelegate alloc] init];
  [NSApp setDelegate:appDelegate];
  
  [appDelegate performSelector:@selector(applicationWasOpenedDirectly)
                    withObject:nil
                    afterDelay:0.4];
  [NSApp run];
  [pool drain];
  return 0;
}

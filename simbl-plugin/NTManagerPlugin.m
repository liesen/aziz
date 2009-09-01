#import "NTManagerPlugin.h"
#import "NTSpotifyListener.h"
#import "logging.h"

#undef SRC_MODULE
#define SRC_MODULE "plugin"

@implementation NTManagerPlugin


+ (NTManagerPlugin*)sharedInstance {
  static NTManagerPlugin* plugin = nil;
  if (plugin != nil)
    return plugin;
  plugin = [[NTManagerPlugin alloc] init];
  return plugin;
}


// The object received is a NSTextStorage which contains the query
- (void) addObserver:(id)observer selector:(SEL)sel {
  id editor = [[NSApp mainWindow] fieldEditor:YES forObject:nil];
  [[NSNotificationCenter defaultCenter] addObserver:observer
                                           selector:sel
                                               name:NSTextStorageDidProcessEditingNotification
                                             object:editor];
  Log_debug(@"added observer %@", observer);
}


+ (void)load {
  // Initialize logging
  log_asl_client = asl_open(NULL, "se.notion.spot2spot.mdplugin", 0);
  #if DEBUG
    log_set_send_filter(ASL_LEVEL_DEBUG);
  #else
    log_set_send_filter(ASL_LEVEL_NOTICE);
  #endif
  // todo: should call asl_close(log_asl_client); atexit
  
  NTManagerPlugin *manager;
  // Make sure that we instansiate the plugin
  manager = [NTManagerPlugin sharedInstance];
  
  // Register listeners
  NTSpotifyListener *spotifyListener = [[NTSpotifyListener alloc] init];
  if (spotifyListener) {
    [manager addObserver:spotifyListener
                selector:@selector(spotlightQueryDidChange:)];
  }
  
  log_notice("NTManagerPlugin installed");
}

@end

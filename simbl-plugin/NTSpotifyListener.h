#import "NTSpotifyRemoteSearch.h"

extern NSString *kNTSpotifyTypeTrack;
extern NSString *kNTSpotifyTypeArtist;
extern NSString *kNTSpotifyTypeAlbum;

@interface NTSpotifyListener : NSObject {
  NSArray *runloopModes;
  NTSpotifyRemoteSearch *remoteSearch;
  NSThread *parserThread;
  NSString *metadataDir;    // ~/Library/Caches/Metadata/se.notion.spot2spot
  NSString *cacheDir;       // ~/Library/Caches/se.notion.spot2spot
  NSString *queryCacheDir;  // <cacheDir>/queries
  NSFileManager *fileManager;
  NSTimeInterval fileCacheTTL;
  NSTimeInterval queryCacheTTL;
}

#pragma mark -
#pragma mark Utility functions
- (BOOL) createDirectoriesAtPath:(NSString *)path;
- (BOOL) cachedFileIsExpired:(NSString *)path ttl:(NSTimeInterval)ttl;
- (NSString *) pathForMetadataWithIdentifier:(NSString *)identifier type:(NSString *)type mkdirs:(BOOL)mkdirs;
- (BOOL) writeMetadata:(NSDictionary *)metadata toPath:(NSString *)path;
- (NSString *) queryCachePathForQuery:(NSString *)query;

#pragma mark -
#pragma mark Dispatching and receiving remote queries
- (void) dispatchQueryUpdate:(NSString *)query;
- (void) cancel;
- (void) cancelRemoteSearch;
- (void) cancelParserThread;

#pragma mark -
#pragma mark Parsing queries
- (void) parseResponseThread:(NTSpotifyRemoteSearch *)remoteSearch;
- (void) parseResponse:(NSData *)data query:(NSString *)query;
- (void) parseArtists:(NSXMLElement *)artists;
- (void) parseAlbums:(NSXMLElement *)albums;
- (void) parseTracks:(NSXMLElement *)tracks;

#pragma mark -
#pragma mark Delegate implementation
- (void) spotlightQueryDidChange:(NSNotification *)notification;

@end

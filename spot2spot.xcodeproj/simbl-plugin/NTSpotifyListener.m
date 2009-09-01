#import "NTSpotifyListener.h"
#import "logging.h"

#undef SRC_MODULE
#define SRC_MODULE "spotify"

NSString *kNTSpotifyTypeTrack = @"track";
NSString *kNTSpotifyTypeArtist = @"artist";
NSString *kNTSpotifyTypeAlbum = @"album";

@interface NTSpotifyListener (Private)
- (NSString *) _parseAuthors:(NSXMLElement *)node authors:(NSMutableArray **)authors;
@end

@implementation NTSpotifyListener


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init {
  self = [super init];
  if (self != nil) {
    runloopModes = [[NSArray arrayWithObject:NSRunLoopCommonModes] retain];
    remoteSearch = nil;
    parserThread = nil;
    metadataDir = [[@"~/Library/Caches/Metadata/se.notion.spot2spot" stringByExpandingTildeInPath] retain];
    cacheDir = [[@"~/Library/Caches/se.notion.spot2spot" stringByExpandingTildeInPath] retain];
    queryCacheDir = [[cacheDir stringByAppendingPathComponent:@"queries"] retain];
    fileCacheTTL = 60.0*60.0*24.0*7.0; // 1 week
    queryCacheTTL = 60.0*60.0*24.0;    // 1 day
    fileManager = [[NSFileManager defaultManager] retain];
    
    if (![self createDirectoriesAtPath:cacheDir]) {
      [self release];
      return nil;
    }
  }
  return self;
}


- (void) dealloc {
  [metadataDir release];
  [cacheDir release];
  [queryCacheDir release];
  [fileManager release];
  [runloopModes release];
  if (remoteSearch)
    [remoteSearch release];
  if (parserThread)
    [parserThread release];
  [super dealloc];
}


#pragma mark -
#pragma mark Utility functions


- (BOOL) createDirectoriesAtPath:(NSString *)path {
  NSError *error = nil;
  [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
  if (error) {
    Log_crit(@"failed to create directory/directories \"%@\" -- %@", path, error);
    return NO;
  }
  return YES;
}


- (BOOL) cachedFileIsExpired:(NSString *)path ttl:(NSTimeInterval)ttl {
  NSDictionary *fileAttributes;
  NSDate *referenceDate, *fileModificationDate;
  
  if ((fileAttributes = [fileManager fileAttributesAtPath:path traverseLink:NO])) {
    referenceDate = [NSDate date];
    fileModificationDate = [fileAttributes objectForKey:NSFileModificationDate];
    fileModificationDate = [fileModificationDate addTimeInterval:ttl];
    if ([referenceDate earlierDate:fileModificationDate] == referenceDate) {
      return YES;
    }
  }
  return NO;
}


- (NSString *)urlEncode:(NSString *)raw {
  return (NSString*)[(NSString*)CFURLCreateStringByAddingPercentEscapes(
    NULL, (CFStringRef)raw, NULL, NULL, kCFStringEncodingUTF8) autorelease];
}


- (NSString *)pathForMetadataWithIdentifier:(NSString *)identifier type:(NSString *)type mkdirs:(BOOL)mkdirs {
  NSString *filename, *ch01, *ch23;
  NSError *error;
  
  ch01 = [identifier substringWithRange:NSMakeRange(0, 2)];
  ch23 = [identifier substringWithRange:NSMakeRange(2, 2)];
  filename = [NSString stringWithFormat:@"%@/%@", ch01, ch23];
  filename = [metadataDir stringByAppendingPathComponent:filename];
  if (mkdirs) {
    error = nil;
    [fileManager createDirectoryAtPath:filename
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error];
    if (error)
      Log_err(@"failed to create directory '%@'", filename);
  }
  filename = [filename stringByAppendingPathComponent:identifier];
  filename = [filename stringByAppendingPathExtension:[@"s2s" stringByAppendingString:type]];
  return filename;
}


- (BOOL) writeMetadata:(NSDictionary *)metadata toPath:(NSString *)path {
  NSData *data;
  NSString *errorDescription;
  
  data = [NSPropertyListSerialization dataFromPropertyList:metadata 
                                                    format:NSPropertyListBinaryFormat_v1_0
                                          errorDescription:&errorDescription];
  if (data == nil) {
    Log_warn(@"failed to serialize dictionary using NSPropertyListBinaryFormat_v1_0");
    return NO;
  }
  return [data writeToFile:path atomically:YES];
}


- (NSString *)queryCachePathForQuery:(NSString *)q {
  return [queryCacheDir stringByAppendingPathComponent:[self urlEncode:q]];
}


#pragma mark -
#pragma mark Dispatching and receiving remote queries


- (void) dispatchQueryUpdate:(NSString *)query {
  // Cancel any previous query, which is still being processed
  [self cancel];
  
  // Cached?
  if ([self cachedFileIsExpired:[self queryCachePathForQuery:query] ttl:queryCacheTTL]) {
    Log_notice(@"query %@ is fully cached", query);
    return;
  }
  
  // Dispatch new request
  remoteSearch = [[NTSpotifyRemoteSearch alloc] initWithQuery:query
                                                     delegate:self
                                             startImmediately:YES];
}


- (void) cancelRemoteSearch {
  if (remoteSearch) {
    [remoteSearch cancel];
    [remoteSearch autorelease];
    remoteSearch = nil;
    log_info("cancelled previous connection");
  }
}


- (void) cancelParserThread {
  if (parserThread) {
    if (![parserThread isCancelled] && [parserThread isExecuting]) {
      [parserThread cancel];
      log_info("cancelled parser thread");
    }
    [parserThread autorelease];
    parserThread = nil;
  }
}


- (void) cancel {
  [self cancelRemoteSearch];
  [self cancelParserThread];
}


- (void) spotifyRemoteSearch:(NTSpotifyRemoteSearch *)_remoteSearch didFailWithError:(NSError *)error {
  Log_warn(@"remote search failed %@", error);
  [_remoteSearch release];
  if (_remoteSearch == remoteSearch)
    remoteSearch = nil;
}


- (void) spotifyRemoteSearchCompleted:(NTSpotifyRemoteSearch *)_remoteSearch {
  assert(_remoteSearch == remoteSearch);
  [self cancelParserThread];
  parserThread = [[NSThread alloc] initWithTarget:self
                                         selector:@selector(parseResponseThread:)
                                           object:_remoteSearch];
  [parserThread start];
  // We do not release _remoteSearch here because the thread main handles 
  // that. We surrender our reference.
  if (_remoteSearch == remoteSearch)
    remoteSearch = nil;
}


#pragma mark -
#pragma mark Parsing queries


- (void) parseResponseThread:(NTSpotifyRemoteSearch *)_remoteSearch {
  NSAutoreleasePool *ap = [[NSAutoreleasePool alloc] init];
  // We do not retain, but only release, _remoteSearch since we where given 
  // a reference by the caller (spotifyRemoteSearchCompleted:)
  [self parseResponse:_remoteSearch.responsePayload query:_remoteSearch.query];
  [_remoteSearch release];
  [ap drain];
}


- (void) parseResponse:(NSData *)data query:(NSString *)query {
  NSXMLDocument *doc;
  NSXMLElement *root, *n;
  NSError *error;
  NSUInteger i, count;
  NSString *queryCachePath;
  
  log_info("parsing response (%ld bytes)", (long)[data length]);
  
  error = nil;
  doc = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
  
  if (error || !doc) {
    Log_error(@"failed to parse response %@", error);
    if (doc)
      [doc release];
    return;
  }
  
  if (![self createDirectoriesAtPath:metadataDir]) {
    [doc release];
    return;
  }
  
  root = [doc rootElement];
  count = [root childCount];
  
  for (i = 0; i < count; i++) {
    if ([[NSThread currentThread] isCancelled]) {
      log_info("parser thread is cancelled -- bailing out from parseResponse");
      break;
    }
    
    n = (NSXMLElement *)[root childAtIndex:i];
    
    if ([[n name] compare:@"artists"] == 0)
      [self parseArtists:n];
    else if ([[n name] compare:@"albums"] == 0)
      [self parseAlbums:n];
    else if ([[n name] compare:@"tracks"] == 0)
      [self parseTracks:n];
  }
  
  // Write query cache unless cancelled
  if ( (![[NSThread currentThread] isCancelled]) && query ) {
    if ([self createDirectoriesAtPath:queryCacheDir]) {
      queryCachePath = [self queryCachePathForQuery:query];
      [@"\n" writeToFile:queryCachePath
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:&error];
      if (error)
        Log_err(@"failed to write query cache to '%@' -- %@", queryCachePath, error);
    }
  }
  
  [doc release];
}


- (void) parse:(NSString *)type root:(NSXMLElement *)root {
  NSXMLElement *node;
  NSThread *currentThread;
  NSString *uri, *identifier, *filename, *displayName, *itemTitle;
  NSMutableDictionary *metadata;
  NSUInteger i, childCount, hrefPrefixLength;
  NSArray *mediaTypes;
  NSMutableArray *authors;
  
  hrefPrefixLength = [[NSString stringWithFormat:@"spotify:%@:", type] length];
  childCount = [root childCount];
  currentThread = [NSThread currentThread];
  mediaTypes = [NSArray arrayWithObject:@"Sound"];
  
  for (i = 0;
       ![currentThread isCancelled] && i < childCount;
       i++)
  {
    node = (NSXMLElement *)[root childAtIndex:i];
    
    // Extract URI and Spotify ID
    if (!(uri = [[node attributeForName:@"href"] stringValue]))
      Log_warn(@"uri is nil");
    if (!(identifier = [uri substringFromIndex:hrefPrefixLength]))
      Log_warn(@"identifier is nil");
    
    // Build filename
    filename = [self pathForMetadataWithIdentifier:identifier type:type mkdirs:YES];
    
    // Check if cache is valid
    if ([self cachedFileIsExpired:filename ttl:fileCacheTTL])
      continue;
    
    // Compile metadata
    displayName = nil;
    itemTitle = [[[node elementsForName:@"name"] objectAtIndex:0] stringValue];
    if (!itemTitle)
      continue;
    metadata = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                uri, (NSString *)kMDItemURL,
                mediaTypes, (NSString *)kMDItemMediaTypes,
                itemTitle, (NSString *)kMDItemTitle,
                nil];
    
    // Type specific metadata
    if (type == kNTSpotifyTypeTrack || type == kNTSpotifyTypeAlbum) {
      NSString *artistNames;
      artistNames = [self _parseAuthors:node authors:&authors];
      displayName = [NSString stringWithFormat:@"%@ by %@", itemTitle, artistNames];
      [metadata setObject:authors forKey:(NSString *)kMDItemAuthors];
    }
    if (type == kNTSpotifyTypeTrack) {
      int duration;
      NSArray *yearNodes;
      
      duration = atoi([[[[node elementsForName:@"track-number"] objectAtIndex:0] stringValue] UTF8String]);
      [metadata setObject:[[[node elementsForName:@"track-number"] objectAtIndex:0] stringValue]
                   forKey:(NSString *)kMDItemAudioTrackNumber];
      [metadata setObject:[NSNumber numberWithInt:(duration/1000)]
                   forKey:(NSString *)kMDItemDurationSeconds];
      yearNodes = [node elementsForName:@"year"];
      if (yearNodes && [yearNodes count]) {
        [metadata setObject:[[yearNodes objectAtIndex:0] stringValue]
                     forKey:(NSString *)kMDItemRecordingYear];
      }
      else {
        [metadata setObject:@"" forKey:(NSString *)kMDItemRecordingYear];
      }
    }
    
    if (!displayName)
      displayName = itemTitle;
    
    // Common keys with type-specific values
    [metadata setObject:displayName forKey:(NSString *)kMDItemDisplayName];
    
#if DEBUG
    if ([self writeMetadata:metadata toPath:filename])
      Log_notice(@"wrote %@ (%@)", filename, displayName);
#else
    [self writeMetadata:metadata toPath:filename];
#endif
  }
}


- (NSString *) _parseAuthors:(NSXMLElement *)node authors:(NSMutableArray **)authors {
  NSUInteger x, artistCount;
  NSString *artistNames, *artistName;
  NSXMLElement *artist;
  NSArray *childNodes;
  
  childNodes = [node elementsForName:@"artist"];
  artistCount = [childNodes count];
  *authors = [NSMutableArray arrayWithCapacity:artistCount];
  artistNames = @"";
  for (x = 0; x < artistCount; x++) {
    artist = (NSXMLElement *)[childNodes objectAtIndex:x];
    artistName = [[[artist elementsForName:@"name"] objectAtIndex:0] stringValue];
    [*authors addObject:artistName];
    if (x == artistCount-1)
      artistNames = [artistNames stringByAppendingString:artistName];
    else
      artistNames = [artistNames stringByAppendingFormat:@"%@, ", artistName];
  }
  return artistNames;
}


- (void) parseArtists:(NSXMLElement *)artists {
  [self parse:kNTSpotifyTypeArtist root:artists];
}


- (void) parseAlbums:(NSXMLElement *)albums {
  [self parse:kNTSpotifyTypeAlbum root:albums];
}


- (void) parseTracks:(NSXMLElement *)tracks {
  [self parse:kNTSpotifyTypeTrack root:tracks];
}


#pragma mark -
#pragma mark Delegate implementation


- (void) spotlightQueryDidChange:(NSNotification *)notification {
  NSString *query;
  SEL dispatchSelector;
  
  dispatchSelector = @selector(dispatchQueryUpdate:);
  [NSObject cancelPreviousPerformRequestsWithTarget:self
                                           selector:dispatchSelector
                                             object:nil];
  
  // save query
  query = [[notification object] string];
  query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([query length] < 3)
    return;
  
  [self performSelector:dispatchSelector
             withObject:query
             afterDelay:0.2f
                inModes:runloopModes];
}

@end

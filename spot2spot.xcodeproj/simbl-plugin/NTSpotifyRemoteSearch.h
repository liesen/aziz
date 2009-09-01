@interface NTSpotifyRemoteSearch : NSURLConnection {
  NSString *query;
  NSURLRequest *request;
  NSURLResponse *response;
  NSMutableData *responsePayload;
  id delegate;
}

@property(readonly) NSString *query;
@property(readonly) NSURLRequest *request;
@property(readonly) NSURLResponse *response;
@property(readonly) NSMutableData *responsePayload;

- (id) initWithQuery:(NSString *)query delegate:(id)delegate startImmediately:(BOOL)startImmediately;

@end


@protocol NTSpotifyRemoteSearchDelegate
- (void) spotifyRemoteSearch:(NTSpotifyRemoteSearch *)remoteSearch didFailWithError:(NSError *)error;
- (void) spotifyRemoteSearchCompleted:(NTSpotifyRemoteSearch *)remoteSearch;
@end

#import "NTSpotifyRemoteSearch.h"

@implementation NTSpotifyRemoteSearch

@synthesize query, request, response, responsePayload;


- (id) initWithQuery:(NSString *)_query delegate:(id)_delegate startImmediately:(BOOL)startImmediately {
  NSString *urlEncodedQuery;
  NSURL *url;
  
  query = [_query retain];
  
  urlEncodedQuery = (NSString*)CFURLCreateStringByAddingPercentEscapes(
    NULL, (CFStringRef)query, NULL, NULL, kCFStringEncodingUTF8);
  url = [NSURL URLWithString:[@"http://ws.spotify.com/search?q=" stringByAppendingString:urlEncodedQuery]];
  [urlEncodedQuery release];
  
  delegate = _delegate ? [_delegate retain] : nil;
  request = [[NSURLRequest alloc] initWithURL:url];
  responsePayload = nil;
  response = nil;
  
  if (!(self = [super initWithRequest:request delegate:self startImmediately:startImmediately])) {
    [query release];
    [request release];
    if (delegate)
      [delegate release];
    return nil;
  }
  
  return self;
}

- (void) dealloc {
  [query release];
  [request release];
  if (delegate)
    [delegate release];
  if (responsePayload)
    [responsePayload release];
  if (response)
    [response release];
  [super dealloc];
}


#pragma mark -
#pragma mark Processing


- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)rsp {
  NSURLResponse *oldResponse;
  NSMutableData *oldResponsePayload;
  
  oldResponsePayload = responsePayload;
  oldResponse = response;
  response = [rsp retain];
  
  long long len = [response expectedContentLength];
  if (len == NSURLResponseUnknownLength)
    responsePayload = [[NSMutableData alloc] init];
  else
    responsePayload = [[NSMutableData alloc] initWithCapacity:(NSUInteger)len];
  
  if (oldResponsePayload)
    [oldResponsePayload release];
  if (oldResponse)
    [oldResponse release];
}


- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [responsePayload appendData:data];
}


- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  [delegate spotifyRemoteSearch:self didFailWithError:error];
}


- (void) connectionDidFinishLoading:(NSURLConnection *)conn {
  [delegate spotifyRemoteSearchCompleted:self];
}


@end

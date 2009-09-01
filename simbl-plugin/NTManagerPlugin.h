
@interface NTManagerPlugin : NSObject {
  NSMutableArray *listeners;
}

+ (NTManagerPlugin*)sharedInstance;

@end

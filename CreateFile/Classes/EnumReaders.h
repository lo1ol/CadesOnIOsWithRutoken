#import <CPROCSP/CPROCSP.h>

@interface CProReader : NSObject
@property (strong, readwrite) NSString* nickname;
@property (strong, readwrite) NSString* name;
@property (strong, readwrite) NSString* media;
@property (assign, readwrite) uint8_t flags;
-(CProReader*) initWithData:(uint8_t*)dataPtr;
+(NSArray*) getReaderList;
@end

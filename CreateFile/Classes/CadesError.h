#import <Foundation/Foundation.h>

@interface CadesError : NSError

+ (CadesError*)errorWithCode:(NSUInteger)code;

@end

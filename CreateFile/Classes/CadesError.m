#import "CadesError.h"

static NSString* const gCadesErrorDomain = @"ru.cryptopro.cades";

@implementation CadesError

- (NSString*)localizedDescription {
	switch ([self code]) {
		default:
			return @"Unknown error";
	}
}

+ (CadesError*)errorWithCode:(NSUInteger)code {
	return [[CadesError alloc] initWithDomain:gCadesErrorDomain code:code userInfo:nil];
}

@end

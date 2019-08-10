//
//  LastFm.m
//  lastfmlocalplayback
//
//  Created by Kevin Renskers on 17-08-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import "LastFm.h"
#import "DDXML.h"
#include <CommonCrypto/CommonDigest.h>
#import <AFNetworking/AFNetworking.h>



#define API_URL @"http://ws.audioscrobbler.com/2.0/"


@interface DDXMLParserResponseSerializer : AFHTTPResponseSerializer

@end





@interface DDXMLNode (objectAtXPath)

- (id)objectAtXPath:(NSString *)XPath;

@end

@implementation DDXMLNode (objectAtXPath)

- (id)objectAtXPath:(NSString *)XPath {
    NSError *err;
    NSArray *nodes = [self nodesForXPath:XPath error:&err];

    if ([nodes count]) {
        NSMutableArray *strings = [[NSMutableArray alloc] init];
        for (DDXMLNode *node in nodes) {
            if ([node stringValue]) {
                [strings addObject:[[node stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            }
        }
        if ([strings count] == 1) {
            NSString *output = [NSString stringWithString:[strings objectAtIndex:0]];
            return output;
        } else if ([strings count] > 1) {
            return strings;
        } else {
            return @"";
        }
    } else {
        return @"";
    }
}

@end


@interface LastFm ()

@property (nonatomic,strong)AFHTTPSessionManager *sessionManager;

@end


@implementation LastFm

+ (LastFm *)sharedInstance {
    static dispatch_once_t pred;
    static LastFm *sharedInstance = nil;
    dispatch_once(&pred, ^{
        sharedInstance = [[self alloc] init];
        //http://www.last.fm/api/accounts
        //https://www.last.fm/api/account/create
        sharedInstance.apiKey = APP_LAST_FM_API_KEY;
        sharedInstance.apiSecret = APP_LAST_FM_API_SECRET;
        sharedInstance.timeoutInterval = 30.0;
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.apiKey = @"";
        self.apiSecret = @"";
        self.timeoutInterval = 30.0;
        self.sessionManager = [[self class] sharedSessionManager];
    }
    return self;
}

+ (AFHTTPSessionManager *)sharedSessionManager{
    static dispatch_once_t onceToken;
    static AFHTTPSessionManager *manager;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.allowsCellularAccess = YES;
        configuration.timeoutIntervalForRequest = 30;
        configuration.HTTPMaximumConnectionsPerHost = 1;
        manager = [[AFHTTPSessionManager alloc] initWithSessionConfiguration:configuration];
        dispatch_queue_t callBackQueue = dispatch_queue_create([@"com.lastfm.callback.queue" cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        manager.completionQueue = callBackQueue;
        manager.responseSerializer = [DDXMLParserResponseSerializer serializer];
        manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    });
    return manager;
}

+ (NSDateFormatter *)dateFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
    });
    return formatter;
}

+ (NSDateFormatter *)alternativeDateFormatter1 {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setDateFormat:@"dd MMM yyyy, HH:mm"];
    });
    return formatter;
}

+ (NSDateFormatter *)alternativeDateFormatter2 {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z"];
    });
    return formatter;
}

+ (NSDateFormatter *)alternativeDateFormatter3 {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    });
    return formatter;
}

+ (NSNumberFormatter *)numberFormatter {
    static dispatch_once_t onceToken;
    static NSNumberFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
    });
    return formatter;
}

#pragma mark - Private methods

- (NSString *)md5sumFromString:(NSString *)string {
	unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
	CC_MD5([string UTF8String], (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
	NSMutableString *ms = [NSMutableString string];
	for (i=0;i<CC_MD5_DIGEST_LENGTH;i++) {
		[ms appendFormat: @"%02x", (int)(digest[i])];
	}
	return [ms copy];
}

- (NSString*)urlEscapeString:(id)unencodedString {
    if ([unencodedString isKindOfClass:[NSString class]]) {
        NSString *s = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
            NULL,
            (__bridge CFStringRef)unencodedString,
            NULL,
            (CFStringRef)@"!*'();:@&=+$,/?%#[]", 
            kCFStringEncodingUTF8
        );
        return s;
    }
    return unencodedString;
}

- (id)transformValue:(id)value intoClass:(NSString *)targetClass {
    if ([value isKindOfClass:NSClassFromString(targetClass)]) {
        return value;
    }

    if ([targetClass isEqualToString:@"NSNumber"]) {
        if ([value isKindOfClass:[NSString class]] && [value length]) {
            return [[LastFm numberFormatter] numberFromString:value];
        }
        return @0;
    }

    if ([targetClass isEqualToString:@"NSURL"]) {
        if ([value isKindOfClass:[NSString class]] && [value length]) {
            return [NSURL URLWithString:value];
        }
        return nil;
    }

    if ([targetClass isEqualToString:@"NSDate"]) {
        NSDate *date = [[LastFm dateFormatter] dateFromString:value];
        if (!date) {
            date = [[LastFm alternativeDateFormatter1] dateFromString:value];
        }
        if (!date) {
            date = [[LastFm alternativeDateFormatter2] dateFromString:value];
        }
        if (!date) {
            date = [[LastFm alternativeDateFormatter3] dateFromString:value];
        }
        return date;
    }

    if ([targetClass isEqualToString:@"NSArray"]) {
        if ([value isKindOfClass:[NSString class]] && [value length]) {
            return [NSArray arrayWithObject:value];
        }
        return [NSArray array];
    }

    NSLog(@"Invalid targetClass (%@)", targetClass);
    return value;
}

- (NSString *)forceString:(NSString *)value {
    if (!value) return @"";
    return value;
}

- (NSString *)period:(LastFmPeriod)period {
    switch (period) {
        case kLastFmPeriodOverall:
            return @"overall";
            break;

        case kLastFmPeriodWeek:
            return @"7day";
            break;

        case kLastFmPeriodMonth:
            return @"1month";
            break;

        case kLastFmPeriodQuarter:
            return @"3month";
            break;

        case kLastFmPeriodHalfYear:
            return @"6month";
            break;

        case kLastFmPeriodYear:
            return @"12month";
            break;
    }
}

- (NSURLSessionDataTask *)performApiCallForMethod:(NSString*)method
                              withParams:(NSDictionary *)params
                               rootXpath:(NSString *)rootXpath
                        returnDictionary:(BOOL)returnDictionary
                           mappingObject:(NSDictionary *)mappingObject
                          successHandler:(LastFmReturnBlockWithObject)successHandler
                          failureHandler:(LastFmReturnBlockWithError)failureHandler {

    NSMutableDictionary *newParams = [params mutableCopy];
    [newParams setObject:method forKey:@"method"];
    [newParams setObject:self.apiKey forKey:@"api_key"];

    if (self.session) {
        [newParams setObject:self.session forKey:@"sk"];
    }

    if (self.username && ![params objectForKey:@"username"]) {
        [newParams setObject:self.username forKey:@"username"];
    }

    // Create signature by sorting all the parameters
    NSArray *sortedParamKeys = [[newParams allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *signature = [[NSMutableString alloc] init];
    for (NSString *key in sortedParamKeys) {
        [signature appendString:[NSString stringWithFormat:@"%@%@", key, [newParams objectForKey:key]]];
    }
    [signature appendString:self.apiSecret];

    // Check if we have the object in cache
    NSString *cacheKey = [self md5sumFromString:signature];

    // We need to send all the params in a sorted fashion
    NSMutableArray *sortedParamsArray = [NSMutableArray array];
    for (NSString *key in sortedParamKeys) {
        [sortedParamsArray addObject:[NSString stringWithFormat:@"%@=%@", [self urlEscapeString:key], [self urlEscapeString:[newParams objectForKey:key]]]];
    }

    return [self _performApiCallForMethod:method signature:cacheKey withSortedParamsArray:sortedParamsArray andOriginalParams:newParams rootXpath:rootXpath returnDictionary:returnDictionary mappingObject:mappingObject successHandler:successHandler failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)_performApiCallForMethod:(NSString*)method
                                signature:(NSString *)signature
                    withSortedParamsArray:(NSArray *)sortedParamsArray
                        andOriginalParams:(NSDictionary *)originalParams
                                rootXpath:(NSString *)rootXpath
                         returnDictionary:(BOOL)returnDictionary
                            mappingObject:(NSDictionary *)mappingObject
                           successHandler:(LastFmReturnBlockWithObject)successHandler
                           failureHandler:(LastFmReturnBlockWithError)failureHandler {

    
    // Do we need to POST or GET?
    BOOL doPost = YES;
    NSArray *methodParts = [method componentsSeparatedByString:@"."];
    if ([methodParts count] > 1) {
        NSString *secondPart = [methodParts objectAtIndex:1];
        if ([secondPart hasPrefix:@"get"]) {
            doPost = NO;
        }
    }
    
    NSMutableURLRequest *request;
    if (doPost) {
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:API_URL]];
        request.timeoutInterval = self.timeoutInterval;
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[[NSString stringWithFormat:@"%@&api_sig=%@", [sortedParamsArray componentsJoinedByString:@"&"], signature] dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        NSString *paramsString = [NSString stringWithFormat:@"%@&api_sig=%@", [sortedParamsArray componentsJoinedByString:@"&"], signature];
        NSString *urlString = [NSString stringWithFormat:@"%@?%@", API_URL, paramsString];
        
        request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
        request.timeoutInterval = self.timeoutInterval;
    }
    NSLog(@"LastFM request: %@",request.URL.absoluteString);
   NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        if (error) {
            if (failureHandler) {
                failureHandler(error);
            }
        } else {
            NSParameterAssert([responseObject isKindOfClass:[DDXMLDocument class]]);
            if([responseObject isKindOfClass:[DDXMLDocument class]]){
                @autoreleasepool {
                    DDXMLDocument *document = (DDXMLDocument *)responseObject;
                    // Check for Last.fm errors
                    if (![[[document rootElement] objectAtXPath:@"./@status"] isEqualToString:@"ok"]) {
                        if (failureHandler) {
                            NSError *lastfmError = [[NSError alloc] initWithDomain:LastFmServiceErrorDomain
                                                                              code:[[[document rootElement] objectAtXPath:@"./error/@code"] intValue]
                                                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[[document rootElement] objectAtXPath:@"./error"], NSLocalizedDescriptionKey, method, @"method", nil]];
                            
                            failureHandler(lastfmError);
                        }
                        return;
                    }
                    NSArray *output = [[document rootElement] nodesForXPath:rootXpath error:&error];
                    NSMutableArray *returnArray = [NSMutableArray array];
                    for (DDXMLNode *node in output) {
                        // Convert this node to a dictionary using the mapping object (keys and xpaths)
                        NSMutableDictionary *result = [NSMutableDictionary dictionary];
                        [result setObject:originalParams forKey:@"_params"];
                        
                        for (NSString *key in mappingObject) {
                            NSArray *mappingArray = [mappingObject objectForKey:key];
                            NSString *xpath = [mappingArray objectAtIndex:0];
                            NSString *targetClass = [mappingArray objectAtIndex:1];
                            NSString *value = [node objectAtXPath:xpath];
                            id correctValue = [self transformValue:value intoClass:targetClass];
                            if (correctValue != nil) {
                                [result setObject:correctValue forKey:key];
                            }
                        }
                        
                        [returnArray addObject:result];
                    }
                    if (successHandler) {
                        id returnObject;
                        if (returnDictionary) {
                            returnObject = (returnArray.count > 0 ? [returnArray objectAtIndex:0] : @{});
                        } else {
                            returnObject = returnArray;
                        }
                        successHandler(returnObject);
                    }
                }
            }
            else{
                // Check for XML parsing errors
                if (failureHandler) {
                        failureHandler(error);
                }
                return;
            }
        }
    }];
    [dataTask resume];
    return dataTask;

}

#pragma mark - Artist methods

- (NSURLSessionDataTask *)getInfoForArtist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"bio": @[ @"./bio/content", @"NSString" ],
        @"summary": @[ @"./bio/summary", @"NSString" ],
        @"name": @[ @"./name", @"NSString" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"imageSmall": @[ @"./image[@size=\"small\"]", @"NSURL" ],
        @"imageMedium": @[ @"./image[@size=\"medium\"]", @"NSURL" ],
        @"imageLarge": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"imageExtraLarge": @[ @"./image[@size=\"extralarge\"]", @"NSURL" ],
        @"imageMega": @[ @"./image[@size=\"mega\"]", @"NSURL" ],
        @"listeners": @[ @"./stats/listeners", @"NSNumber" ],
        @"playcount": @[ @"./stats/playcount", @"NSNumber" ],
        @"userplaycount": @[ @"./stats/userplaycount", @"NSNumber" ],
        @"tags": @[ @"./tags/tag/name", @"NSArray" ],
        @"ontour": @[ @"./ontour", @"NSNumber" ],
    };

    return [self performApiCallForMethod:@"artist.getInfo"
                              withParams:@{ @"artist": [self forceString:artist] ,@"autocorrect":@(autocorrect)}
                               rootXpath:@"./artist"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getEventsForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"title": @[ @"./title", @"NSString" ],
        @"headliner": @[ @"./artists/headliner", @"NSString" ],
        @"attendance": @[ @"./attendance", @"NSNumber" ],
        @"description": @[ @"./description", @"NSString" ],
        @"startDate": @[ @"./startDate", @"NSDate" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"venue": @[ @"./venue/name", @"NSString" ],
        @"city": @[ @"./venue/location/city", @"NSString" ],
        @"country": @[ @"./venue/location/country", @"NSString" ],
        @"venue_url": @[ @"./venue/website", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"artist.getEvents"
                              withParams:@{ @"artist": [self forceString:artist] }
                               rootXpath:@"./events/event"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopAlbumsForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"title": @[ @"./name", @"NSString" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"artist.getTopAlbums"
                             withParams:@{ @"artist": [self forceString:artist], @"limit": @"500" }
                              rootXpath:@"./topalbums/album"
                       returnDictionary:NO
                          mappingObject:mappingObject
                         successHandler:successHandler
                         failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopTracksForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"artist.getTopTracks"
                             withParams:@{ @"artist": [self forceString:artist], @"limit": @"500" }
                              rootXpath:@"./toptracks/track"
                       returnDictionary:NO
                          mappingObject:mappingObject
                         successHandler:successHandler
                         failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getImagesForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"format": @[ @"format", @"NSString"],
        @"original": @[ @"./sizes/size[@name=\"original\"]", @"NSURL" ],
        @"original_width": @[ @"./sizes/size[@name=\"original\"]/@width", @"NSNumber" ],
        @"original_height": @[ @"./sizes/size[@name=\"original\"]/@height", @"NSNumber" ],
        @"extralarge": @[ @"./sizes/size[@name=\"extralarge\"]", @"NSURL" ],
        @"extralarge_width": @[ @"./sizes/size[@name=\"extralarge\"]/@width", @"NSNumber" ],
        @"extralarge_height": @[ @"./sizes/size[@name=\"extralarge\"]/@height", @"NSNumber" ],
        @"large": @[ @"./sizes/size[@name=\"large\"]", @"NSURL" ],
        @"large_width": @[ @"./sizes/size[@name=\"large\"]/@width", @"NSNumber" ],
        @"large_height": @[ @"./sizes/size[@name=\"large\"]/@height", @"NSNumber" ],
        @"largesquare": @[ @"./sizes/size[@name=\"largesquare\"]", @"NSURL" ],
        @"largesquare_width": @[ @"./sizes/size[@name=\"largesquare\"]/@width", @"NSNumber" ],
        @"largesquare_height": @[ @"./sizes/size[@name=\"largesquare\"]/@height", @"NSNumber" ],
        @"medium": @[ @"./sizes/size[@name=\"medium\"]", @"NSURL" ],
        @"medium_width": @[ @"./sizes/size[@name=\"medium\"]/@width", @"NSNumber" ],
        @"medium_height": @[ @"./sizes/size[@name=\"medium\"]/@height", @"NSNumber" ],
        @"small": @[ @"./sizes/size[@name=\"small\"]", @"NSURL" ],
        @"small_width": @[ @"./sizes/size[@name=\"small\"]/@width", @"NSNumber" ],
        @"small_height": @[ @"./sizes/size[@name=\"small\"]/@height", @"NSNumber" ],
        @"title": @[ @"title", @"NSString" ],
        @"url": @[ @"url", @"NSURL" ],
        @"owner": @[ @"./owner/name", @"NSString" ],
        @"thumbsup": @[ @"./votes/thumbsup", @"NSNumber" ],
        @"thumbsdown": @[ @"./votes/thumbsdown", @"NSNumber" ],
    };

    return [self performApiCallForMethod:@"artist.getImages"
                              withParams:@{ @"artist": [self forceString:artist], @"limit": @"500" }
                               rootXpath:@"./images/image"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getSimilarArtistsTo:(NSString *)artist autocorrect:(BOOL)autocorrect limit:(NSUInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"match": @[ @"./match", @"NSNumber" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
    };

    return [self performApiCallForMethod:@"artist.getSimilar"
                              withParams:@{ @"artist": [self forceString:artist], @"limit": @(limit),@"autocorrect":@(autocorrect) }
                               rootXpath:@"./similarartists/artist"
                        returnDictionary:NO
                           mappingObject:mappingObject
                         successHandler:successHandler
                         failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopTagsForArtist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler{
    NSDictionary *mappingObject = @{
                                    @"name": @[ @"./name", @"NSString" ],
                                    @"count": @[ @"./count", @"NSNumber" ],
                                    @"url": @[ @"./url", @"NSURL" ],
                                    };
    
    return [self performApiCallForMethod:@"artist.getTopTags"
                              withParams:@{ @"artist": [self forceString:artist], @"autocorrect":@(autocorrect)}
                               rootXpath:@"./toptags/tag"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - Album methods

- (NSURLSessionDataTask *)getInfoForAlbum:(NSString *)album artist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"artist": @[ @"./artist", @"NSString" ],
        @"name": @[ @"./name", @"NSString" ],
        @"listeners": @[ @"./listeners", @"NSNumber" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"imageSmall": @[ @"./image[@size=\"small\"]", @"NSURL" ],
        @"imageMedium": @[ @"./image[@size=\"medium\"]", @"NSURL" ],
        @"imageLarge": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"imageExtraLarge": @[ @"./image[@size=\"extralarge\"]", @"NSURL" ],
        @"imageMega": @[ @"./image[@size=\"mega\"]", @"NSURL" ],
        @"releasedate": @[ @"./releasedate", @"NSString" ], // deprecated
        @"date": @[ @"./releasedate", @"NSDate" ],
        @"tags": @[ @"./toptags/tag/name", @"NSArray" ],
        @"userplaycount": @[ @"./userplaycount", @"NSNumber" ],
        @"summary": @[ @"./wiki/summary", @"NSString" ],
    };

    return [self performApiCallForMethod:@"album.getInfo"
                              withParams:@{ @"artist": [self forceString:artist], @"album": [self forceString:album] ,@"autocorrect":@(autocorrect)}
                               rootXpath:@"./album"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTracksForAlbum:(NSString *)album artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"rank": @[ @"@rank", @"NSNumber" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"name": @[ @"./name", @"NSString" ],
        @"duration": @[ @"./duration", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ],
    };

    return [self performApiCallForMethod:@"album.getInfo"
                              withParams:@{ @"artist": [self forceString:artist], @"album": [self forceString:album], @"1": @"1" }
                               rootXpath:@"./album/tracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getBuyLinksForAlbum:(NSString *)album artist:(NSString *)artist country:(NSString *)country successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"url": @[ @"./buyLink", @"NSURL" ],
        @"price": @[ @"./price/amount", @"NSNumber" ],
        @"currency": @[ @"./price/currency", @"NSString" ],
        @"name": @[ @"./supplierName", @"NSString" ],
        @"icon": @[ @"./supplierIcon", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"album.getBuylinks"
                              withParams:@{ @"artist": [self forceString:artist], @"album": [self forceString:album], @"country": [self forceString:country] }
                               rootXpath:@"./affiliations/downloads/affiliation"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopTagsForAlbum:(NSString *)album artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"count": @[ @"./count", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"album.getTopTags"
                              withParams:@{ @"artist": [self forceString:artist], @"album": [self forceString:album] }
                               rootXpath:@"./toptags/tag"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - Tag methods

- (NSURLSessionDataTask *)getTopAlbumsForTag:(NSString *)tag successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler{
    NSDictionary *mappingObject = @{
                                    @"artist": @[ @"./artist/name", @"NSString" ],
                                    @"name": @[ @"./name", @"NSString" ],
                                    @"url": @[ @"./url", @"NSURL" ],
                                    @"imageSmall": @[ @"./image[@size=\"small\"]", @"NSURL" ],
                                    @"imageMedium": @[ @"./image[@size=\"medium\"]", @"NSURL" ],
                                    @"imageLarge": @[ @"./image[@size=\"large\"]", @"NSURL" ],
                                    @"imageExtraLarge": @[ @"./image[@size=\"extralarge\"]", @"NSURL" ],
                                    };
    return [self performApiCallForMethod:@"tag.getTopAlbums"
                              withParams:@{ @"tag": [self forceString:tag], @"limit": @"10"}
                               rootXpath:@"./albums/album"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - Track methods

- (NSURLSessionDataTask *)getInfoForTrack:(NSString *)title artist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"listeners": @[ @"./listeners", @"NSNumber" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"tags": @[ @"./toptags/tag/name", @"NSArray" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"album": @[ @"./album/title", @"NSString" ],
        @"imageSmall": @[ @"./album/image[@size=\"small\"]", @"NSURL" ],
        @"imageMedium": @[ @"./album/image[@size=\"medium\"]", @"NSURL" ],
        @"imageLarge": @[ @"./album/image[@size=\"large\"]", @"NSURL" ],
        @"imageExtraLarge": @[ @"./album/image[@size=\"extralarge\"]", @"NSURL" ],
        @"imageMega": @[ @"./album/image[@size=\"mega\"]", @"NSURL" ],
        @"wiki": @[ @"./wiki/summary", @"NSString" ],
        @"duration": @[ @"./duration", @"NSNumber" ],
        @"userplaycount": @[ @"./userplaycount", @"NSNumber" ],
        @"userloved": @[ @"./userloved", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"track.getInfo"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] ,@"autocorrect":@(autocorrect)}
                               rootXpath:@"./track"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getInfoForTrack:(NSString *)musicBrainId successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"listeners": @[ @"./listeners", @"NSNumber" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"tags": @[ @"./toptags/tag/name", @"NSArray" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"album": @[ @"./album/title", @"NSString" ],
        @"image": @[ @"./album/image[@size=\"large\"]", @"NSURL" ],
        @"wiki": @[ @"./wiki/summary", @"NSString" ],
        @"duration": @[ @"./duration", @"NSNumber" ],
        @"userplaycount": @[ @"./userplaycount", @"NSNumber" ],
        @"userloved": @[ @"./userloved", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"track.getInfo"
                             withParams:@{ @"mbid": [self forceString:musicBrainId] }
                              rootXpath:@"./track"
                       returnDictionary:YES
                          mappingObject:mappingObject
                         successHandler:successHandler
                         failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)loveTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    return [self performApiCallForMethod:@"track.love"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] }
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)unloveTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    return [self performApiCallForMethod:@"track.unlove"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] }
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)banTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    return [self performApiCallForMethod:@"track.ban"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] }
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)unbanTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    return [self performApiCallForMethod:@"track.unban"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] }
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getBuyLinksForTrack:(NSString *)title artist:(NSString *)artist country:(NSString *)country successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"url": @[ @"./buyLink", @"NSURL" ],
        @"price": @[ @"./price/amount", @"NSNumber" ],
        @"currency": @[ @"./price/currency", @"NSString" ],
        @"name": @[ @"./supplierName", @"NSString" ],
        @"icon": @[ @"./supplierIcon", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"track.getBuylinks"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist], @"country": [self forceString:country] }
                               rootXpath:@"./affiliations/downloads/affiliation"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getSimilarTracksTo:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"rank": @[ @"@rank", @"NSNumber" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"name": @[ @"./name", @"NSString" ],
        @"duration": @[ @"./duration", @"NSNumber" ],
        @"url": @[ @"./url", @"NSURL" ],
    };

    return [self performApiCallForMethod:@"track.getsimilar"
                              withParams:@{ @"track": [self forceString:title], @"artist": [self forceString:artist] }
                               rootXpath:@"./similartracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - User methods

// Please note: to use this method, your API key needs special permission
- (NSURLSessionDataTask *)createUserWithUsername:(NSString *)username password:(NSString *)password email:(NSString *)email successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"url": @[ @"./url", @"NSURL" ],
    };

    NSDictionary *params = @{
        @"username": [self forceString:username],
        @"password": [self forceString:password],
        @"email": [self forceString:email],
    };

    return [self performApiCallForMethod:@"user.signUp"
                              withParams:params
                               rootXpath:@"./user"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getSessionForUser:(NSString *)username password:(NSString *)password successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    username = [self forceString:username];
    password = [self forceString:password];
    NSString *authToken = [self md5sumFromString:[NSString stringWithFormat:@"%@%@", [username lowercaseString], [self md5sumFromString:password]]];

    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"key": @[ @"./key", @"NSString" ],
        @"subscriber": @[ @"./subscriber", @"NSNumber" ]
    };

    return [self performApiCallForMethod:@"auth.getMobileSession"
                              withParams:@{ @"username": [username lowercaseString], @"authToken": authToken }
                               rootXpath:@"./session"
                        returnDictionary:YES
                            mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getSessionInfoWithSuccessHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./session/name", @"NSString" ],
        @"subscriber": @[ @"./session/subscriber", @"NSNumber" ],
        @"country": @[ @"./country", @"NSString" ],
        @"radio_enabled": @[ @"./radioPermission/user[@type=\"you\"]/radio", @"NSNumber" ],
        @"trial_enabled": @[ @"./radioPermission/user[@type=\"you\"]/freetrial", @"NSNumber" ],
        @"trial_expired": @[ @"./radioPermission/user[@type=\"you\"]/trial/expired", @"NSNumber" ],
        @"trial_playsleft": @[ @"./radioPermission/user[@type=\"you\"]/trial/playsleft", @"NSNumber" ],
        @"trial_playselapsed": @[ @"./radioPermission/user[@type=\"you\"]/trial/playselapsed", @"NSNumber" ]
    };

    return [self performApiCallForMethod:@"auth.getSessionInfo"
                              withParams:@{}
                               rootXpath:@"./application"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)sendNowPlayingTrack:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(NSTimeInterval)duration successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *params = @{
        @"track": [self forceString:track],
        @"artist": [self forceString:artist],
        @"album": [self forceString:album],
        @"duration": @((int)duration)
    };

    return [self performApiCallForMethod:@"track.updateNowPlaying"
                              withParams:params
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)sendScrobbledTrack:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(NSTimeInterval)duration atTimestamp:(NSTimeInterval)timestamp successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *params = @{
        @"track": [self forceString:track],
        @"artist": [self forceString:artist],
        @"album": [self forceString:album],
        @"duration": @((int)duration),
        @"timestamp": @((int)timestamp)
    };

    return [self performApiCallForMethod:@"track.scrobble"
                                
                              withParams:params
                               rootXpath:@"."
                        returnDictionary:YES
                           mappingObject:@{}
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getNewReleasesForUserBasedOnRecommendations:(BOOL)basedOnRecommendations successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"releasedate": @[ @"@releasedate", @"NSString" ], // deprecated
        @"date": @[ @"@releasedate", @"NSDate" ],
    };

    NSDictionary *params = @{
        @"user": [self forceString:self.username],
        @"userec": @(basedOnRecommendations)
    };

    return [self performApiCallForMethod:@"user.getNewReleases"
                              withParams:params
                               rootXpath:@"./albums/album"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getRecommendedAlbumsWithLimit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"context": @[ @"./context/artist/name", @"NSArray" ],
    };

    return [self performApiCallForMethod:@"user.getRecommendedAlbums"
                              withParams:@{ @"limit": @(limit) }
                               rootXpath:@"./recommendations/album"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (void)logout {
    self.session = nil;
    self.username = nil;
}

#pragma mark - General User methods

- (NSURLSessionDataTask *)getInfoForUserOrNil:(NSString *)username successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./realname", @"NSString" ],
        @"username": @[ @"./name", @"NSString" ],
        @"gender": @[ @"./gender", @"NSString" ],
        @"age": @[ @"./age", @"NSNumber" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"country": @[ @"./country", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"registered": @[ @"./registered", @"NSDate" ],
    };

    NSDictionary *params = @{};
    if (username) {
        params = @{ @"user": [self forceString:username] };
    }

    return [self performApiCallForMethod:@"user.getInfo"
                              withParams:params
                               rootXpath:@"./user"
                        returnDictionary:YES
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopArtistsForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"url": @[ @"url", @"NSURL" ],
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"period": [self period:period],
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getTopArtists"
                              withParams:params
                               rootXpath:@"./topartists/artist"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getRecentTracksForUserOrNil:(NSString *)username limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist", @"NSString" ],
        @"album": @[ @"./album", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"date": @[ @"./date", @"NSDate" ],
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getRecentTracks"
                              withParams:params
                               rootXpath:@"./recenttracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getLovedTracksForUserOrNil:(NSString *)username limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"date": @[ @"./date", @"NSDate" ],
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getLovedTracks"
                              withParams:params
                               rootXpath:@"./lovedtracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopTracksForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"url": @[ @"./url", @"NSURL" ],
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"period": [self period:period],
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getTopTracks"
                              withParams:params
                               rootXpath:@"./toptracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getEventsForUserOrNil:(NSString *)username festivalsOnly:(BOOL)festivalsonly limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"title": @[ @"./title", @"NSString" ],
        @"headliner": @[ @"./artists/headliner", @"NSString" ],
        @"artists": @[ @"./artists/artist", @"NSArray" ],
        @"attendance": @[ @"./attendance", @"NSNumber" ],
        @"description": @[ @"./description", @"NSString" ],
        @"startDate": @[ @"./startDate", @"NSDate" ],
        @"url": @[ @"./url", @"NSURL" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"venue": @[ @"./venue/name", @"NSString" ],
        @"city": @[ @"./venue/location/city", @"NSString" ],
        @"country": @[ @"./venue/location/country", @"NSString" ],
        @"venue_url": @[ @"./venue/website", @"NSURL" ]
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"festivalsonly": @(festivalsonly),
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getEvents"
                              withParams:params
                               rootXpath:@"./events/event"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getTopAlbumsForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"url": @[ @"url", @"NSURL" ],
    };

    NSDictionary *params = @{
        @"user": username ? [self forceString:username] : [self forceString:self.username],
        @"period": [self period:period],
        @"limit": @(limit),
    };

    return [self performApiCallForMethod:@"user.getTopAlbums"
                              withParams:params
                               rootXpath:@"./topalbums/album"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - Chart methods

- (NSURLSessionDataTask *)getTopTracksWithLimit:(NSInteger)limit page:(NSInteger)page successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"playcount": @[ @"./playcount", @"NSNumber" ],
        @"listeners": @[ @"./listeners", @"NSNumber" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"artist": @[ @"./artist/name", @"NSString" ]
    };

    return [self performApiCallForMethod:@"chart.getTopTracks"
                              withParams:@{ @"limit": @(limit), @"page": @(page) }
                               rootXpath:@"./tracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

- (NSURLSessionDataTask *)getHypedTracksWithLimit:(NSInteger)limit page:(NSInteger)page successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"name": @[ @"./name", @"NSString" ],
        @"image": @[ @"./image[@size=\"large\"]", @"NSURL" ],
        @"artist": @[ @"./artist/name", @"NSString" ],
        @"percentagechange": @[ @"./percentagechange", @"NSNumber" ]
    };

    return [self performApiCallForMethod:@"chart.getHypedTracks"
                              withParams:@{ @"limit": @(limit), @"page": @(page) }
                               rootXpath:@"./tracks/track"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

#pragma mark - Geo methods

- (NSURLSessionDataTask *)getEventsForLocation:(NSString *)location successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler {
    NSDictionary *mappingObject = @{
        @"title": @[ @"./title", @"NSString" ],
        @"venue": @[ @"./venue/name", @"NSString" ],
        @"city": @[ @"./venue/location/city", @"NSString" ],
        @"country": @[ @"./venue/location/country", @"NSString" ],
        @"latitude": @[ @"./venue/location/*/*[local-name()='lat']", @"NSNumber" ],
        @"longitude": @[ @"./venue/location/*/*[local-name()='long']", @"NSNumber" ],
        @"url": @[ @"url", @"NSURL" ]
    };

    return [self performApiCallForMethod:@"geo.getEvents"
                              withParams:@{ @"location": [self forceString:location] }
                               rootXpath:@"./events/event"
                        returnDictionary:NO
                           mappingObject:mappingObject
                          successHandler:successHandler
                          failureHandler:failureHandler];
}

@end





@implementation DDXMLParserResponseSerializer

+ (instancetype)serializer {
    DDXMLParserResponseSerializer *serializer = [[self alloc] init];
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.acceptableContentTypes = [[NSSet alloc] initWithObjects:@"application/xml", @"text/xml", nil];
    return self;
}

#pragma mark - AFURLResponseSerialization

static BOOL DDErrorOrUnderlyingErrorHasCodeInDomain(NSError *error, NSInteger code, NSString *domain) {
    if ([error.domain isEqualToString:domain] && error.code == code) {
        return YES;
    } else if (error.userInfo[NSUnderlyingErrorKey]) {
        return DDErrorOrUnderlyingErrorHasCodeInDomain(error.userInfo[NSUnderlyingErrorKey], code, domain);
    }
    
    return NO;
}

- (id)responseObjectForResponse:(NSHTTPURLResponse *)response
                           data:(NSData *)data
                          error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:(NSHTTPURLResponse *)response data:data error:error]) {
        if (!error || DDErrorOrUnderlyingErrorHasCodeInDomain(*error, NSURLErrorCannotDecodeContentData, AFURLResponseSerializationErrorDomain)) {
            return nil;
        }
    }
    
//#ifndef __OPTIMIZE__
//    NSString *respStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    NSLog(@"lastfm response: %@",respStr);
//#endif
    
    NSError *docError = nil;
    DDXMLDocument *document = [[DDXMLDocument alloc] initWithData:data options:0 error:&docError];
    return document;
}

@end



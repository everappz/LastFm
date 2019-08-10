//
//  LastFm.h
//  lastfmlocalplayback
//
//  Created by Kevin Renskers on 17-08-12.
//  Copyright (c) 2012 Gangverk. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LastFmServiceErrorDomain @"LastFmServiceErrorDomain"

enum LastFmServiceErrorCodes {
	kLastFmErrorCodeInvalidService = 2,
	kLastFmErrorCodeInvalidMethod = 3,
	kLastFmErrorCodeAuthenticationFailed = 4,
	kLastFmErrorCodeInvalidFormat = 5,
	kLastFmErrorCodeInvalidParameters = 6,
	kLastFmErrorCodeInvalidResource = 7,
	kLastFmErrorCodeOperationFailed = 8,
	kLastFmErrorCodeInvalidSession = 9,
	kLastFmErrorCodeInvalidAPIKey = 10,
	kLastFmErrorCodeServiceOffline = 11,
	kLastFmErrorCodeSubscribersOnly = 12,
	kLastFmErrorCodeInvalidAPISignature = 13,
    kLastFmerrorCodeServiceError = 16
};

enum LastFmRadioErrorCodes {
	kLastFmErrorCodeTrialExpired = 18,
	kLastFmErrorCodeNotEnoughContent = 20,
	kLastFmErrorCodeNotEnoughMembers = 21,
	kLastFmErrorCodeNotEnoughFans = 22,
	kLastFmErrorCodeNotEnoughNeighbours = 23,
	kLastFmErrorCodeDeprecated = 27,
	kLastFmErrorCodeGeoRestricted = 28
};

typedef enum {
	kLastFmPeriodOverall,
    kLastFmPeriodWeek,
    kLastFmPeriodMonth,
    kLastFmPeriodQuarter,
    kLastFmPeriodHalfYear,
    kLastFmPeriodYear,
} LastFmPeriod;

typedef void (^LastFmReturnBlockWithObject)(id result);
typedef void (^LastFmReturnBlockWithDictionary)(NSDictionary *result);
typedef void (^LastFmReturnBlockWithArray)(NSArray *result);
typedef void (^LastFmReturnBlockWithError)(NSError *error);


@interface LastFm : NSObject

@property (copy, nonatomic) NSString *session;
@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *apiKey;
@property (copy, nonatomic) NSString *apiSecret;
@property (nonatomic) NSTimeInterval timeoutInterval;
@property (nonatomic) BOOL nextRequestIgnoresCache;

+ (void)setSharedInstance:(LastFm *)sharedInstance;
+ (LastFm *)sharedInstance;
- (instancetype)initWithApiKey:(NSString *)apiKey apiSecret:(NSString *)apiSecret;
    
- (NSString *)forceString:(NSString *)value;
- (NSURLSessionDataTask *)performApiCallForMethod:(NSString*)method withParams:(NSDictionary *)params rootXpath:(NSString *)rootXpath returnDictionary:(BOOL)returnDictionary mappingObject:(NSDictionary *)mappingObject successHandler:(LastFmReturnBlockWithObject)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Artist methods
///----------------------------------

- (NSURLSessionDataTask *)getInfoForArtist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler ;
- (NSURLSessionDataTask *)getEventsForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopAlbumsForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopTracksForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getImagesForArtist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getSimilarArtistsTo:(NSString *)artist autocorrect:(BOOL)autocorrect limit:(NSUInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopTagsForArtist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Album methods
///----------------------------------

- (NSURLSessionDataTask *)getInfoForAlbum:(NSString *)album artist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTracksForAlbum:(NSString *)album artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getBuyLinksForAlbum:(NSString *)album artist:(NSString *)artist country:(NSString *)country successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopTagsForAlbum:(NSString *)album artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Track methods
///----------------------------------

- (NSURLSessionDataTask *)getInfoForTrack:(NSString *)title artist:(NSString *)artist autocorrect:(BOOL)autocorrect successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getInfoForTrack:(NSString *)musicBrainId successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)loveTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)unloveTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)banTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)unbanTrack:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getBuyLinksForTrack:(NSString *)title artist:(NSString *)artist country:(NSString *)country successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getSimilarTracksTo:(NSString *)title artist:(NSString *)artist successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Authenticated User methods
///----------------------------------

- (NSURLSessionDataTask *)createUserWithUsername:(NSString *)username password:(NSString *)password email:(NSString *)email successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getSessionForUser:(NSString *)username password:(NSString *)password successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getSessionInfoWithSuccessHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)sendNowPlayingTrack:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(NSTimeInterval)duration successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)sendScrobbledTrack:(NSString *)track byArtist:(NSString *)artist onAlbum:(NSString *)album withDuration:(NSTimeInterval)duration atTimestamp:(NSTimeInterval)timestamp successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getNewReleasesForUserBasedOnRecommendations:(BOOL)basedOnRecommendations successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getRecommendedAlbumsWithLimit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (void)logout;

///----------------------------------
/// @name General User methods
///----------------------------------

- (NSURLSessionDataTask *)getInfoForUserOrNil:(NSString *)username successHandler:(LastFmReturnBlockWithDictionary)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopArtistsForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getRecentTracksForUserOrNil:(NSString *)username limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getLovedTracksForUserOrNil:(NSString *)username limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopTracksForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getEventsForUserOrNil:(NSString *)username festivalsOnly:(BOOL)festivalsonly limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getTopAlbumsForUserOrNil:(NSString *)username period:(LastFmPeriod)period limit:(NSInteger)limit successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Chart methods
///----------------------------------

- (NSURLSessionDataTask *)getTopTracksWithLimit:(NSInteger)limit page:(NSInteger)page successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;
- (NSURLSessionDataTask *)getHypedTracksWithLimit:(NSInteger)limit page:(NSInteger)page successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;

///----------------------------------
/// @name Geo methods
///----------------------------------

- (NSURLSessionDataTask *)getEventsForLocation:(NSString *)location successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;


///----------------------------------
/// @name Tag methods
///----------------------------------

- (NSURLSessionDataTask *)getTopAlbumsForTag:(NSString *)tag successHandler:(LastFmReturnBlockWithArray)successHandler failureHandler:(LastFmReturnBlockWithError)failureHandler;


@end

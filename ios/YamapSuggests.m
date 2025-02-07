#import "YamapSuggests.h"

@import YandexMapsMobile;

@implementation YamapSuggests {
    YMKSearchManager* searchManager;
    YMKSearchSuggestSession* suggestClient;
    YMKBoundingBox* defaultBoundingBox;
    YMKSuggestOptions* suggestOptions;
}

-(id)init {
    self = [super init];
    
    YMKPoint* southWestPoint = [YMKPoint pointWithLatitude:-90.0 longitude:-180.0];
    YMKPoint* northEastPoint = [YMKPoint pointWithLatitude:90.0 longitude:180.0];
    defaultBoundingBox = [YMKBoundingBox boundingBoxWithSouthWest:southWestPoint northEast:northEastPoint];
    suggestOptions = [YMKSuggestOptions suggestOptionsWithSuggestTypes: YMKSuggestTypeGeo
                                                                             userPosition:nil
                                                                             suggestWords:true];
    
    searchManager = [[YMKSearch sharedInstance] createSearchManagerWithSearchManagerType:YMKSearchSearchManagerTypeOnline];
    
    return self;
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

// TODO: Этот метод можно вынести в отдельный файл утилей, но пока в этом нет необходимости.
void runOnMainQueueWithoutDeadlocking(void (^block)(void))
{
    if ([NSThread isMainThread])
    {
        block();
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

NSString* ERR_NO_REQUEST_ARG = @"YANDEX_SUGGEST_ERR_NO_REQUEST_ARG";
NSString* ERR_SUGGEST_FAILED = @"YANDEX_SUGGEST_ERR_SUGGEST_FAILED";

-(YMKSearchSuggestSession*_Nonnull) getSuggestClient {
    if (suggestClient) {
        return suggestClient;
    }
    runOnMainQueueWithoutDeadlocking(^{
        self->suggestClient = [self->searchManager createSuggestSession];
    });
    return suggestClient;
}

RCT_EXPORT_METHOD(suggest:(nonnull NSString*) searchQuery
                resolver:(RCTPromiseResolveBlock) resolve
                rejecter:(RCTPromiseRejectBlock) reject {
    @try {
        YMKSearchSuggestSession* session = [self getSuggestClient];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [session suggestWithText:searchQuery
                              window:self->defaultBoundingBox
                      suggestOptions:self->suggestOptions
                     responseHandler:^(NSArray<YMKSuggestItem *> * _Nullable suggestList, NSError * _Nullable error){
                if (error) {
                    reject(ERR_SUGGEST_FAILED, [NSString stringWithFormat:@"search request: %@", searchQuery], error);
                    return;
                }
                
                NSMutableArray *suggestsToPass = [NSMutableArray new];
                for (YMKSuggestItem* suggest in suggestList) {
                    NSMutableDictionary *suggestToPass = [NSMutableDictionary new];
                    
                    [suggestToPass setValue:[[suggest title] text] forKey:@"title"];
                    [suggestToPass setValue:[[suggest subtitle] text] forKey:@"subtitle"];
                    [suggestToPass setValue:[suggest uri] forKey:@"uri"];
                    
                    [suggestsToPass addObject:suggestToPass];
                }
                
                resolve(suggestsToPass);
            }];
        });
    }
    @catch ( NSException *error ) {
        reject(ERR_NO_REQUEST_ARG, [NSString stringWithFormat:@"search request: %@", searchQuery], nil);
    }
})

RCT_EXPORT_METHOD(resetSuggest: (NSString*) ususedParam
                      resolver:(RCTPromiseResolveBlock) resolve
                      rejecter:(RCTPromiseRejectBlock) reject {
    @try {
        if (suggestClient) {
            [suggestClient reset];
        }
        resolve(@[]);
    }
    @catch( NSException *error ) {
        reject(@"ERROR", @"Error during reset suggestions", nil);
    }
})

RCT_EXPORT_MODULE();

@end

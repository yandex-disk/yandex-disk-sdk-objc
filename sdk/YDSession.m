/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#if !(__has_feature(objc_arc))
#   error ARC is required. Add -fobj-arc compiler flag for this file.
#endif


#import "YDSession.h"
#import "YDConstants.h"
#import "NSNotificationCenter+Additions.h"
#import "YDFileListRequest.h"
#import "YDMKCOLRequest.h"
#import "YDMOVERequest.h"
#import "YDDeleteRequest.h"
#import "YDDiskPOSTRequest.h"
#import "YDFileUploadRequest.h"


@interface YDSession ()

+ (NSURL *)urlForDiskPath:(NSString *)path;
+ (NSURL *)urlForLocalPath:(NSString *)path;

- (void)prepareRequest:(YDDiskRequest *)request;

- (void)removePath:(NSString *)path toTrash:(BOOL)trash completion:(YDHandler)block;

@end


@implementation YDSession

- (instancetype)init
{
    NSAssert(YES, @"use initWithDelegate:");
    return nil;
}

- (instancetype)initWithDelegate:(id<YDSessionDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (BOOL)authenticated
{
    return self.OAuthToken.length > 0;
}

- (void)fetchDirectoryContentsAtPath:(NSString *)path completion:(YDFetchDirectoryHandler)block
{
    NSURL *url = [YDSession urlForDiskPath:path];
    if (!url) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"listPath": path}], nil);
        return;
    }

    YDFileListRequest *request = [[YDFileListRequest alloc] initWithURL:url];
    [self prepareRequest:request];
    request.depth = YDWebDAVDepth1;

    request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    request.props = @[[YDFileListRequest displayNameProp],
                      [YDFileListRequest resourceTypeProp],
                      [YDFileListRequest contentTypeProp],
                      [YDFileListRequest contentLengthProp],
                      [YDFileListRequest lastModifiedProp],
                      [YDFileListRequest eTagProp],
                      [YDFileListRequest readonlyProp],
                      [YDFileListRequest publicUrlProp],
                      [YDFileListRequest sharedProp]];

    request.didFailBlock = ^(NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"URL"] = url;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithFetchDirectoryRequestNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo], nil);
    };

    request.didReceiveMultistatusResponsesBlock = ^(NSArray *responses) {
        NSMutableArray *fileItems = [NSMutableArray arrayWithCapacity:0];

        for (YDMultiStatusResponse *response in responses) {
            YDItemStat *item = [[YDItemStat alloc] initWithSession:self
                                                        dictionary:response.successPropValues
                                                               URL:response.URL];

            if (![response.URL.path isEqual:url.path]) {
                [fileItems addObject:item];
            }
        }

        block(nil, fileItems);
    };
    
    [request start];
}

- (void)fetchStatusForPath:(NSString *)path completion:(YDFetchStatusHandler)block
{
    NSURL *url = [YDSession urlForDiskPath:path];
    if (!url) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"statPath": path}], nil);
        return;
    }

    YDFileListRequest *request = [[YDFileListRequest alloc] initWithURL:url];
    [self prepareRequest:request];
    request.depth = YDWebDAVDepth0;

    request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    request.props = @[[YDFileListRequest displayNameProp],
                      [YDFileListRequest resourceTypeProp],
                      [YDFileListRequest contentTypeProp],
                      [YDFileListRequest contentLengthProp],
                      [YDFileListRequest lastModifiedProp],
                      [YDFileListRequest eTagProp],
                      [YDFileListRequest readonlyProp],
                      [YDFileListRequest publicUrlProp],
                      [YDFileListRequest sharedProp]];

    request.didFailBlock = ^(NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"URL"]=url;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithFetchStatusRequestNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo], nil);
    };

    request.didReceiveMultistatusResponsesBlock = ^(NSArray *responses) {
        for (YDMultiStatusResponse *response in responses) {
            if ([response.URL.path isEqual:url.path]) {
                YDItemStat *item = [[YDItemStat alloc] initWithSession:self
                                                            dictionary:response.successPropValues
                                                                   URL:response.URL];
                block(nil, item);
                return;
            }
        }
        block(nil, nil);
    };

    [request start];
}

- (void)createDirectoryAtPath:(NSString *)path completion:(YDHandler)block
{
    NSURL *url = [YDSession urlForDiskPath:path];
    if (!url) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"mkDirAtPath": path}]);
        return;
    }

    YDMKCOLRequest *request = [[YDMKCOLRequest alloc] initWithURL:url];
    [self prepareRequest:request];

    request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    NSURL *requestURL = [request.URL copy];

    request.didFailBlock = ^(NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"URL"] = requestURL;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailToCreateDirectoryNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo]);
    };

    request.didFinishLoadingBlock = ^(NSData *receivedData) {
        NSDictionary *userInfo = @{@"URL": requestURL};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidCreateDirectoryNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block(nil);
    };

    [request start];

    NSDictionary *userInfo = @{@"URL": request.URL};
    [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidSendCreateDirectoryRequestNotification
                                                                       object:self
                                                                     userInfo:userInfo];
}

- (void)removePath:(NSString *)path toTrash:(BOOL)trash completion:(YDHandler)block
{
    NSURL *url = [YDSession urlForDiskPath:path];
    if (!url) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{trash?@"trashPath":@"removePath": path}]);
        return;
    }

    NSString *urlstr = url.absoluteString;
    urlstr = [urlstr stringByAppendingFormat:@"?trash=%@", trash?@"true":@"false"];
    url = [NSURL URLWithString:urlstr];

    YDDeleteRequest *request = [[YDDeleteRequest alloc] initWithURL:url];
    [self prepareRequest:request];

    NSURL *requestURL = [request.URL copy];

    void (^successBlock)(NSURL *, NSUInteger) = ^(NSURL *URL, NSUInteger statusCode) {
        NSDictionary *userInfo = @{@"URL": URL,
                                   @"statusCode": @(statusCode)};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidRemoveNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block(nil);
    };

    void (^failBlock)(NSURL *, NSError *) = ^(NSURL *URL, NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"URL"] = url;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithRemoveRequestNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo]);
    };

    request.didFailBlock = ^(NSError *error) {
        failBlock(requestURL, error);
    };

    request.didReceiveResponseBlock = ^(NSURLResponse *response, BOOL *accept) {
        NSUInteger statusCode = [(NSHTTPURLResponse *)response statusCode];

        // Accept all 2xx codes and 404, except 207 – it will be processed in Multistatus response block
        if (statusCode/100 != 2 && statusCode != 404) {
            *accept = NO;
        }
        else if (statusCode != 207) {
            *accept = YES;
            successBlock(requestURL, statusCode);
        }
    };

    request.didReceiveMultistatusResponsesBlock = ^(NSArray *responses) {
        for (YDMultiStatusResponse *response in responses) {
            if (response.statusCode/100 == 2 && response.statusCode != 404) {
                successBlock(requestURL, response.statusCode);
            }
            else {
                failBlock(requestURL, nil);
            }
        }
    };

    [request start];

    NSDictionary *userInfo = @{@"URL": request.URL};
    [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidSendRemoveRequestNotification
                                                                       object:self
                                                                     userInfo:userInfo];
}

- (void)removeItemAtPath:(NSString *)path completion:(YDHandler)block
{
    [self removePath:path toTrash:NO completion:block];
}

- (void)trashItemAtPath:(NSString *)path completion:(YDHandler)block
{
    [self removePath:path toTrash:YES completion:block];
}

- (void)moveItemAtPath:(NSString *)path toPath:(NSString *)topath completion:(YDHandler)block
{
    NSURL *fromurl = [YDSession urlForDiskPath:path];
    if (!fromurl) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"movePath": path}]);
        return;
    }
    NSURL *tourl = [YDSession urlForDiskPath:topath];
    if (!tourl) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:1
                            userInfo:@{@"toPath": topath}]);
        return;
    }

    YDMOVERequest *request = [[YDMOVERequest alloc] initWithURL:fromurl];
    [self prepareRequest:request];

    request.destination = [tourl.path stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

    request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    NSDictionary *userInfo = @{@"from": fromurl,
                                 @"to": tourl};

    request.didFailBlock = ^(NSError *error) {
        NSMutableDictionary *errorInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
        [errorInfo addEntriesFromDictionary:@{@"error": error}];
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailToMoveNotification
                                                                           object:self
                                                                         userInfo:errorInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:errorInfo]);
    };

    request.didFinishLoadingBlock = ^(NSData *receivedData) {
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidMoveNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block(nil);
    };

    [request start];

    [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidSendMoveRequestNotification
                                                                       object:self
                                                                     userInfo:userInfo];
}

- (void)uploadFile:(NSString *)aFile toPath:(NSString *)aPath completion:(YDHandler)block
{
    NSURL *path = [YDSession urlForDiskPath:aPath];
    if (!path) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"putPath": aPath}]);
        return;
    }
    NSURL *file = [YDSession urlForLocalPath:aFile];
    if (!file) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:1
                            userInfo:@{@"fromFile": file}]);
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        YDFileUploadRequest *request = [[YDFileUploadRequest alloc] initWithURL:path];
        request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        request.OAuthToken = self.OAuthToken;
        request.localURL = file;
        request.uploadedDataSize = 0;
        request.timeoutInterval = 30;

        NSDictionary *userInfo = @{@"URL": request.URL};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidStartUploadFileNotification
                                                                           object:self
                                                                         userInfo:userInfo];

        request.didFinishLoadingBlock = ^(NSData *receivedData) {
            [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFinishUploadFileNotification
                                                                               object:self
                                                                             userInfo:userInfo];
            block(nil);
        };

        request.didSendBodyData = ^(UInt64 totalBytesWritten, UInt64 totalBytesExpectedToWrite) {
            NSDictionary *userInfo = @{@"URL": path,
                                       @"totalSent":@(totalBytesWritten),
                                       @"totalExpected":@(totalBytesExpectedToWrite)};
            [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidSendPartialDataForFileNotification
                                                                               object:self
                                                                             userInfo:userInfo];
        };

        request.didFailBlock = ^(NSError *error) {
            NSDictionary *userInfo = @{@"uploadPath": path,
                                         @"fromFile": file,
                                            @"error": error};
            [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailUploadFileNotification
                                                                               object:self
                                                                             userInfo:userInfo];
            block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo]);
        };

        [request start];
    });
}

- (void)downloadFileFromPath:(NSString *)path toFile:(NSString *)aFilePath completion:(YDHandler)block
{
    NSURL *url = [YDSession urlForDiskPath:path];
    if (!url) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"getPath": path}]);
        return;
    }
    NSURL *filePath = [YDSession urlForDiskPath:aFilePath];
    if (!filePath) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:1
                            userInfo:@{@"toFile": aFilePath}]);
        return;
    }

    YDDiskRequest *request = [[YDDiskRequest alloc] initWithURL:url];
    request.fileURL = filePath;
    [self prepareRequest:request];

    NSURL *requestURL = [request.URL copy];

    request.callbackQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    request.didReceiveResponseBlock = ^(NSURLResponse *response, BOOL *accept) { };

    request.didGetPartialDataBlock = ^(UInt64 receivedDataLength, UInt64 expectedDataLength) {
        NSDictionary *userInfo = @{@"URL": requestURL,
                                   @"receivedDataLength": @(receivedDataLength),
                                   @"expectedDataLength": @(expectedDataLength)};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidGetPartialDataForFileNotification
                                                                           object:self
                                                                         userInfo:userInfo];
    };

    request.didFinishLoadingBlock = ^(NSData *receivedData) {
        NSDictionary *userInfo = @{@"URL": requestURL,
                                   @"receivedDataLength": @(receivedData.length)};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidDownloadFileNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block(nil);
    };

    request.didFailBlock = ^(NSError *error) {
        NSDictionary *userInfo = @{@"URL": requestURL};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailToDownloadFileNotification
                                                                           object:self
                                                                         userInfo:userInfo];

        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo]);
    };

    [request start];

    NSDictionary *userInfo = @{@"URL": request.URL};
    [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidStartDownloadFileNotification
                                                                       object:self
                                                                     userInfo:userInfo];
}

- (void)publishItemAtPath:(NSString *)aPath completion:(YDPublishHandler)block
{
    NSURL *path = [YDSession urlForDiskPath:aPath];
    if (!path) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"publishPath": aPath}], nil);
        return;
    }

    NSString *pathUrl = path.absoluteString;
    pathUrl = [pathUrl stringByAppendingString:@"?publish"];
    NSURL *publishURL = [NSURL URLWithString:pathUrl];

    YDDiskPOSTRequest *request = [[YDDiskPOSTRequest alloc] initWithURL:publishURL];
    [self prepareRequest:request];
    request.timeoutInterval = 15;

    void (^successBlock)(NSURL *, NSURL *) = ^(NSURL *itemURL, NSURL *locationURL) {
        NSDictionary *userInfo = @{@"URL": itemURL,
                                   @"locationURL": locationURL};
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidPublishFileNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block(nil, locationURL);
    };

    void (^failBlock)(NSURL *, NSError *) = ^(NSURL *itemURL, NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"URL"] = itemURL;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithPublishRequestNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo], nil);
    };

    request.shouldRedirectBlock = ^NSURLRequest *(NSURLResponse *urlResponse, NSURLRequest *redirectURLRequest) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *) urlResponse;
        if (response.statusCode == 302) {
            NSString *publishURLStr = response.allHeaderFields[@"Location"];
            if (publishURLStr.length > 0) {
                successBlock(path, [NSURL URLWithString:publishURLStr]);
                return nil;
            }
        }

        return redirectURLRequest;
    };

    request.didReceiveResponseBlock = ^(NSURLResponse *urlResponse, BOOL *accept) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *) urlResponse;
        *accept = (response.statusCode == 302);
    };

    request.didFailBlock = ^(NSError *error) {
        failBlock(path, error);
    };
    
    [request start];
}

- (void)unpublishItemAtPath:(NSString *)aPath completion:(YDHandler)block
{
    NSURL *path = [YDSession urlForDiskPath:aPath];
    if (!path) {
        block([NSError errorWithDomain:kYDSessionBadArgumentErrorDomain
                                code:0
                            userInfo:@{@"unPublishPath": aPath}]);
        return;
    }

    NSString *pathUrl = path.absoluteString;
    pathUrl = [pathUrl stringByAppendingString:@"?unpublish"];
    NSURL *publishURL = [NSURL URLWithString:pathUrl];

    YDDiskPOSTRequest *request = [[YDDiskPOSTRequest alloc] initWithURL:publishURL];
    [self prepareRequest:request];
    request.timeoutInterval = 15;

    request.didReceiveResponseBlock = ^(NSURLResponse *urlResponse, BOOL *accept) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *) urlResponse;
        if (response.statusCode == 200) {
            NSDictionary *userInfo = @{@"path": path};
            [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidUnpublishFileNotification
                                                                               object:self
                                                                             userInfo:userInfo];
            block(nil);
            *accept = YES;
        }
        *accept = NO;
    };

    request.didFailBlock = ^(NSError *error) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"path"] = path;
        if (error) userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter] postNotificationInMainQueueWithName:kYDSessionDidFailWithUnpublishRequestNotification
                                                                           object:self
                                                                         userInfo:userInfo];
        block([NSError errorWithDomain:error.domain code:error.code userInfo:userInfo]);
    };

    [request start];
}

#pragma mark - Private

+ (NSURL *)urlForDiskPath:(NSString *)uri
{
    uri = [@"https://webdav.yandex.ru" stringByAppendingFormat:([uri hasPrefix:@"/"]?@"%@":@"/%@"), uri];
    uri = [uri stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

    return [NSURL URLWithString:uri];
}

+ (NSURL *)urlForLocalPath:(NSString *)uri
{
    NSURL *url = [NSURL URLWithString:uri];
    return url.isFileURL?url:nil;
}

- (void)prepareRequest:(YDDiskRequest *)request
{
    request.OAuthToken = self.OAuthToken;
    request.userAgent = self.delegate.userAgent;
}

@end

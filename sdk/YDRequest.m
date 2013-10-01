/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDRequest.h"
#import "YDConstants.h"

@interface YDRequest ()

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSFileHandle *uploadFileHandle;
@property (nonatomic, copy) NSURLRequest *lastRequest;
@property (nonatomic, strong) NSHTTPURLResponse *lastResponse;
@property (nonatomic, assign) BOOL isCanceled;
@property (nonatomic, assign) UInt64 receivedDataLength;
@property (nonatomic, strong) NSURLConnection *connection;

@end


@implementation YDRequest

@synthesize callbackQueue = _callbackQueue;

#pragma mark - Object lifecycle

- (instancetype)initWithURL:(NSURL *)theURL
{
    self = [super init];
    if (self != nil) {
        _URL = theURL;
    }
    return self;
}

- (NSString *)description
{
	NSMutableString *description = [[NSMutableString alloc] initWithString:super.description];
	[description appendFormat:@", URL: %@", self.URL];
	return description;
}

#pragma mark - Properties

- (dispatch_queue_t)callbackQueue
{
    @synchronized(self) {
        if (!_callbackQueue) {
            return dispatch_get_main_queue();
        }
        return _callbackQueue;
    }
}

- (void)setCallbackQueue:(dispatch_queue_t)newValue
{
    @synchronized(self) {
        _callbackQueue = newValue;
    }
}

#pragma mark - Public interface

- (void)start
{
	NSLog(@"%@ attempts to start", self);
	if (self.hasActiveConnection == YES) {
        NSLog(@"%@ failed to start because it is already running", self);
		return;
	}

    self.receivedDataLength = 0;
    self.isCanceled = NO;
    self.receivedData = nil;

	NSURLRequest *req = self.buildRequest;

	NSAssert1(req != nil, @"%@ failed to build HTTP request.", self);
	if (req == nil) {
        NSLog(@"%@ failed to build HTTP request.", self);
		return;
	}

    if ( req.HTTPBody.length > 0) {
        NSLog(@"BODY: %@", [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding]);
    }

	_connection = [[NSURLConnection alloc] initWithRequest:req
												 delegate:self
										 startImmediately:YES];
	if (_connection == nil) {
        NSLog(@"%@ failed to create request connection.", self);
		return;
	}
}

- (void)cancel
{
    _isCanceled = YES;

	NSLog(@"%@ cancel", self);

	[self closeConnection];

    [self removeFileIfExist];

    NSError *error = [NSError errorWithDomain:kYDSessionRequestErrorDomain
                                         code:YDRequestErrorCodeCanceled
                                     userInfo:nil];

    [self callDelegateWithError:error];
}

#pragma mark - NSURLConnection delegate callbacks

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (self.isCanceled) {
        [self cancel];
        return;
    }

    if (self.didSendBodyData!= nil) {
        dispatch_async(self.callbackQueue, ^{
            self.didSendBodyData(totalBytesWritten, totalBytesExpectedToWrite);
        });
    }
}

- (NSURLRequest *)connection:(NSURLConnection *)aConnection
			 willSendRequest:(NSURLRequest *)aRequest
			redirectResponse:(NSURLResponse *)aResponse
{
    if (self.isCanceled) {
        [self cancel];
        return nil;
    }

    self.lastResponse = (NSHTTPURLResponse *)aResponse;

    if (self.lastResponse != nil) {
        __block NSURLRequest *redirectRequest = [self buildRedirectRequestUsingDefault:aRequest];
        if (self.shouldRedirectBlock != nil) {
            dispatch_async(self.callbackQueue, ^{
                redirectRequest = self.shouldRedirectBlock(aResponse, aRequest);
            });
        }

        if (redirectRequest != nil) {
            self.lastRequest = redirectRequest;
        }

        return redirectRequest;
    }

    return aRequest;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
    NSLog(@"%@ did receive response %ld %@", self, (long)statusCode, [NSHTTPURLResponse localizedStringForStatusCode:statusCode]);

    if (self.isCanceled) {
        [self cancel];
        return;
    }

    self.lastResponse = (NSHTTPURLResponse *)response;

    // Call delegate callback

    // By default we accept all 2xx codes, but delegate can override this rule.
    __block BOOL responseAccepted = [self acceptResponseCode:self.lastResponse.statusCode];

    if (self.didReceiveResponseBlock != nil) {
        dispatch_async(self.callbackQueue, ^{
            self.didReceiveResponseBlock(self.lastResponse, &responseAccepted);
        });
    }

    if (responseAccepted == NO) {
        NSLog(@"%@: response has not been accepted. Closing connection", self);
        [self closeConnection];

        NSError *error = [NSError errorWithDomain:kYDSessionRequestErrorDomain
                                             code:YDRequestErrorCodeWrongResponseStatusCode
                                         userInfo:@{@"statusCode" : @(self.lastResponse.statusCode)}];

        [self callDelegateWithError:error];
    }
}

- (void)connection:(NSURLConnection *)aConnection didReceiveData:(NSData *)data
{
	NSLog(@"%@ did receive some data (%llu)", self, _receivedDataLength + data.length);

    if (self.isCanceled) {
        [self cancel];
        return;
    }

    UInt64 expectedContentLength = self.lastResponse.expectedContentLength;
    if (expectedContentLength == NSURLResponseUnknownLength) {
        expectedContentLength = 0;
    }

    if (self.fileURL != nil) {
        NSError *error = nil;
        // Delete file if exist
        if (self.receivedDataLength == 0 && [[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path] == YES)
            [[NSFileManager defaultManager] removeItemAtPath:self.fileURL.path error:&error];

        if (error == nil && [[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path] == NO) {
            NSURL *dirURL = self.fileURL.URLByDeletingLastPathComponent;
            [[NSFileManager defaultManager] createDirectoryAtPath:dirURL.path
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];

            if (error == nil) {
                [[NSFileManager defaultManager] createFileAtPath:_fileURL.path
                                                        contents:nil
                                                      attributes:nil];
                self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.fileURL.path];
            }
        }

        // Handle create/delete file errors
        if (error != nil) {
            [self closeConnection];
            [self removeFileIfExist];
            [self callDelegateWithError:error];
            return;
        }

        @try {
            [self.fileHandle seekToEndOfFile];
            [self.fileHandle writeData:data];
        }
        @catch (NSException *exception) {
            if ([exception.name isEqualToString:NSFileHandleOperationException]) {
                [self closeConnection];
                [self removeFileIfExist];
                NSError *error = [NSError errorWithDomain:kYDSessionRequestErrorDomain code:YDRequestErrorCodeFileIO userInfo:exception.userInfo];
                [self callDelegateWithError:error];
                return;
            }
            else {
                @throw exception;
            }
        }
    }
    else {
        if (self.receivedData == nil) {
            self.receivedData = [NSMutableData dataWithCapacity:expectedContentLength];
        }

        [self.receivedData appendData:data];
    }

    self.receivedDataLength += data.length;

    // Call delegate callback
    if (self.didGetPartialDataBlock != nil) {
        dispatch_async(self.callbackQueue, ^{
            self.didGetPartialDataBlock(self.receivedDataLength, expectedContentLength);
        });
    }
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error
{
	NSLog(@"%@ did fail with error:\n%@", self, error);

    [self closeConnection];

    [self removeFileIfExist];

    [self callDelegateWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
	NSLog(@"%@ did finish loading.", self);

	[self closeConnection];

    if (self.fileHandle != nil) {
        [self.fileHandle closeFile];
        NSLog(@"DATA stored at: %@", self.fileURL.path);
    }
    else if (self.receivedData.length > 0) {
        NSLog(@"DATA: %@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
    }

    // Call delegate callback
    if (self.didFinishLoadingBlock != nil) {
        dispatch_async(self.callbackQueue, ^{
            self.didFinishLoadingBlock(self.fileURL != nil ? nil : self.receivedData);
        });
    }

    [self processReceivedData];
}

#pragma mark - Private

- (BOOL)hasActiveConnection
{
	return (_connection != nil);
}

- (NSData *)buildHTTPBody
{
    // Can be overwritten by descendants.
    return nil;
}

- (void)prepareRequest:(NSMutableURLRequest *)request
{
    if (self.OAuthToken.length > 0) {
        NSString *OAuthHeaderField = [NSString stringWithFormat:@"OAuth %@", self.OAuthToken];
        [request setValue:OAuthHeaderField forHTTPHeaderField:@"Authorization"];
    }

    // We never use cookies for authorization!!!
    [request setHTTPShouldHandleCookies:NO];

    if (self.timeoutInterval > 0) {
        request.timeoutInterval = self.timeoutInterval;
    }
    else {
        request.timeoutInterval = 20; // default timeout interval
    }

    NSData *body = [self buildHTTPBody];
    if (body.length > 0) {
        request.HTTPBody = body;
    }
}

- (NSURLRequest *)buildRequest
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL];

    [self prepareRequest:request];

    return request;
}

- (NSURLRequest *)buildRedirectRequestUsingDefault:(NSURLRequest *)request
{
    NSMutableURLRequest *redirectRequest = [request mutableCopy];

    [self prepareRequest:redirectRequest];

    return redirectRequest;
}

- (BOOL)acceptResponseCode:(NSUInteger)statusCode
{
    // Can be overwritten by descendants.

    // Accept all 2xx codes
    return (statusCode/100 == 2);
}

- (void)processReceivedData
{
    // Should be overwritten by descendants (if it needs additional processing of received data)
    // For example, received data can be parsed here.
}

- (void)closeConnection
{
    if (_connection == nil) {
        return;
    }

    [_connection cancel];
    _connection = nil;
}

- (void)removeFileIfExist
{
    if (self.fileHandle != nil)
        [self.fileHandle closeFile];

    if (self.fileURL != nil && [[NSFileManager defaultManager] fileExistsAtPath:self.fileURL.path])
        [[NSFileManager defaultManager] removeItemAtPath:self.fileURL.path error:nil];
}

- (void)callDelegateWithError:(NSError *)error
{
    // Call delegate callback
    if (self.didFailBlock != nil) {
        dispatch_async(self.callbackQueue, ^{
            self.didFailBlock(error);
        });
    }
}

@end

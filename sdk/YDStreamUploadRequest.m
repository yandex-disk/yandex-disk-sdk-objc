/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDStreamUploadRequest.h"


@interface YDRequest ()

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error;
- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection;
- (void)cancel;

@end


@interface YDStreamUploadRequest ()

@property (nonatomic, strong) NSInputStream *consumer;
@property (nonatomic, strong) NSOutputStream *producer;
@property (nonatomic, assign) UInt64 dataOffset;
@property (nonatomic, assign) UInt64 bufferOffset;
@property (nonatomic, assign) UInt64 bufferActualSize;

@end


@implementation YDStreamUploadRequest

- (void)prepareRequest:(NSMutableURLRequest *)request
{
    [super prepareRequest:request];

    [self prepareStreams];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBodyStream:self.consumer];
    [request setValue:self.md5 forHTTPHeaderField: @"Etag"];
    [request setValue:self.sha256 forHTTPHeaderField: @"Sha256"];
    [request setValue:@"100-continue" forHTTPHeaderField: @"Expect"];
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error
{
    [self resetStreams];
    [super connection:aConnection didFailWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)aConnection
{
    [self resetStreams];
    [super connectionDidFinishLoading:aConnection];
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)request
{
    [self resetStreams];
    [self prepareStreams];

    return self.consumer;
}

- (void)cancel
{
    [self resetStreams];
    [super cancel];
}

#pragma mark - streams

- (void)prepareStreams
{
    [self createBoundedStreams];

    self.dataOffset = self.uploadedDataSize;
    self.producer.delegate = self;
    [self.producer scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.producer open];
}

- (void)resetProducerStream
{
    // We set our delegate callback to nil because we don't want to
    // be called anymore for this stream.  However, we can't
    // remove the stream from the runloop (doing so prevents the
    // URL from ever completing) and nor can we nil out our
    // stream reference (that causes all sorts of wacky crashes).
    // http://developer.apple.com/library/ios/#samplecode/SimpleURLConnections/Listings/PostController_m.html
    self.producer.delegate = nil;
    [self.producer close];
}

- (void)resetStreams
{
    self.producer.delegate = nil;
    [self.producer removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.producer close];
    self.producer = nil;

    self.consumer = nil;

    self.dataOffset = 0;
    self.bufferOffset = 0;
    self.bufferActualSize = 0;
}

- (void)createBoundedStreams
{
    CFReadStreamRef readStream = nil;
    CFWriteStreamRef writeStream = nil;

    CFStreamCreateBoundPair(kCFAllocatorDefault, &readStream, &writeStream, BUFFER_SIZE);

    self.consumer = CFBridgingRelease(readStream);
    self.producer = CFBridgingRelease(writeStream);
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            // stream opened;
            break;

        case NSStreamEventHasBytesAvailable:
            NSAssert(NO, @"YDStreamUploadRequest NSStreamEventHasBytesAvailable - should never happen");
            break;

        case NSStreamEventHasSpaceAvailable:
            [self handleStreamEventHasSpaceAvailable];
            break;

        case NSStreamEventErrorOccurred:
            [self cancel];
            break;

        case NSStreamEventEndEncountered:   // Consumer stream have been closed
            [self resetProducerStream];
            break;

        default:
            NSAssert(NO, @"YDStreamUploadRequest default - should never happen");
            break;
    }
}

- (void)handleStreamEventHasSpaceAvailable
{
    
}

@end

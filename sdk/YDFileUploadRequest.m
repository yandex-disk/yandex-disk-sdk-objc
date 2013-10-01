/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDFileUploadRequest.h"


@interface YDStreamUploadRequest ()

@property (nonatomic, strong) NSInputStream *consumer;
@property (nonatomic, strong) NSOutputStream *producer;
@property (nonatomic, assign) UInt64 dataOffset;
@property (nonatomic, assign) UInt64 bufferOffset;
@property (nonatomic, assign) UInt64 bufferActualSize;

@end


@interface YDFileUploadRequest ()

@property (nonatomic, assign) UInt64 fileSize;
@property (nonatomic, strong) NSFileHandle *uploadingFile;

@end


@implementation YDFileUploadRequest

- (void)prepareRequest:(NSMutableURLRequest *)request
{
    [super prepareRequest:request];

    if (self.uploadedDataSize > 0) {
        [request setValue:[NSString stringWithFormat:@"bytes %lld-%lld/%lld", self.uploadedDataSize, self.fileSize-1, self.fileSize]
       forHTTPHeaderField:@"Content-Range"];
    }
    else {
        [request setValue:[NSString stringWithFormat:@"%lld", self.fileSize]
       forHTTPHeaderField:@"Content-Length"];
    }
}

- (BOOL)acceptResponseCode:(NSUInteger)statusCode
{
    return statusCode == 201 || statusCode == 409;
}

- (void)prepareStreams
{
    [super prepareStreams];

    self.fileSize = [[NSFileManager.defaultManager attributesOfItemAtPath:self.localURL.path error:nil] fileSize];
    self.uploadingFile = [NSFileHandle fileHandleForReadingAtPath:self.localURL.path];
    [self.uploadingFile seekToFileOffset:self.uploadedDataSize];
}

- (void)resetStreams
{
    [super resetStreams];
    [self.uploadingFile closeFile];
}

- (void)handleStreamEventHasSpaceAvailable
{
    if (self.bufferOffset == self.bufferActualSize) {
        if (self.dataOffset == self.fileSize) {
            // All data read and sent to server
            [self resetProducerStream];
            return;
        }

        // Read more data
        self.bufferOffset = 0;
        NSData *data = [self.uploadingFile readDataOfLength:BUFFER_SIZE];
        self.bufferActualSize = data.length;

        memcpy(buffer_, data.bytes, (unsigned long)self.bufferActualSize);

        self.dataOffset += self.bufferActualSize;
    }

    // Write data to stream
    NSInteger bytesWritten = [self.producer write:&buffer_[self.bufferOffset]
                                        maxLength:self.bufferActualSize - self.bufferOffset];

    if (bytesWritten == -1) {   // Stream error
        [self resetProducerStream];
    }
    else {
        self.bufferOffset += bytesWritten;
    }
}

@end

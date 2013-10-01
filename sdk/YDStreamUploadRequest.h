/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDDiskRequest.h"


#define BUFFER_SIZE 1024*10


@interface YDStreamUploadRequest : YDDiskRequest<NSStreamDelegate>
{
    uint8_t buffer_[BUFFER_SIZE];
}

@property (nonatomic, copy) NSString *md5;
@property (nonatomic, copy) NSString *sha256;
@property (nonatomic, assign) UInt64 uploadedDataSize;

// Handle stream event. Can be be overwritten by descendants.
- (void)handleStreamEventHasSpaceAvailable;
- (void)prepareStreams;
- (void)resetStreams;
- (void)resetProducerStream;

@end

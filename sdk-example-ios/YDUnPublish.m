/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDUnPublish.h"
#import "YDSession.h"

@interface YDUnPublish ()

@property(strong, nonatomic) NSMutableArray * files;

@end


@implementation YDUnPublish

- (UIImage *)activityImage
{
    static UIImage *image = nil;
    if (!image) image = [UIImage imageNamed:@"Share_icon"];
    return image;
}

- (NSString *)activityTitle
{
    return @"Unpublish";
}

- (NSString *)activityType
{
    return @"ru.ya.disk-sdk-example-ios.unpublish";
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for (id element in activityItems) {
        if ([[element class] isSubclassOfClass:NSClassFromString(@"YDItemStat")]) {
            YDItemStat * item = element;
            if (item.publicURL) return YES;
        }
    }
    return NO;
}

- (void)performActivity
{
    for (YDItemStat *item in self.files) {
        [item.session  unpublishItemAtPath:item.path
                                completion:^(NSError *err) {
                                    if (!err) {
                                        [item setValue:nil forKey:@"publicURL"];
                                        [self activityDidFinish:YES];
                                    }
                                    else {
                                        [self activityDidFinish:NO];
                                    }
                                }];
    }
    [self activityDidFinish:YES];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    self.files = [[NSMutableArray alloc] init];
    for (id element in activityItems) {
        if ([[element class] isSubclassOfClass:NSClassFromString(@"YDItemStat")])
            [self.files addObject:element];
    }
}

@end

/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDDelete.h"
#import "YDSession.h"

@interface YDDelete ()

@property(strong, nonatomic) NSMutableArray * files;

@end


@implementation YDDelete

- (UIImage *)activityImage
{
    static UIImage *image = nil;
    if (!image) image = [UIImage imageNamed:@"Delete_icon"];
    return image;
}

- (NSString *)activityTitle
{
    return @"Delete";
}

- (NSString *)activityType
{
    return @"ru.ya.disk-sdk-example-ios.delete";
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for (id element in activityItems) {
        if ([[element class] isSubclassOfClass:NSClassFromString(@"YDItemStat")])
            return YES;
    }
    return NO;
}

- (void)performActivity
{
    for (YDItemStat *item in self.files) {
        [item.session removeItemAtPath:item.path
                            completion:^(NSError *err) {
                                if (!err) {
                                    [self activityDidFinish:YES];
                                }
                                else {
                                    [self activityDidFinish:NO];
                                }
                            }];
    }
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
    self.files = [[NSMutableArray alloc] init];
    for (id element in activityItems) {
        if ([[element class] isSubclassOfClass:NSClassFromString(@"YDItemStat")])
            [self.files addObject:element];
    }
}

@end

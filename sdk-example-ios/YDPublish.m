/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "YDPublish.h"
#import "YDSession.h"

@interface YDPublish ()

@property(strong, nonatomic) NSMutableArray * files;

@end


@implementation YDPublish

- (UIImage *)activityImage
{
    static UIImage *image = nil;
    if (!image) image = [UIImage imageNamed:@"Share_icon"];
    return image;
}

- (NSString *)activityTitle
{
    return @"Publish";
}

- (NSString *)activityType
{
    return @"ru.ya.disk-sdk-example-ios.publish";
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for (id element in activityItems) {
        if ([[element class] isSubclassOfClass:NSClassFromString(@"YDItemStat")]) {
            YDItemStat *item = element;
            if (!item.publicURL) return YES;
        }
    }
    return NO;
}

- (void)performActivity
{
    for (YDItemStat *item in self.files) {
        [item.session  publishItemAtPath:item.path
                              completion:^(NSError *err, NSURL *url) {
                                  if (!err) {
                                      [item setValue:url forKey:@"publicURL"];
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

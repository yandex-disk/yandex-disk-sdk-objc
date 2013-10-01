/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import <UIKit/UIKit.h>

@interface YDDelete : UIActivity

- (UIImage *)activityImage;
- (NSString *)activityTitle;
- (NSString *)activityType;
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems;
- (void)performActivity;
- (void)prepareWithActivityItems:(NSArray *)activityItems;

@end

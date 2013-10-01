/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import <UIKit/UIKit.h>
#import "YDSession.h"

@interface DirectoryViewController : UITableViewController

@property(nonatomic, copy) NSString *path;
@property(nonatomic, copy) NSArray *entries;
@property(nonatomic, strong) YDSession *session;

- (instancetype)initWithSession:(YDSession *)session path:(NSString *)path;

@end

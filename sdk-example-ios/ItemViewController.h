/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import <UIKit/UIKit.h>
#import "YDSession.h"
#import "ItemViewDelegate.h"

@interface ItemViewController : UITableViewController

@property(nonatomic, weak) id<ItemViewDelegate> delegate;
@property(nonatomic, strong) YDItemStat *item;

- (instancetype)initWithItem:(YDItemStat *)stat;

@end

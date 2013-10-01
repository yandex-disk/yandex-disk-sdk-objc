/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import <Cocoa/Cocoa.h>
#import <Disk-SDK/YDSession.h>


@interface AppDelegate : NSObject

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *pathField;
@property (assign) IBOutlet NSTableView *table;

@property (retain) IBOutlet YDSession *disk;

@property (copy) NSArray *items;

- (IBAction)onList:(id)sender;
- (IBAction)onMKCol:(id)sender;
- (IBAction)onRemove:(id)sender;
- (IBAction)onGet:(id)sender;
- (IBAction)onPut:(id)sender;
- (IBAction)onParentPath:(id)sender;
- (IBAction)onPublish:(id)sender;
- (IBAction)onUnPublish:(id)sender;
- (IBAction)onMove:(id)sender;
- (IBAction)onUnlock:(id)sender;

@end

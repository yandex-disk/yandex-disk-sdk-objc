/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */

#import "AppDelegate.h"
#import <Disk-SDK/YOAuth2Delegate.h>
#import <Disk-SDK/YOAuth2WindowController.h>

#error Replace the following with the data you got when registering your app at: https://oauth.yandex.ru/
NSString * kClientID = @"00112233445566778899aabbccddeeff";

#warning Replace the following with the data you got when registering your app at: https://oauth.yandex.ru/
NSString * kRedirectURI = @"http://sdk-example.auth";

@interface AppDelegate () <NSApplicationDelegate, YDSessionDelegate, YOAuth2Delegate,
                           NSTableViewDataSource, NSTableViewDelegate,
                           NSTextFieldDelegate>

@property (nonatomic, strong) YOAuth2WindowController * authWindow;

@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.disk = [[YDSession alloc] init];
    self.pathField.delegate = self;
    [self onUnlock:self];
}

- (NSString *)clientID { return kClientID; }
- (NSString *)userAgent { return @"disk-sdk-example-osx"; }
- (NSString *)redirectURL { return kRedirectURI; }

- (IBAction)onList:(id)sender
{
    NSString * path = self.pathField.stringValue;

    void (^onSuccess)(NSArray *items) = ^(NSArray *items){
         self.items = items;

        dispatch_async(dispatch_get_main_queue(), ^{
         [self.table deselectAll:self];
         [self.table reloadData];
        });
    };

    [self.disk fetchDirectoryContentsAtPath:path
                                 completion:^(NSError *error, NSArray *items) {
                                     if (!error) {
                                         onSuccess(items);
                                     }
     }];
}

- (IBAction)onMKCol:(id)sender
{
    [self.disk createDirectoryAtPath:self.pathField.stringValue
                          completion:^(NSError *err) {
                              if (!err)
                                  [self onParentPath:self];
                          }];
}

- (IBAction)onRemove:(id)sender
{
    [self.disk removeItemAtPath:self.pathField.stringValue
                     completion:^(NSError *err) {
                         if (!err)
                             [self onParentPath:self];
                     }];
}

- (IBAction)onTrash:(id)sender
{
    [self.disk trashItemAtPath:self.pathField.stringValue
                    completion:^(NSError *err) {
                         if (!err)
                             [self onParentPath:self];
                     }];
}

- (IBAction)onGet:(id)sender
{
    NSArray * downloadDir = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES);
    NSString *file = self.pathField.stringValue;
    NSString *tofile = [downloadDir[0] stringByAppendingPathComponent:[file lastPathComponent]];

    [self.disk downloadFileFromPath:file
                             toFile:tofile
                         completion:^(NSError *err) {
                             if (!err) {
                                 NSRunInformationalAlertPanel(@"Download Succeeded", @"Downloaded '%@'\nto '%@'", @"OK", nil, nil, [file lastPathComponent], [tofile stringByDeletingLastPathComponent]);
                             }
                             else {
                                 NSRunInformationalAlertPanel(@"Download Failed", @"Download of '%@'\nto '%@'\n\tFAILED.", @"OK", nil, nil, [file lastPathComponent], [tofile stringByDeletingLastPathComponent]);
                             }
                         }];
}

- (IBAction)onParentPath:(id)sender
{
    self.pathField.stringValue = [self.pathField.stringValue stringByDeletingLastPathComponent];
    [self onList:self];
}

- (IBAction)onPublish:(id)sender
{
    NSString * path = self.pathField.stringValue;
    [self.disk publishItemAtPath:path
                      completion:^(NSError *err, NSURL *url) {
                          self.pathField.stringValue = [path stringByDeletingLastPathComponent];
                          [self onList:self];
                      }];
}

- (IBAction)onUnPublish:(id)sender
{
    NSString * path = self.pathField.stringValue;
    [self.disk unpublishItemAtPath:path
                        completion:^(NSError *err) {
                            self.pathField.stringValue = [path stringByDeletingLastPathComponent];
                            [self onList:self];
                        }];
}

- (IBAction)onMove:(id)sender
{
    [self.disk moveItemAtPath:self.pathField.stringValue
                       toPath:[@"/" stringByAppendingString:[self.pathField.stringValue lastPathComponent]]
                   completion:^(NSError *err) {
                       if (err) {
                           NSRunInformationalAlertPanel(@"Something went wrong!", @"%@", @"Damn!", nil, nil, [err description]);
                       }
                       else {
                           [self onParentPath:self];
                       }
                   }];
}

- (IBAction)onUnlock:(id)sender
{
    if (!self.disk) self.disk = [[YDSession alloc] initWithDelegate:self];

    self.authWindow = [[YOAuth2WindowController alloc] init];
    self.authWindow.delegate = self;

    [self.authWindow showWindow:self];
}

- (IBAction)onPut:(id)sender
{
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];
    openDlg.canChooseFiles = YES;
    openDlg.canChooseDirectories = NO;
    openDlg.allowsMultipleSelection = NO;

    [openDlg beginSheetModalForWindow:self.window
                    completionHandler:^(NSInteger returnCode) {
          if (returnCode == NSOKButton) {
        NSString * file = ((NSURL*)openDlg.URLs[0]).absoluteString;
              NSString * tofile = [@"/" stringByAppendingPathComponent:[file lastPathComponent]];
        [self.disk uploadFile:file
                       toPath:tofile
                   completion:^(NSError *err) {
                       if (!err) {
                           NSRunInformationalAlertPanel(@"Upload Succeeded", @"Uploaded '%@'\nto '%@'", @"OK", nil, nil, [file lastPathComponent], [tofile stringByDeletingLastPathComponent]);
                           [self onList:self];
                             }
                             else {
                           NSRunInformationalAlertPanel(@"Upload Failed", @"Upload of '%@'\nto '%@'\n\tFAILED.", @"OK", nil, nil, [file lastPathComponent], [tofile stringByDeletingLastPathComponent]);
                       }
                   }];
    }
      }];
}

#pragma mark - YOAuth2Delegate

- (void)OAuthLoginSucceededWithToken:(NSString *)token
{
    self.disk.OAuthToken = token;
    self.authWindow = nil;
    [self onList:self];
}

- (void)OAuthLoginFailedWithError:(NSError *)error
{
    self.authWindow = nil;
    NSLog(@"It's time to panic! %@", error);
}


#pragma mark - TABLE-VIEW DATASOURCE

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.items.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    });

    NSArray *items = self.items;
    YDItemStat *item = items[row];

    id value = nil;

    if (items) {
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            value = item.name;
        }
        else if ([[tableColumn identifier] isEqualToString:@"size"]) {
            value = (item.size >0) ? [NSString stringWithFormat:@"%lld bytes", item.size] : @"-";
        }
        else if ([[tableColumn identifier] isEqualToString:@"date"]) {
            value = [dateFormatter stringFromDate:item.mTime];
        }
        else if ([[tableColumn identifier] isEqualToString:@"type"]) {
            value = item.isDirectory ? @"directory" : item.mimeType;
        }
        else if ([[tableColumn identifier] isEqualToString:@"public"]) {
            value = item.publicURL.absoluteString;
        }
    }

    return value;
}


#pragma mark - TABLE-VIEW DELEGATE

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row
{
    NSArray *items = self.items;
    YDItemStat *item = items[row];

    self.pathField.stringValue = item.path;

    return (item)?YES:NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    [self onList:self];
    return NO;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if (commandSelector == @selector(insertNewline:)) {
        [self onList:self];
    }
    return NO;
}

@end

/* Лицензионное соглашение на использование набора средств разработки
 * «SDK Яндекс.Диска» доступно по адресу: http://legal.yandex.ru/sdk_agreement
 */


#import "ItemViewController.h"
#import "YDDelete.h"
#import "YDPublish.h"
#import "YDUnPublish.h"


@implementation ItemViewController

- (instancetype)initWithItem:(YDItemStat *)stat
{
	if (self = [super init]) {
        _item = stat;
		super.title = self.item.name;

        super.tableView.dataSource = self;
        super.tableView.delegate = self;
	}
	return self;
}

- (void)action:(id)sender
{
    UIActivityViewController *activityView = nil;

    NSArray *appActivities = @[[[YDDelete alloc] init],
                               [[YDPublish alloc] init],
                               [[YDUnPublish alloc] init]];

    NSArray *activityItems = (self.item.publicURL)
                                ? @[self.item, self.item.name, self.item.publicURL]
                                : @[self.item, self.item.name];

    activityView = [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                                     applicationActivities:appActivities];

    activityView.completionHandler = ^(NSString *activityType, BOOL completed) {
        if (completed) {
            if ([activityType isEqualToString:@"ru.yandex.disk.delete"]) {
                [self.delegate itemsChanged:self];
                [self.navigationController popViewControllerAnimated:YES];
            } else if ([activityType isEqualToString:@"ru.yandex.disk.publish"] ||
                       [activityType isEqualToString:@"ru.yandex.disk.unpublish"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadData];
                });
            }
        }
    };

    [self presentViewController:activityView animated:YES completion:nil];
}

#pragma mark - UIViewController methods

- (void)viewDidLoad
{
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                                           target:self
                                                                                           action:@selector(action:)];
}

#pragma mark - UITableView methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 7;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    static NSString *cellIdentifier = @"Cell";

    cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }

    switch (indexPath.row) {
        case 0: {
            cell.textLabel.text = @"Name";
            cell.detailTextLabel.text = self.item.name;
        } break;
        case 1: {
            cell.textLabel.text = @"Type";
            cell.detailTextLabel.text = self.item.isDirectory?@"directory":self.item.mimeType;
        } break;
        case 2: {
            cell.textLabel.text = @"Size";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%llu bytes", self.item.size];
        } break;
        case 3: {
            cell.textLabel.text = @"Permission";
            cell.detailTextLabel.text = self.item.isReadOnly?@"readonly":@"readwrite";
        } break;
        case 4: {
            cell.textLabel.text = @"M-Time";
            cell.detailTextLabel.text = self.item.mTime.description;
        } break;
        case 5: {
            cell.textLabel.text = @"Shared";
            cell.detailTextLabel.text = self.item.isShare?@"YES":@"NO";
        } break;
        case 6: {
            cell.textLabel.text = @"Public URL";
            cell.detailTextLabel.text = [self.item.publicURL absoluteString];
        } break;
        default:
            break;
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

@end

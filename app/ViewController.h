#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface ViewController : UIViewController <WKNavigationDelegate, WKUIDelegate>
@property (strong, nonatomic) WKWebView *webView;
@end
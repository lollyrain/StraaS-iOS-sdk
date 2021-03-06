//
//  STSCircallMainViewController.m
//  StraaSDemoApp
//
//  Created by Allen and Kim on 2018/5/2.
//  Copyright © 2018 StraaS.io. All rights reserved.
//

#import "STSCircallMainViewController.h"
#import "STSCircallSingleVideoCallViewController.h"
#import "STSQRCodeScannerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface STSCircallMainViewController () <UITextFieldDelegate, STSQRCodeScannerViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *backgroundView;
@property (weak, nonatomic) IBOutlet UIButton *connectRoomButton;
@property (weak, nonatomic) IBOutlet UITextField *streamKeyTextField;
@property (weak, nonatomic) IBOutlet UILabel *errorMessageLabel;

@end

@implementation STSCircallMainViewController

+ (instancetype)viewControllerFromStoryboard {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    STSCircallMainViewController * vc =
    [storyboard instantiateViewControllerWithIdentifier:@"STSCircallMainViewController"];
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.streamKeyTextField.delegate = self;
    
    [self makeBackgroundColorGradient];
    
    self.connectRoomButton.layer.cornerRadius = 5.0;
    
    self.streamKeyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    UIColor *color = [UIColor colorWithRed:120./255. green:193./255. blue:196./255. alpha:1];
    self.streamKeyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"請貼上串流碼" attributes:@{NSForegroundColorAttributeName: color}];
}

#pragma mark - Accessors

#pragma mark - IBAction

- (IBAction)connectRoomButtonDidPressed:(id)sender {
    self.errorMessageLabel.hidden = YES;

    if (![[self class] isCircallTokenValid:self.streamKeyTextField.text]) {
        self.errorMessageLabel.text = @"串流碼錯誤";
        self.errorMessageLabel.hidden = NO;
        return;
    }
    
    [self requestCameraAndMicrophonePermissionsWithSuccessHandler:^{
        STSCircallSingleVideoCallViewController *vc = [STSCircallSingleVideoCallViewController viewControllerFromStoryboard];
        dispatch_async(dispatch_get_main_queue(), ^{
            vc.streamKey = self.streamKeyTextField.text;
            [self.navigationController pushViewController:vc animated:YES];
        });
    }];
}

- (IBAction)scanQRCodeButtonDidPress:(id)sender {
    [self requestCameraAndMicrophonePermissionsWithSuccessHandler:^{
        STSQRCodeScannerViewController *vc = [STSQRCodeScannerViewController new];
        vc.delegate = self;
        [self presentViewController:vc animated:YES completion:nil];
    }];
}

#pragma mark - Private Methods

- (void)makeBackgroundColorGradient {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);
    
    struct CGColor *circallLightGreenColor = [[UIColor colorWithRed:2./255. green:113./255. blue:117./255. alpha:1] CGColor];
    struct CGColor *circallDarkGreenColor = [[UIColor colorWithRed:81./255. green:192./255. blue:194./255. alpha:1] CGColor];
    gradient.colors = [NSArray arrayWithObjects:(__bridge id)circallDarkGreenColor, (__bridge id)circallLightGreenColor, nil];
    [self.backgroundView.layer addSublayer:gradient];
}

- (void)requestCameraAndMicrophonePermissionsWithSuccessHandler:(void (^)())successHandler {
    self.errorMessageLabel.text = @"";
    self.errorMessageLabel.hidden = YES;
    
    __weak STSCircallMainViewController * weakSelf = self;
    
    void (^requestAccessFailureHandler)(NSString *errorMessage) = ^(NSString *errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.errorMessageLabel.text = errorMessage;
            weakSelf.errorMessageLabel.hidden = NO;
        });
    };
    
    void (^audioAccessHandler)(BOOL) = ^(BOOL granted) {
        if (!granted) {
            requestAccessFailureHandler(@"麥克風授權失敗，請至設定頁重新開啟。");
            return;
        }
        successHandler();
    };
    void (^videoAccessHandler)(BOOL) = ^(BOOL granted) {
        if (!granted) {
            requestAccessFailureHandler(@"攝影機授權失敗，請至設定頁重新開啟。");
            return;
        }
        [weakSelf requestAccessForAudioWithCompletionHandler:audioAccessHandler];
    };
    
    [self requestAccessForVideoWithCompletionHandler:videoAccessHandler];
}

- (void)requestAccessForVideoWithCompletionHandler:(void (^)(BOOL granted))handler {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:handler];
            break;
        }
        case AVAuthorizationStatusAuthorized: {
            handler(YES);
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            handler(NO);
            break;
    }
}

- (void)requestAccessForAudioWithCompletionHandler:(void (^)(BOOL granted))handler {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (status) {
        case AVAuthorizationStatusNotDetermined: {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:handler];
            break;
        }
        case AVAuthorizationStatusAuthorized: {
            handler(YES);
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
        default:
            handler(NO);
            break;
    }
}

+ (BOOL)isCircallTokenValid:(NSString *)circallToken {
    if (circallToken == nil || circallToken.length == 0) {
        return false;
    }
    
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:circallToken options:0];
    
    if (decodedData == nil) {
        return NO;
    }

    NSError *error = nil;
    NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:decodedData options:0 error:&error];
    if (error != nil) {
        return NO;
    } else if (jsonObject == nil || jsonObject[@"host"] == nil) {
        return NO;
    }
    
    return YES;
}

#pragma mark - UITextfieldDelegate Methods

-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - STSQRCodeScannerViewControllerDelegate

- (void)scanner:(STSQRCodeScannerViewController *)scanner didGetQRCode:(NSString *)qrCode {
    self.streamKeyTextField.text = qrCode;
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

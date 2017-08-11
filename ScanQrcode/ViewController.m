//
//  ViewController.m
//  ScanQrcode
//
//  Created by bjovov on 2017/8/8.
//  Copyright © 2017年 ovov.cn. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ScanBackGroundView.h"
#import "Helper.h"

#define kScreen_Bounds [UIScreen mainScreen].bounds
#define kScreen_Height [UIScreen mainScreen].bounds.size.height
#define kScreen_Width [UIScreen mainScreen].bounds.size.width
@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic,strong) AVCaptureSession *captureSession;//协调输入输出设备以获得数据
@property (nonatomic,strong) AVCaptureDevice *captureDevice;//代表了物理捕获设备如:摄像机
@property (nonatomic,strong) AVCaptureDeviceInput *deviceInput; //可以作为输入捕获会话
@property (nonatomic,strong) AVCaptureMetadataOutput *captureMetadataOutPut;//处理输出捕获会话，需要指定他的输出类型及扫描范围
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *previewLayer;//显示捕获到的相机输出流
@property (nonatomic,strong) UILabel *tipLabel;
@property (nonatomic,strong) UIImageView *scanRectView;
@property (nonatomic,strong) UIImageView *lineView;
@property (nonatomic,strong) ScanBackGroundView *scanBackGroundView;
@property (nonatomic,strong) CIDetector *detector;
@property (nonatomic,strong) UIButton *switchButton;
@property (nonatomic,assign) BOOL isSelectflashbulb;
@end

@implementation ViewController
#pragma mark - LifeCycle Menthod
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"二维码";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"相册" style:UIBarButtonItemStylePlain target:self action:@selector(clickRightBarButton)];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(applicationDidBecomeActive:)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(applicationWillResignActive:)
               name:UIApplicationWillResignActiveNotification
             object:nil];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (!_previewLayer) {
        [self configUI];
    }else{
        [self startScan];
    }
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [self stopScan];
}

- (void)configUI{
    CGFloat width = kScreen_Width *2/3;
    CGFloat padding = (kScreen_Width - width)/2;
    CGRect scanRect = CGRectMake(padding, (kScreen_Height - width)/2 - 50, width, width);
    
    if (!_previewLayer) {
        NSError *error;
        _captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        _deviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:_captureDevice error:&error];
        _captureSession = [[AVCaptureSession alloc]init];
        //设置会话的输入设备
        [_captureSession addInput:_deviceInput];
        
        //设置对应输出
        _captureMetadataOutPut = [[AVCaptureMetadataOutput alloc]init];
        [_captureMetadataOutPut setMetadataObjectsDelegate:self queue:dispatch_queue_create("ease_capture_queue",NULL)];
        [_captureSession addOutput:_captureMetadataOutPut];
        _captureMetadataOutPut.rectOfInterest = CGRectMake(CGRectGetMinY(scanRect)/CGRectGetHeight(self.view.frame),
                                                           CGRectGetMinX(scanRect)/CGRectGetWidth(self.view.frame),
                                                           CGRectGetHeight(scanRect)/CGRectGetHeight(self.view.frame),
                                                           CGRectGetWidth(scanRect)/CGRectGetWidth(self.view.frame));
        [_captureMetadataOutPut setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
        
        
        //将捕获的数据流展现出来
        _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        [_previewLayer setFrame:self.view.bounds];
    }
    
    if (!_scanBackGroundView) {
        _scanBackGroundView = [[ScanBackGroundView alloc]initWithFrame:self.view.bounds];
        _scanBackGroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
        _scanBackGroundView.scanRect = scanRect;
    }
    
    if (!_scanRectView) {
        _scanRectView = [[UIImageView alloc] initWithFrame:scanRect];
        _scanRectView.image = [UIImage imageNamed:@"扫描边框"];
        _scanRectView.clipsToBounds = YES;
    }
    
    if (!_tipLabel) {
        _tipLabel = [UILabel new];
        _tipLabel.textAlignment = NSTextAlignmentCenter;
        _tipLabel.font = [UIFont boldSystemFontOfSize:14];
        _tipLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
        _tipLabel.text = @"将二维码放入框内，即可自动扫描";
        _tipLabel.frame = CGRectMake(0, CGRectGetMaxY(scanRect),CGRectGetWidth(self.view.bounds),40);
    }
    
    if (!_lineView) {
         CGFloat lineHeight = 2;
        _lineView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"scan_line"]];
        _lineView.contentMode = UIViewContentModeScaleToFill;
        _lineView.frame = CGRectMake(0, 0, CGRectGetWidth(_scanRectView.frame), lineHeight);
    }
    
    [self.view.layer addSublayer:_previewLayer];
    [self.view addSubview:_scanBackGroundView];
    [self.view addSubview:_scanRectView];
    [self.view addSubview:_tipLabel];
    [self.view addSubview:self.switchButton];
    [_scanRectView addSubview:_lineView];
    self.switchButton.frame = CGRectMake(CGRectGetWidth(self.view.frame)/2-80/2, CGRectGetMaxY(_tipLabel.frame) + 30, 80, 80);
    
    [self startScan];
}

#pragma mark - Event Response
-(void)clickRightBarButton{
    if (![Helper checkPhotoLibraryAuthorizationStatus]) {
        return;
    }
    //停止扫描
    [self stopScan];
    
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self.navigationController presentViewController:picker animated:YES completion:nil];
}

- (void)switchButtonClicked{
    //修改前必须先锁定
    _isSelectflashbulb  = !_isSelectflashbulb;
    [self.captureDevice lockForConfiguration:nil];
    //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if ([self.captureDevice hasFlash]) {
        if (!_isSelectflashbulb) {
            [self.captureDevice setTorchMode:AVCaptureTorchModeOn];
            [self.switchButton setBackgroundImage:[UIImage imageNamed:@"zxing_scan_flashlight_on"] forState:UIControlStateNormal];
        }else{
            [self.captureDevice setTorchMode: AVCaptureTorchModeOff];
            [self.switchButton setBackgroundImage:[UIImage imageNamed:@"zxing_scan_flashlight_off"] forState:UIControlStateNormal];
        }
    } else {
        NSLog(@"设备不支持闪光灯");
    }
    [self.captureDevice unlockForConfiguration];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [picker dismissViewControllerAnimated:YES completion:^{
        [self handleImageInfo:info];
    }];
}

- (void)handleImageInfo:(NSDictionary *)info{
    //停止扫描
    [self stopScan];
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
    if (!image){
        image = [info objectForKey:UIImagePickerControllerOriginalImage];
    }
    __block NSString *resultStr = nil;
    NSArray *features = [self.detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    [features enumerateObjectsUsingBlock:^(CIQRCodeFeature *obj, NSUInteger idx, BOOL *stop) {
        if (obj.messageString.length > 0) {
            resultStr = obj.messageString;
            *stop = YES;
        }
    }];
    //震动反馈
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"提示" message:resultStr preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:controller animated:YES completion:NULL];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Notification
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self startScan];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [self stopScan];
}

#pragma mark - Public Menthod
- (BOOL)isScaning{
    return self.previewLayer.session.isRunning;
}

- (void)startScan{
    [self.previewLayer.session startRunning];
    [self scanLineStartAction];
}

- (void)stopScan{
    [self.previewLayer.session stopRunning];
    [self scanLineStopAction];
}

#pragma mark - private menthod
- (void)scanLineStartAction{
    [self scanLineStopAction];
    
    CABasicAnimation *scanAnimation = [CABasicAnimation animationWithKeyPath:@"position.y"];
    scanAnimation.fromValue = @(0);
    scanAnimation.toValue = @(CGRectGetHeight(_scanRectView.frame));
    scanAnimation.repeatCount = CGFLOAT_MAX;
    scanAnimation.duration = 1.7;
    scanAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    [self.lineView.layer addAnimation:scanAnimation forKey:@"scan"];
}

- (void)scanLineStopAction{
    [self.lineView.layer removeAnimationForKey:@"scan"];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    //判断是否有数据，是否是二维码数据
    if (metadataObjects.count > 0) {
        __block AVMetadataMachineReadableCodeObject *result = nil;
        [metadataObjects enumerateObjectsUsingBlock:^(AVMetadataMachineReadableCodeObject *obj, NSUInteger idx, BOOL *stop) {
            if ([obj.type isEqualToString:AVMetadataObjectTypeQRCode]) {
                result = obj;
                *stop = YES;
            }
        }];
        if (!result) {
            result = [metadataObjects firstObject];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self analyseResult:result];
        });
    }
}

- (void)analyseResult:(AVMetadataMachineReadableCodeObject *)result{
    if (![result isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
        return;
    }
    NSString *resultStr = result.stringValue;
    if (resultStr.length <= 0) {
        return;
    }
    //停止扫描
    [self stopScan];
    //震动反馈
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"提示" message:result.stringValue preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:controller animated:YES completion:NULL];
}

#pragma mark - Setter && Getter
- (CIDetector *)detector{
    if (!_detector) {
        _detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    }
    return _detector;
}

- (UIButton *)switchButton{
    if (!_switchButton) {
        _switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_switchButton setBackgroundImage:[UIImage imageNamed:@"zxing_scan_flashlight_off"] forState:UIControlStateNormal];
        [_switchButton addTarget:self action:@selector(switchButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchButton;
}

@end



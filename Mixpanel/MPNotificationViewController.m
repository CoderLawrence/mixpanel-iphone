#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import "UIView+MPHelpers.h"
#import "MPLogger.h"
#import "MPNotification.h"
#import "MPNotificationViewController.h"
#import "UIColor+MPColor.h"
#import "UIImage+MPAverageColor.h"
#import "UIImage+MPImageEffects.h"
#import "MPFoundation.h"
#import "UIColor+MPColor.h"
#import "MPResources.h"

#define MPNotifHeight 65.0f


@interface CircleLayer : CALayer {}

@property (nonatomic, assign) CGFloat circlePadding;

@end

@interface ElasticEaseOutAnimation : CAKeyframeAnimation {}

- (instancetype)initWithStartValue:(CGRect)start endValue:(CGRect)end andDuration:(double)duration;

@end

@interface GradientMaskLayer : CAGradientLayer {}

@end

@interface MPAlphaMaskView : UIView {

@protected
    CAGradientLayer *_maskLayer;
}

@end

@interface MPActionButton : UIButton

@property (nonatomic, assign) BOOL isLight;

@end

@interface MPNotificationViewController ()

@end

@implementation MPNotificationViewController

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    return;
}

@end

@interface MPTakeoverNotificationViewController ()

@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;
@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet NSLayoutConstraint *bottomImageSpacing;
@property (nonatomic, strong) IBOutlet MPAlphaMaskView *fadingView;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *bodyLabel;
@property (nonatomic, strong) IBOutlet UIButton *firstButton;
@property (nonatomic, strong) IBOutlet UIButton *secondButton;
@property (nonatomic, strong) IBOutlet UIView *secondButtonContainer;
@property (nonatomic, strong) IBOutlet UIView *viewMask;
@property (nonatomic, strong) IBOutlet UIButton *closeButton;

@end

@interface MPTakeoverNotificationViewController ()

@end

@implementation MPTakeoverNotificationViewController

- (instancetype)init {
    self = [super initWithNibName:[MPResources notificationXibName] bundle:[MPResources frameworkBundle]];
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.notification) {
        if (self.notification.image) {
            UIImage *image = [UIImage imageWithData:self.notification.image scale:2.0f];
            if (image) {
                self.imageView.image = image;
            } else {
                MPLogError(@"image failed to load from data: %@", self.notification.image);
            }
        }

        MPTakeoverNotification *notification = (MPTakeoverNotification *) self.notification;

        if (notification.title && notification.body) {
            self.titleLabel.text = notification.title;
            self.bodyLabel.text = notification.body;
            self.titleLabel.textColor = [UIColor mp_colorFromRGB:notification.titleColor];
            self.bodyLabel.textColor = [UIColor mp_colorFromRGB:notification.bodyColor];
        } else {
            [[NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0] setActive:YES];
            [[NSLayoutConstraint constraintWithItem:self.bodyLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0] setActive:YES];
        }

        UIImage *originalImage = self.closeButton.imageView.image;
        UIImage *tintedImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        [self.closeButton setImage:tintedImage forState:UIControlStateNormal];
        self.closeButton.tintColor = [UIColor mp_colorFromRGB:notification.closeButtonColor];

        if (!notification.shouldFadeImage) {
            self.bottomImageSpacing.constant = 30;
            self.fadingView.layer.mask = nil;
        }

        [self setUpButtonView:self.firstButton withData:notification.buttons[0] forIndex:0];

        if (notification.buttons.count == 2) {
            [self setUpButtonView:self.secondButton withData:notification.buttons[1] forIndex:1];
        } else {
            [[NSLayoutConstraint constraintWithItem:self.secondButtonContainer attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0] setActive:YES];
        }
        
        self.viewMask.backgroundColor = [UIColor mp_colorFromRGB:notification.backgroundColor];
        self.viewMask.clipsToBounds = YES;
        self.viewMask.layer.cornerRadius = 6.f;
    }
}

- (void)setUpButtonView:(UIButton *)buttonView withData:(MPNotificationButton *)notificationButton forIndex:(NSInteger)index {
    [buttonView setTitle:notificationButton.text forState:UIControlStateNormal];
    buttonView.layer.cornerRadius = 5.0f;
    buttonView.layer.borderWidth = 2.0f;
    UIColor *textColor = [UIColor mp_colorFromRGB:notificationButton.textColor];
    [buttonView setTitleColor:textColor forState:UIControlStateNormal];
    [buttonView setTag:index];
    UIColor *borderColor = [UIColor mp_colorFromRGB:notificationButton.borderColor];
    [buttonView.layer setBorderColor:borderColor.CGColor];
    [buttonView addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)buttonTapped:(UIButton *)button {
    [self.delegate notificationController:self wasDismissedWithCtaUrl:((MPTakeoverNotification *)self.notification).buttons[button.tag].ctaUrl];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    [self.presentingViewController dismissViewControllerAnimated:animated completion:completion];
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (IBAction)tappedClose:(UITapGestureRecognizer *)gesture
{
    if ([self.delegate respondsToSelector:@selector(notificationController:wasDismissedWithCtaUrl:)]) {
        [self.delegate notificationController:self wasDismissedWithCtaUrl:nil];
    }
}

@end

@interface MPMiniNotificationViewController () {
    CGPoint _panStartPoint;
    CGPoint _position;
    BOOL _canPan;
    BOOL _isBeingDismissed;
}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) CircleLayer *circleLayer;
@property (nonatomic, strong) UILabel *bodyLabel;

@end

@implementation MPMiniNotificationViewController

static const NSUInteger MPMiniNotificationSpacingFromBottom = 10;

- (void)viewDidLoad
{
    [super viewDidLoad];

    _canPan = YES;
    _isBeingDismissed = NO;
    self.view.clipsToBounds = YES;
    
    MPMiniNotification *notification = (MPMiniNotification *) self.notification;

    self.imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.imageView.layer.masksToBounds = YES;

    self.bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bodyLabel.textColor = [UIColor mp_colorFromRGB:notification.bodyColor];
    self.bodyLabel.backgroundColor = [UIColor clearColor];
    self.bodyLabel.font = [UIFont systemFontOfSize:14.0f];
    self.bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.bodyLabel.numberOfLines = 0;

    self.view.backgroundColor = [UIColor mp_colorFromRGB:notification.backgroundColor];

    if (notification != nil) {
        if (notification.image != nil) {
            self.imageView.image = [UIImage imageWithData:notification.image scale:2.0f];
            UIImage *originalImage = [UIImage imageWithData:notification.image scale:2.0f];
            UIImage *tintedImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [self.imageView setImage:tintedImage];
            self.imageView.tintColor = [UIColor mp_colorFromRGB:notification.imageTintColor];
            self.imageView.hidden = NO;
        } else {
            self.imageView.hidden = YES;
        }

        if (notification.body != nil) {
            self.bodyLabel.text = notification.body;
            self.bodyLabel.hidden = NO;
        } else {
            self.bodyLabel.hidden = YES;
        }
    }

    [self.view addSubview:self.imageView];
    [self.view addSubview:self.bodyLabel];

    self.view.frame = CGRectMake(0.0f, 0.0f, 0.0f, 30.0f);

    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    gesture.numberOfTouchesRequired = 1;
    [self.view addGestureRecognizer:gesture];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)viewWillLayoutSubviews
{
    UIView *parentView = self.view.superview;
    CGRect parentFrame = parentView.frame;

    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.view.frame = CGRectMake(15, parentFrame.size.height - MPNotifHeight - MPMiniNotificationSpacingFromBottom, parentFrame.size.width - 30, MPNotifHeight);
    } else {
        self.view.frame = CGRectMake(parentFrame.size.width/4, parentFrame.size.height - MPNotifHeight - MPMiniNotificationSpacingFromBottom, parentFrame.size.width/2, MPNotifHeight);
    }
    self.view.clipsToBounds = YES;
    self.view.layer.cornerRadius = 6.f;

    // Position images
    self.imageView.layer.position = CGPointMake(MPNotifHeight / 2.0f, MPNotifHeight / 2.0f);

    // Position circle around image
    self.circleLayer.position = self.imageView.layer.position;
    [self.circleLayer setNeedsDisplay];

    // Position body label
    CGSize constraintSize = CGSizeMake(self.view.frame.size.width - MPNotifHeight - 12.5f, CGFLOAT_MAX);
    CGSize sizeToFit = [self.bodyLabel.text boundingRectWithSize:constraintSize
                                                         options:NSStringDrawingUsesLineFragmentOrigin
                                                      attributes:@{NSFontAttributeName: self.bodyLabel.font}
                                                         context:nil].size;

    self.bodyLabel.frame = CGRectMake(MPNotifHeight, (CGFloat)ceil((MPNotifHeight - sizeToFit.height) / 2.0f) - 2.0f, (CGFloat)ceil(sizeToFit.width), (CGFloat)ceil(sizeToFit.height));
}

- (UIView *)getTopView
{
    UIView *topView = nil;
    for (UIView *subview in [UIApplication sharedApplication].keyWindow.subviews) {
        if (!subview.hidden && subview.alpha > 0 && subview.frame.size.width > 0 && subview.frame.size.height > 0) {
            topView = subview;
        }
    }
    return topView;
}

- (double)angleForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        default:
            return 0.0;
    }
}

- (void)showWithAnimation
{
    [self.view removeFromSuperview];

    UIView *topView = [self getTopView];
    if (topView) {
        CGRect topFrame = topView.frame;
        [topView addSubview:self.view];

        _canPan = NO;

        self.view.frame = CGRectMake(0.0f, topFrame.size.height, topFrame.size.width, MPNotifHeight * 3.0f);
        _position = self.view.layer.position;

        [UIView animateWithDuration:0.1f animations:^{
            self.view.frame = CGRectMake(0.0f, topFrame.size.height - MPNotifHeight, topFrame.size.width, MPNotifHeight * 3.0f);
        } completion:^(BOOL finished) {
            self->_position = self.view.layer.position;
            [self performSelector:@selector(animateImage) withObject:nil afterDelay:0.1];
            self->_canPan = YES;
        }];
    }
}

- (void)animateImage
{
    CGSize imageViewSize = CGSizeMake(40.0f, 40.0f);
    CGFloat duration = 0.5f;

    // Animate the circle around the image
    CGRect before = _circleLayer.bounds;
    CGRect after = CGRectMake(0.0f, 0.0f, imageViewSize.width + (_circleLayer.circlePadding * 2.0f), imageViewSize.height + (_circleLayer.circlePadding * 2.0f));

    ElasticEaseOutAnimation *circleAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:before endValue:after andDuration:duration];
    _circleLayer.bounds = after;
    [_circleLayer addAnimation:circleAnimation forKey:@"bounds"];

    // Animate the image
    before = _imageView.bounds;
    after = CGRectMake(0.0f, 0.0f, imageViewSize.width, imageViewSize.height);
    ElasticEaseOutAnimation *imageAnimation = [[ElasticEaseOutAnimation alloc] initWithStartValue:before endValue:after andDuration:duration];
    _imageView.layer.bounds = after;
    [_imageView.layer addAnimation:imageAnimation forKey:@"bounds"];
}

- (void)hideWithAnimation:(BOOL)animated completion:(void (^)(void))completion
{
    _canPan = NO;

    if (!_isBeingDismissed) {
        _isBeingDismissed = YES;
        
        CGFloat duration = animated ? 0.5f : 0.f;
        CGRect parentFrame = self.view.superview.frame;
        
        [UIView animateWithDuration:duration
                         animations:^{
                             self.view.frame = CGRectMake(self.view.frame.origin.x, parentFrame.size.height, self.view.frame.size.width, self.view.frame.size.height);
                         } completion:^(BOOL finished) {
                             [self.view removeFromSuperview];
                             if (completion) {
                                 completion();
                             }
                         }];
    }
}

- (void)didTap:(UITapGestureRecognizer *)gesture
{
    if (!_isBeingDismissed && gesture.state == UIGestureRecognizerStateEnded) {
        [self.delegate notificationController:self wasDismissedWithCtaUrl:((MPMiniNotification *)self.notification).ctaUrl];
    }
}

- (void)didPan:(UIPanGestureRecognizer *)gesture
{
    if (_canPan) {
        if (gesture.state == UIGestureRecognizerStateBegan && gesture.numberOfTouches == 1) {
            _panStartPoint = [gesture locationInView:self.parentViewController.view];
        } else if (gesture.state == UIGestureRecognizerStateChanged) {
            CGPoint position = [gesture locationInView:self.parentViewController.view];
            CGFloat diffY = position.y - _panStartPoint.y;

            if (diffY > 0) {
                position.y = _position.y + diffY * 2.0f;
            } else {
                position.y = _position.y + diffY * 0.1f;
            }

            self.view.layer.position = CGPointMake(self.view.layer.position.x, position.y);
        } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
            id strongDelegate = self.delegate;
            if (self.view.layer.position.y > _position.y + MPNotifHeight / 2.0f && strongDelegate != nil) {
                [strongDelegate notificationController:self wasDismissedWithCtaUrl:nil];
            } else {
                [UIView animateWithDuration:0.2f animations:^{
                    self.view.layer.position = self->_position;
                }];
            }
        }
    }
}

@end

@implementation MPAlphaMaskView

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        _maskLayer = [GradientMaskLayer layer];
        [self.layer setMask:_maskLayer];
        [_maskLayer setColors:@[[UIColor blackColor], [UIColor blackColor], [UIColor clearColor],[UIColor clearColor]]];
        [_maskLayer setLocations:@[@0, @0.4, @0.9, @1]];
        [_maskLayer setStartPoint:CGPointMake(0, 0)];
        [_maskLayer setEndPoint:CGPointMake(0, 1)];
        self.opaque = NO;
        _maskLayer.opaque = NO;
        _maskLayer.needsDisplayOnBoundsChange = YES;
        [_maskLayer setNeedsDisplay];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_maskLayer setFrame:self.bounds];
}

@end

@implementation MPActionButton

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.layer.cornerRadius = 5.0f;
        self.layer.borderColor = [UIColor whiteColor].CGColor;
        self.layer.borderWidth = 2.0f;
    }

    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted) {
        self.layer.borderColor = [UIColor grayColor].CGColor;
    } else {
        if (self.isLight) {
            self.layer.borderColor = [UIColor colorWithRed:123/255.0 green:146/255.0 blue:163/255.0 alpha:1].CGColor;
        } else {
            self.layer.borderColor = [UIColor whiteColor].CGColor;
        }
    }

    [super setHighlighted:highlighted];
}

@end

@implementation CircleLayer

+ (instancetype)layer {
    CircleLayer *cl = (CircleLayer *)[super layer];
    cl.circlePadding = 2.5f;
    return cl;
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGFloat edge = 1.5f; //the distance from the edge so we don't get clipped.
    CGContextSetAllowsAntialiasing(ctx, true);
    CGContextSetShouldAntialias(ctx, true);

    CGMutablePathRef thePath = CGPathCreateMutable();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGPathAddArc(thePath, NULL, self.frame.size.width / 2.0f, self.frame.size.height / 2.0f, MIN(self.frame.size.width, self.frame.size.height) / 2.0f - (2 * edge), (float)-M_PI, (float)M_PI, YES);

    CGContextBeginPath(ctx);
    CGContextAddPath(ctx, thePath);

    CGContextSetLineWidth(ctx, 1.5f);
    CGContextStrokePath(ctx);

    CFRelease(thePath);
}

@end

@implementation GradientMaskLayer

- (void)drawInContext:(CGContextRef)ctx
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();

    CGFloat components[] = { //[Grayscale, Alpha] for each component
        1.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 0.0f};

    CGFloat locations[] = {0.0f, 0.4f, 0.9f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 4);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(5.0f, self.bounds.size.height), (CGGradientDrawingOptions)0);


    NSUInteger bits = (NSUInteger)fabs(self.bounds.size.width) * (NSUInteger)fabs(self.bounds.size.height);
    char *rgba = (char *)malloc(bits);
    srand(124);

    for (NSUInteger i = 0; i < bits; ++i) {
        rgba[i] = (rand() % 8);
    }

    CGContextRef noise = CGBitmapContextCreate(rgba, (NSUInteger)fabs(self.bounds.size.width), (NSUInteger)fabs(self.bounds.size.height), 8, (NSUInteger)fabs(self.bounds.size.width), NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    CGImageRef image = CGBitmapContextCreateImage(noise);

    CGContextSetBlendMode(ctx, kCGBlendModeSourceOut);
    CGContextDrawImage(ctx, self.bounds, image);

    CGImageRelease(image);
    CGColorSpaceRelease(colorSpace);
    CGGradientRelease(gradient);
    CGContextRelease(noise);
    free(rgba);
}

@end

@implementation ElasticEaseOutAnimation

- (instancetype)initWithStartValue:(CGRect)start endValue:(CGRect)end andDuration:(double)duration
{
    if ((self = [super init])) {
        self.duration = duration;
        self.values = [self generateValuesFrom:start to:end];
    }
    return self;
}

- (NSArray *)generateValuesFrom:(CGRect)start to:(CGRect)end
{
    NSUInteger steps = (NSUInteger)ceil(60 * self.duration) + 2;
	NSMutableArray *valueArray = [NSMutableArray arrayWithCapacity:steps];
    const double increment = 1.0 / (double)(steps - 1);
    double t = 0.0;
    CGRect range = CGRectMake(end.origin.x - start.origin.x, end.origin.y - start.origin.y, end.size.width - start.size.width, end.size.height - start.size.height);

    NSUInteger i;
    for (i = 0; i < steps; i++) {
        float v = (float) -(pow(M_E, -8*t) * cos(12*t)) + 1; // Cosine wave with exponential decay

        CGRect value = CGRectMake(start.origin.x + v * range.origin.x,
                                  start.origin.y + v * range.origin.y,
                                  start.size.width + v * range.size.width,
                                  start.size.height + v *range.size.height);

        [valueArray addObject:[NSValue valueWithCGRect:value]];
        t += increment;
    }

    return [NSArray arrayWithArray:valueArray];
}

@end

#import "Tweak.h"

%group MitsuhaVisuals

%hook MusicNowPlayingControlsViewController

-(void)viewDidLoad{
    %orig;
    
    MSHJelloViewConfig *config = [MSHJelloViewConfig loadConfigForApplication:@"Music"];
    
    CGFloat height = CGRectGetHeight(self.view.bounds);
    self.view.clipsToBounds = 1;
    
    self.mitsuhaJelloView = [[MSHJelloView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, height) andConfig:config];
    [self.view addSubview:self.mitsuhaJelloView];
    [self.view sendSubviewToBack:self.mitsuhaJelloView];
}

-(void)viewWillAppear:(BOOL)animated{
    %orig;
    [self.mitsuhaJelloView reloadConfig];
    [self.mitsuhaJelloView msdConnect];
    self.mitsuhaJelloView.center = CGPointMake(self.mitsuhaJelloView.center.x, self.mitsuhaJelloView.frame.size.height + self.mitsuhaJelloView.config.waveOffset);
}

-(void)viewWillDisappear:(BOOL)animated{
    %orig;
    [self.mitsuhaJelloView msdDisconnect];
}

%new
-(void)setMitsuhaJelloView:(MSHJelloView *)mitsuhaJelloView{
    objc_setAssociatedObject(self, @selector(mitsuhaJelloView), mitsuhaJelloView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
-(MSHJelloView *)mitsuhaJelloView{
    return objc_getAssociatedObject(self, @selector(mitsuhaJelloView));
}

%end

%end

%ctor{
    if([MSHJelloViewConfig loadConfigForApplication:@"Music"].enabled){
        %init(MitsuhaVisuals);
    }
}
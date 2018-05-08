//
//  MSHJelloView.xmi
//  Mitsuha
//
//  Created by c0ldra1n on 2/5/17.
//  Copyright © 2017 c0ldra1n. All rights reserved.
//

#import "MSHJelloView.h"
#import "MSHUtils.h"
#import <substrate.h>
#import <Accelerate/Accelerate.h>
#import <libcolorpicker.h>
#import <arpa/inet.h>

static CGPoint midPointForPoints(CGPoint p1, CGPoint p2) {
    return CGPointMake((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
}

static CGPoint controlPointForPoints(CGPoint p1, CGPoint p2) {
    CGPoint controlPoint = midPointForPoints(p1, p2);
    CGFloat diffY = fabs(p2.y - controlPoint.y);
    
    if (p1.y < p2.y)
        controlPoint.y += diffY;
    else if (p1.y > p2.y)
        controlPoint.y -= diffY;
    
    return controlPoint;
}

@implementation MSHJelloViewConfig

- (instancetype)initWithDictionary:(NSDictionary *)dict{
    self = [super init];
    
    if (self) {
        _application = [dict objectForKey:@"application"];
        _enabled = [([dict objectForKey:@"enabled"] ?: @(YES)) boolValue];
        _enableDynamicGain = [([dict objectForKey:@"enableDynamicGain"] ?: @(NO)) boolValue];
        _enableDynamicColor = [([dict objectForKey:@"enableDynamicColor"] ?: @(NO)) boolValue];
        _enableAutoUIColor = [([dict objectForKey:@"enableAutoUIColor"] ?: @(YES)) boolValue];
        _ignoreColorFlow = [([dict objectForKey:@"ignoreColorFlow"] ?: @(NO)) boolValue];
        _enableCircleArtwork = [([dict objectForKey:@"enableCircleArtwork"] ?: @(NO)) boolValue];
        _enableFFT = [([dict objectForKey:@"enableFFT"] ?: @(NO)) boolValue];
        _enableFFTSpectrumSmoothing = [([dict objectForKey:@"enableFFTSpectrumSmoothing"] ?: @(NO)) boolValue];
        
        if([dict objectForKey:@"waveColor"]){
            if([[dict objectForKey:@"waveColor"] isKindOfClass:[UIColor class]]){
                _waveColor = [dict objectForKey:@"waveColor"];
            }else if([[dict objectForKey:@"waveColor"] isKindOfClass:[NSString class]]){
                _waveColor = LCPParseColorString([dict objectForKey:@"waveColor"], @"#000000:0.5");
            }
        }else{
            _waveColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        }
        
        if([dict objectForKey:@"subwaveColor"]){
            if([[dict objectForKey:@"subwaveColor"] isKindOfClass:[UIColor class]]){
                _subwaveColor = [dict objectForKey:@"subwaveColor"];
            }else if([[dict objectForKey:@"subwaveColor"] isKindOfClass:[NSString class]]){
                _subwaveColor = LCPParseColorString([dict objectForKey:@"subwaveColor"], @"#000000:0.5");
            }
        }else{
            _subwaveColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        }
        
        _gain = [([dict objectForKey:@"gain"] ?: @(50)) doubleValue];
        _limiter = [([dict objectForKey:@"limiter"] ?: @(0)) doubleValue];
        _numberOfPoints = [([dict objectForKey:@"numberOfPoints"] ?: @(8)) unsignedIntegerValue];
        _waveOffset = [([dict objectForKey:@"waveOffset"] ?: @(0)) doubleValue];
        _waveOffset = ([([dict objectForKey:@"negateOffset"] ?: @(false)) boolValue] ? _waveOffset * -1 : _waveOffset);
        if ([_application isEqualToString:@"Music"]) {
            _waveOffset += 70;
        } else if ([_application isEqualToString:@"Spotify"]) {
            _waveOffset += 250;
        } else if ([_application isEqualToString:@"Springboard"]) {
            _waveOffset += 250;
        } else if ([_application isEqualToString:@"Soundcloud"]) {
            _waveOffset += 500;
        }
        _fps = [([dict objectForKey:@"fps"] ?: @(60.0)) doubleValue];
    }
    
    return self;
}

+(MSHJelloViewConfig *)loadConfigForApplication:(NSString *)name{
    NSMutableDictionary *prefs = [@{} mutableCopy];
    [prefs setValue:name forKey:@"application"];

    NSMutableDictionary *file = [[NSMutableDictionary alloc] initWithContentsOfFile:MSHPreferencesFile];
    NSLog(@"[Mitsuha] Preferences: %@", file);
    for (NSString *key in [file allKeys]) {
        [prefs setValue:[file objectForKey:key] forKey:key];
    }

    file = [[NSMutableDictionary alloc] initWithContentsOfFile:MSHColorsFile];
    NSLog(@"[Mitsuha] Colors: %@", file);
    for (NSString *key in [file allKeys]) {
        [prefs setValue:[file objectForKey:key] forKey:key];
    }
    
    for (NSString *key in [prefs allKeys]) {
        NSString *removedKey = [key stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"MSH%@", name] withString:@""];
        NSString *loweredFirstChar = [[removedKey substringWithRange:NSMakeRange(0, 1)] lowercaseString];
        NSString *newKey = [removedKey stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:loweredFirstChar];

        [prefs setValue:[prefs objectForKey:key] forKey:newKey];
    }

    prefs[@"gain"] = [prefs objectForKey:@"gain"] ?: @(50);
    prefs[@"subwaveColor"] = prefs[@"waveColor"];
    prefs[@"waveOffset"] = ([prefs objectForKey:@"waveOffset"] ?: @(0));
    
    if ([name isEqualToString:@"Music"]) {
        prefs[@"waveColor"] = LCPParseColorString([prefs objectForKey:@"waveColor"], @"#fc3059:0.1");
    } else {
        prefs[@"waveColor"] = LCPParseColorString([prefs objectForKey:@"waveColor"], @"#fcfcfc:0.2");
    }
    
    if ([name isEqualToString:@"Spotify"]){
        prefs[@"fps"] = ([prefs objectForKey:@"fps"] ?: @(10.0));
    } else {
        prefs[@"fps"] = ([prefs objectForKey:@"fps"] ?: @(60.0));
    }
    
    NSLog(@"[Mitsuha] Preferences parsed: %@", prefs);
    
    return [[MSHJelloViewConfig alloc] initWithDictionary:prefs];
}

@end

@implementation MSHJelloLayer

- (id<CAAction>)actionForKey:(NSString *)event {
    if(self.shouldAnimate){
        if ([event isEqualToString:@"path"]) {
            
            CABasicAnimation *animation = [CABasicAnimation
                                           animationWithKeyPath:event];
            animation.duration = 0.15f;
            
            return animation;
        }
    }
    return [super actionForKey:event];
}

@end

@implementation MSHJelloView

const int one = 1;

const UInt32 numberOfFrames = 512;
const int numberOfFramesOver2 = numberOfFrames / 2;
const int bufferLog2 = round(log2(numberOfFrames));
const float fftNormFactor = 1.0/32.0;
const FFTSetup fftSetup = vDSP_create_fftsetup(bufferLog2, kFFTRadix2);

float outReal[numberOfFramesOver2];
float outImaginary[numberOfFramesOver2];
COMPLEX_SPLIT output = { .realp = outReal, .imagp = outImaginary };
float out[numberOfFramesOver2];
float spectrumMul[numberOfFramesOver2];

-(instancetype)initWithFrame:(CGRect)frame andConfig:(MSHJelloViewConfig *)config{
    self = [super initWithFrame:frame];

    if (self) {
        connfd = -1;
        empty = (float *)malloc(sizeof(float));

        for (int i = 0; i < numberOfFramesOver2; i++) {
            spectrumMul[i] = pow(i/5, 0.85)/5;
        }

        self.config = config;
        [self initializeWaveLayers];

        empty[0] = 0.0f;

        self.shouldUpdate = true;
        self.points = (CGPoint *)malloc(sizeof(CGPoint) * self.config.numberOfPoints);
        cachedLength = self.config.numberOfPoints;

        [self updateBuffer:empty withLength:1];
    }

    return self;
}

-(void)reloadConfig{
    self.config = [MSHJelloViewConfig loadConfigForApplication:self.config.application];
    [self updateWaveColor:self.config.waveColor subwaveColor:self.config.subwaveColor];
    self.displayLink.preferredFramesPerSecond = self.config.fps;
}

-(void)msdDisconnect{
    NSLog(@"[MitsuhaXI] Disconnect");
    close(connfd);
    connfd = -2;
}

-(void)msdConnect{
    connfd = -1;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"[MitsuhaXI] connfd = %d", connfd);
        struct sockaddr_in remote;
        remote.sin_family = PF_INET;
        remote.sin_port = htons(ASSPort);
        inet_aton("127.0.0.1", &remote.sin_addr);
        int r = -1;
        int rlen = 0;
        float *data = NULL;
        UInt32 len = sizeof(float);
        int retries = 0;

        while (connfd != -2) {
            NSLog(@"[MitsuhaXI] Connecting to mediaserverd.");
            retries++;
            connfd = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

            if (connfd == -1) {
                usleep(1000 * 1000);
                continue;
            }
            setsockopt(connfd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));

            while(r != 0) {
                r = connect(connfd, (struct sockaddr *)&remote, sizeof(remote));
                usleep(200 * 1000);
            }

            NSLog(@"[MitsuhaXI] Connected.");

            if (retries > 10) {
                connfd = -2;
                NSLog(@"[MitsuhaXI] Too many retries. Aborting.");
                break;
            }

            while(true) {
                if (connfd < 0) break;

                rlen = recv(connfd, &len, sizeof(UInt32), 0);

                if (connfd < 0) break;

                if (rlen <= 0) {
                    if (rlen == 0) close(connfd);
                    connfd = -1;
                    len = sizeof(float);
                    data = empty;
                }

                if (len > sizeof(float)) {
                    free(data);
                    data = (float *)malloc(len);
                    rlen = recv(connfd, data, len, 0);

                    if (connfd < 0) break;

                    if (rlen > 0) {
                        retries = 0;
                        [self updateBuffer:data withLength:rlen/sizeof(float)];
                    } else {
                        if (rlen == 0) close(connfd);
                        connfd = -1;
                        len = sizeof(float);
                        data = empty;
                    }
                }
            }

            if (connfd == -2) break;
            usleep(1000 * 1000);
        }
        
        NSLog(@"[MitsuhaXI] Forcefully disconnected.");
    });
}

-(void)initializeWaveLayers{
    self.waveLayer = [MSHJelloLayer layer];
    self.subwaveLayer = [MSHJelloLayer layer];
    
    self.waveLayer.frame = self.subwaveLayer.frame = self.bounds;
    
    [self updateWaveColor:self.config.waveColor subwaveColor:self.config.subwaveColor];
    
    [self.layer addSublayer:self.waveLayer];
    [self.layer addSublayer:self.subwaveLayer];
    
    self.waveLayer.zPosition = 0;
    self.subwaveLayer.zPosition = -1;
    
    [self configureDisplayLink];
    [self resetWaveLayers];
}

-(void)resetWaveLayers{
    if (!self.waveLayer || !self.subwaveLayer) {
        [self initializeWaveLayers];
    }
    
    CGPathRef path = [self createPathWithPoints:self.points
                                     pointCount:0
                                         inRect:self.bounds];
    
    NSLog(@"[Mitsuha]: Resetting Wave Layers...");
    
    self.waveLayer.path = path;
    self.subwaveLayer.path = path;
}

-(void)configureDisplayLink{
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(redraw)];
    
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.displayLink setPaused:false];

    self.displayLink.preferredFramesPerSecond = self.config.fps;
    
    self.waveLayer.shouldAnimate = true;
    self.subwaveLayer.shouldAnimate = true;
}

-(void)updateWaveColor:(UIColor *)waveColor subwaveColor:(UIColor *)subwaveColor{
    self.waveLayer.fillColor = waveColor.CGColor;
    self.subwaveLayer.fillColor = subwaveColor.CGColor;
}

- (void)redraw{
    if (self.shouldUpdate) {
        [self requestUpdate];
    }
    CGPathRef path = [self createPathWithPoints:self.points
                                     pointCount:self.config.numberOfPoints
                                         inRect:self.bounds];
    self.waveLayer.path = path;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.subwaveLayer.path = path;
        CGPathRelease(path);
    });
}


- (CGPathRef)createPathWithPoints:(CGPoint *)points
                       pointCount:(NSUInteger)pointCount
                           inRect:(CGRect)rect {
    UIBezierPath *path;
    
    if (pointCount > 0){
        path = [UIBezierPath bezierPath];
        
        [path moveToPoint:CGPointMake(0, self.frame.size.height)];
        
        CGPoint p1 = self.points[0];
        
        [path addLineToPoint:p1];
        
        for (int i = 0; i<self.config.numberOfPoints; i++) {
            CGPoint p2 = self.points[i];
            CGPoint midPoint = midPointForPoints(p1, p2);
            
            [path addQuadCurveToPoint:midPoint controlPoint:controlPointForPoints(midPoint, p1)];
            [path addQuadCurveToPoint:p2 controlPoint:controlPointForPoints(midPoint, p2)];
            
            p1 = self.points[i];
        }
        
        [path addLineToPoint:CGPointMake(self.frame.size.width, self.frame.size.height)];
        [path addLineToPoint:CGPointMake(0, self.frame.size.height)];
    }else{
        float pixelFixer = self.bounds.size.width/self.config.numberOfPoints;
        
        if(cachedLength != self.config.numberOfPoints){
            self.points = (CGPoint *)malloc(sizeof(CGPoint) * self.config.numberOfPoints);
            cachedLength = self.config.numberOfPoints;
            
            for (int i = 0; i < self.config.numberOfPoints; i++){
                self.points[i].x = i*pixelFixer;
                self.points[i].y = self.config.waveOffset; //self.bounds.size.height/2;
            }
            
            self.points[self.config.numberOfPoints - 1].x = self.bounds.size.width;
            self.points[0].y = self.points[self.config.numberOfPoints - 1].y = self.config.waveOffset; //self.bounds.size.height/2;
        }
        
        return [self createPathWithPoints:self.points
                               pointCount:self.config.numberOfPoints
                                   inRect:self.bounds];
    }
    
    CGPathRef convertedPath = path.CGPath;
    
    return CGPathCreateCopy(convertedPath);
}

-(void)requestUpdate{
    if (connfd > 0) {
        int slen = send(connfd, &one, sizeof(int), 0);
        if (slen <= 0) {
            if (slen == 0) {
                close(connfd);
            }
            connfd = -1;
        }
    }
}

-(void)updateBuffer:(float *)bufferData withLength:(int)length{
    if (self.config.enableFFT && length >= numberOfFrames) {
        vDSP_ctoz((COMPLEX *)bufferData, 2, &output, 1, numberOfFramesOver2);
        vDSP_fft_zrip(fftSetup, &output, 1, bufferLog2, FFT_FORWARD);
        vDSP_vsmul(output.realp, 1, &fftNormFactor, output.realp, 1, numberOfFramesOver2);
        vDSP_vsmul(output.imagp, 1, &fftNormFactor, output.imagp, 1, numberOfFramesOver2);
        vDSP_zvabs(&output, 1, out, 1, numberOfFramesOver2);

        if (self.config.enableFFTSpectrumSmoothing) {
            vDSP_vmul(out, 1, spectrumMul, 1, out, 1, numberOfFramesOver2);
        }

        [self setSampleData:out length:numberOfFramesOver2/2];
    } else {
        [self setSampleData:bufferData length:length];
    }
}

- (void)setSampleData:(float *)data length:(int)length{
    NSUInteger compressionRate = length/self.config.numberOfPoints;
    
    float pixelFixer = self.bounds.size.width/self.config.numberOfPoints;
    
    if(cachedLength != self.config.numberOfPoints){
        free(self.points);
        self.points = (CGPoint *)malloc(sizeof(CGPoint) * self.config.numberOfPoints);
        cachedLength = self.config.numberOfPoints;
    }

#ifdef Sigma
    
    for (int i = 0; i<length; i++) {
        self.points[(int)(i/8)].y += data[i];
    }
    
#else
    
    for (int i = 0; i < self.config.numberOfPoints; i++){
        self.points[i].x = i*pixelFixer;
        double pureValue = data[i*compressionRate] * self.config.gain;
        
        if(self.config.limiter != 0){
            pureValue = (fabs(pureValue) < self.config.limiter ? pureValue : (pureValue < 0 ? -1*self.config.limiter : self.config.limiter));
        }
        
        self.points[i].y = (-1 * pureValue) + self.config.waveOffset;// + self.bounds.size.height/2;
    }
    
#endif
    
    self.points[self.config.numberOfPoints - 1].x = self.bounds.size.width;
    self.points[0].y = self.points[self.config.numberOfPoints - 1].y = self.config.waveOffset; //self.bounds.size.height/2;
}

@end
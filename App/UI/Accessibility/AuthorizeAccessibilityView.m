//
// --------------------------------------------------------------------------
// AuthorizeAccessibilityView.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2019
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

/// Bug:
///     [Aug 2025] Paul Romas reports that the 'Open Privacy & Security Settings' link doesn't work under macOS 10.15 Catalina. (message:<AC7FA1E0-0E52-4B41-869F-B85F1AE0A8E8@gmail.com>)
///         TODO: Investigate – Probably also check if it works on macOS 11 Big Sur and other older macOS versions.
///         Note: The link uses the url: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`

#import "AppDelegate.h"
#import "AuthorizeAccessibilityView.h"
#import "Utility_App.h"
#import "ToastController.h"
#import "MFMessagePort.h"
//#import "CaptureToasts.h" 
#import "Mac_Mouse_Fix-Swift.h"
#import "Localization.h"
#import "Locator.h"
#import "Links.h"

@interface AuthorizeAccessibilityView ()

@property (weak) IBOutlet NSTextField *titleLabel;
@property (weak) IBOutlet NSTextField *subtitleLabel;
@property (weak) IBOutlet NSTextField *step1NumberLabel;
@property (weak) IBOutlet Hyperlink *openSettingsLink;
@property (weak) IBOutlet NSTextField *step2NumberLabel;
@property (weak) IBOutlet NSTextField *step2Label;
@property (weak) IBOutlet NSButton *cancelButton;

@end

@implementation AuthorizeAccessibilityView {
    NSButton *_copyPathButton;
    NSUInteger _copyFeedbackGeneration;
}

AuthorizeAccessibilityView *_accViewController;

+ (void)load {
//    [self performSelector:@selector(addAccViewToWindow) withObject:NULL afterDelay:0.5];
//    [self performSelector:@selector(removeAccViewFromWindow) withObject:NULL afterDelay:3];
    
    
//    NSArray *windows = NSApplication.sharedApplication.windows;
//    NSWindow *prefWindow;
//    for (NSWindow *w in windows) {
//        if ([w.className isEqualToString:@"NSPrefWindow"]) {
//            prefWindow = w;
//        }
//    }
//
//    NSView *accView;
//    for (NSView *v in prefWindow.contentView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//        }
//    }
//
//    _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
//    accView = _accViewController.view;
//    [prefWindow.contentView addSubview:accView];
//
//    accView.hidden = YES;
//
//    DDLogInfo("subviews: %@", prefWindow.contentView.subviews);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(macOS 27.3, *)) {
        [self setupForSystemProtectionOverride];
    } else if (@available(macOS 13.0, *)) {
        /// Default XIB layout targets macOS 13.0–27.2
    } else {
        self.openSettingsLink.stringValue = MFLocalizedString(
            @"accessibility.settings-link.pre-ventura",
            @"Will be used in a context like this: \n"
            "   1. Open 'Security & Privacy' Preferences\n"
            "   2. Switch on 'Mac Mouse Fix Helper'\n"
            "\n"
            "Background info: 'System Preferences' were renamed to 'System Settings' in macOS Ventura. The translation for Ventura and later is defined by 46z-Nd-nh4.title and other entries in AuthorizeAccessibilityView. This here is the string for earlier versions."
        );
    }
}

/// Rebuilds the onboarding steps for macOS 27.3+, where Apple split "Device Control and Data Access"
/// (formerly Accessibility) into "Accessibility" (entitlement-gated assistive tech) and
/// "System & App Protection Override" (which no longer auto-populates from AXIsProcessTrustedWithOptions
/// and no longer supports drag-and-drop into the list).
- (void)setupForSystemProtectionOverride {
    
    /// Update title & subtitle
    self.titleLabel.stringValue = MFLocalizedString(
        @"accessibility.override.title",
        @"Title of the permission sheet on macOS 27.3+, where the Accessibility permission for non-assistive utilities was moved to 'System & App Protection Override'."
    );
    self.subtitleLabel.stringValue = MFLocalizedString(
        @"accessibility.override.subtitle",
        @"Subtitle of the permission sheet on macOS 27.3+. Recommend splitting into two lines of roughly the same length for a nice visual layout."
    );
    
    /// Grab the existing localized openSettingsLink before detaching the legacy 2-step views
    Hyperlink *settingsLink = self.openSettingsLink;
    [self.step1NumberLabel removeFromSuperview];
    [settingsLink removeFromSuperview];
    [self.step2NumberLabel removeFromSuperview];
    [self.step2Label removeFromSuperview];
    
    /// Helper to build a numbered step row
    NSStackView *(^makeStepRow)(NSString *number, NSView *contentView) = ^NSStackView *(NSString *number, NSView *contentView) {
        NSTextField *numLabel = [NSTextField labelWithString:number];
        numLabel.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        numLabel.textColor = NSColor.labelColor;
        numLabel.alignment = NSTextAlignmentRight;
        [numLabel setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [numLabel setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        [numLabel.widthAnchor constraintEqualToConstant:16.0].active = YES;
        
        NSStackView *row = [NSStackView stackViewWithViews:@[numLabel, contentView]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.alignment = NSLayoutAttributeFirstBaseline;
        row.spacing = 6.0;
        return row;
    };
    
    NSTextField *(^makeStepLabel)(NSString *text) = ^NSTextField *(NSString *text) {
        NSTextField *label = [NSTextField labelWithString:text];
        label.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
        label.textColor = NSColor.labelColor;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        return label;
    };
    
    /// Step 1: Open 'Privacy & Security' Settings (reuses existing localized Hyperlink)
    settingsLink.alignment = NSTextAlignmentLeft;
    NSStackView *step1Row = makeStepRow(@"1.", settingsLink);
    
    /// Step 2: Select 'System & App Protection Override' and click '+'
    NSTextField *step2Text = makeStepLabel(MFLocalizedString(
        @"accessibility.override.step2",
        @"Step 2 on macOS 27.3+ permission sheet: instruct user to open System & App Protection Override and click the '+' button."
    ));
    NSStackView *step2Row = makeStepRow(@"2.", step2Text);
    
    /// Step 3: Press ⇧⌘G, paste the helper path, and add 'Mac Mouse Fix Helper'
    NSTextField *step3Text = makeStepLabel(MFLocalizedString(
        @"accessibility.override.step3",
        @"Step 3 on macOS 27.3+ permission sheet: instruct user to press Shift-Command-G in the file picker, paste the helper path, and select Mac Mouse Fix Helper."
    ));
    NSStackView *step3Row = makeStepRow(@"3.", step3Text);
    
    /// Action buttons under Step 3: Copy Helper Path & Reveal in Finder
    NSString *copyTitle = MFLocalizedString(
        @"accessibility.override.copy-path",
        @"Button title on macOS 27.3+ permission sheet that copies the path of 'Mac Mouse Fix Helper.app' to the clipboard."
    );
    _copyPathButton = [NSButton buttonWithTitle:copyTitle target:self action:@selector(copyHelperPathClicked:)];
    _copyPathButton.controlSize = NSControlSizeSmall;
    _copyPathButton.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
    
    NSString *revealTitle = MFLocalizedString(
        @"accessibility.override.reveal-helper",
        @"Button title on macOS 27.3+ permission sheet that reveals 'Mac Mouse Fix Helper.app' in Finder."
    );
    NSButton *revealButton = [NSButton buttonWithTitle:revealTitle target:self action:@selector(revealHelperClicked:)];
    revealButton.controlSize = NSControlSizeSmall;
    revealButton.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall]];
    
    NSStackView *helperActionsRow = [NSStackView stackViewWithViews:@[_copyPathButton, revealButton]];
    helperActionsRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    helperActionsRow.alignment = NSLayoutAttributeCenterY;
    helperActionsRow.spacing = 8.0;
    helperActionsRow.edgeInsets = NSEdgeInsetsMake(2.0, 22.0, 4.0, 0.0);
    
    /// Step 4: Choose 'Override System Protections' and confirm the prompts
    NSTextField *step4Text = makeStepLabel(MFLocalizedString(
        @"accessibility.override.step4",
        @"Step 4 on macOS 27.3+ permission sheet: instruct user to choose 'Override System Protections' and confirm the macOS prompts."
    ));
    NSStackView *step4Row = makeStepRow(@"4.", step4Text);
    
    /// Assemble vertical steps stack
    NSStackView *stepsStack = [NSStackView stackViewWithViews:@[
        step1Row,
        step2Row,
        step3Row,
        helperActionsRow,
        step4Row,
    ]];
    stepsStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stepsStack.alignment = NSLayoutAttributeLeading;
    stepsStack.spacing = 7.0;
    stepsStack.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:stepsStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [stepsStack.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:20.0],
        [self.cancelButton.topAnchor constraintEqualToAnchor:stepsStack.bottomAnchor constant:24.0],
        [stepsStack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stepsStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:30.0],
        [stepsStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-30.0],
    ]];
}

- (void)copyHelperPathClicked:(NSButton *)sender {
    NSString *helperPath = Locator.helperBundle.bundlePath;
    if (helperPath.length == 0) {
        DDLogError("AuthorizeAccessibilityView: Failed to resolve helper bundle path for clipboard copy");
        return;
    }
    
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    [pb setString:helperPath forType:NSPasteboardTypeString];
    
    NSUInteger generation = ++_copyFeedbackGeneration;
    _copyPathButton.title = MFLocalizedString(
        @"accessibility.override.copied",
        @"Temporary confirmation text shown on the 'Copy Helper Path' button after copying the path."
    );
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_copyFeedbackGeneration != generation) return;
        strongSelf->_copyPathButton.title = MFLocalizedString(
            @"accessibility.override.copy-path",
            @"Button title on macOS 27.3+ permission sheet that copies the path of 'Mac Mouse Fix Helper.app' to the clipboard."
        );
    });
}

- (void)revealHelperClicked:(NSButton *)sender {
    NSURL *helperURL = Locator.helperBundle.bundleURL;
    if (!helperURL) {
        DDLogError("AuthorizeAccessibilityView: Failed to resolve helper bundle URL for Finder reveal");
        return;
    }
    [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[helperURL]];
}

- (IBAction)AuthorizeButton:(NSButton *)sender {
    
    /// This is defined in IB instead now. 
    
    assert(false);
    
    DDLogInfo("AuthorizeButton clicked");
    
    /// Open privacy prefpane
    
    NSString *urlString = [Links link:kMFLinkID_MacOSSettingsPrivacyAndSecurity];
    if (urlString) {
        [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:urlString]];
    }
}
- (IBAction)cancelButton:(NSButton *)sender {
    [HelperServices enableHelperAsUserAgent:NO onComplete:nil];
    [AuthorizeAccessibilityView remove];
}

+ (void)add {
    
    DDLogInfo("adding AuthorizeAccessibilityView");
  
    ///
    /// New sheet method
    ///
    
    mfrun(CFRunLoopGetMain(), ^{ /// Remove just don't work sometimes when we don't dispatch to mainQueue. Also dispatching add to be safe.
        
        if (_accViewController == nil) {
            _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
        }
        if ([MainAppState.shared.tabViewController.presentedViewControllers containsObject:_accViewController]) return;
        [MainAppState.shared.tabViewController presentViewControllerAsSheet:_accViewController];
    });
    
    ///
    /// Old overlay method for MMF 2.0
    ///
    
//    NSView *mainView = AppDelegate.mainWindow.contentView;
//
//    NSView *baseView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"baseView"]) {
//            baseView = v;
//        }
//    }
//    NSView *accView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//        }
//    }
//    if (accView == NULL) {
//        _accViewController = [[AuthorizeAccessibilityView alloc] initWithNibName:@"AuthorizeAccessibilityView" bundle:[NSBundle bundleForClass:[self class]]];
//        accView = _accViewController.view;
//        [mainView addSubview:accView];
//        accView.alphaValue = 0;
//        accView.hidden = YES;
//        /// Center in superview
////        mainView.translatesAutoresizingMaskIntoConstraints = NO;
//        accView.translatesAutoresizingMaskIntoConstraints = NO;
//        DDLogInfo("mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
//        [mainView addConstraints:@[
//            [NSLayoutConstraint constraintWithItem:mainView
//                                         attribute:NSLayoutAttributeCenterX
//                                         relatedBy:NSLayoutRelationEqual
//                                            toItem:accView
//                                         attribute:NSLayoutAttributeCenterX
//                                        multiplier:1
//                                          constant:0],
//            [NSLayoutConstraint constraintWithItem:mainView
//                                         attribute:NSLayoutAttributeCenterY
//                                         relatedBy:NSLayoutRelationEqual
//                                            toItem:accView
//                                         attribute:NSLayoutAttributeCenterY
//                                        multiplier:1
//                                          constant:0],
//        ]];
//        [mainView layout];
//        DDLogInfo("mainView frame: %@, accView frame: %@", [NSValue valueWithRect:mainView.frame], [NSValue valueWithRect:accView.frame]);
//    }
//
//    [NSAnimationContext beginGrouping];
//    [[NSAnimationContext currentContext] setDuration:0.3];
//    baseView.animator.alphaValue = 0;
//    baseView.hidden = YES;
//    accView.animator.alphaValue = 1;
//    accView.hidden = NO;
//    [NSAnimationContext endGrouping];
}

+ (void)remove {
    
    DDLogInfo("Removing AuthorizeAccessibilityView");
    
    ///
    /// New sheet method
    ///
    
    mfrun(CFRunLoopGetMain(), ^{
        
        if (_accViewController == nil) return;
        if (![MainAppState.shared.tabViewController.presentedViewControllers containsObject:_accViewController]) return;
        
        [MainAppState.shared.tabViewController dismissViewController:_accViewController];
    });
    
    ///
    /// Old overlay method for MMF 2.0
    ///
    
//    NSView *mainView = AppDelegate.mainWindow.contentView;
//
//    NSView *baseView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"baseView"]) {
//            baseView = v;
//        }
//    }
//    int i = 0;
//    NSView *accView;
//    for (NSView *v in mainView.subviews) {
//        if ([v.identifier isEqualToString:@"accView"]) {
//            accView = v;
//            i++;
//        }
//    }
//
//    if (accView) {
//        [accView removeFromSuperview];
//
//        [NSAnimationContext beginGrouping];
//        [NSAnimationContext.currentContext setDuration:0.3];
//        [NSAnimationContext.currentContext setCompletionHandler:^{
////            NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Welcome to Mac Mouse Fix!"];
////            [ToastController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
//            [NSTimer mf_scheduledTimerWithTimeInterval: 0.0 mode: NSRunLoopCommonModes block: ^(NSTimer * _Nonnull timer) {
//                // v This usually fails because the remote message port can't be created
//                //      I think it happens because the helper kills itself after gaining accessibility access and is restarted by launchd too slowly. Weirdly, I think I remember that this used to work.
//                NSSet *capturedButtons = [RemapTableUtility getCapturedButtons];
//                [CaptureToasts showButtonCaptureToastWithBeforeSet:NSSet.set afterSet:capturedButtons];
////                NSAttributedString *message = [[NSAttributedString alloc] initWithString:@"Mac Mouse Fix will stay enabled after you restart your Mac"];
////                [ToastController attachNotificationWithMessage:message toWindow:AppDelegate.mainWindow forDuration:-1];
//            }];
//        }];
//        baseView.animator.alphaValue = 1;
//        baseView.hidden = NO;
//        accView.animator.alphaValue = 0;
//        accView.hidden = YES;
//        [NSAnimationContext endGrouping];
//    }
}

@end

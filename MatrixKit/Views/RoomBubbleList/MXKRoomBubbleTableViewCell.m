/*
 Copyright 2015 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MXKRoomBubbleTableViewCell.h"

#import "MXKImageView.h"
#import "MXKPieChartView.h"
#import "MXKRoomBubbleCellData.h"
#import "MXKTools.h"

#import "MXKConstants.h"

#import "NSBundle+MatrixKit.h"
#import "MXRoom+Sync.h"
#import "MXKMessageTextView.h"
#import "UITextView+MatrixKit.h"

#pragma mark - Constant definitions
NSString *const kMXKRoomBubbleCellTapOnMessageTextView = @"kMXKRoomBubbleCellTapOnMessageTextView";
NSString *const kMXKRoomBubbleCellTapOnSenderNameLabel = @"kMXKRoomBubbleCellTapOnSenderNameLabel";
NSString *const kMXKRoomBubbleCellTapOnAvatarView = @"kMXKRoomBubbleCellTapOnAvatarView";
NSString *const kMXKRoomBubbleCellTapOnDateTimeContainer = @"kMXKRoomBubbleCellTapOnDateTimeContainer";
NSString *const kMXKRoomBubbleCellTapOnAttachmentView = @"kMXKRoomBubbleCellTapOnAttachmentView";
NSString *const kMXKRoomBubbleCellTapOnOverlayContainer = @"kMXKRoomBubbleCellTapOnOverlayContainer";
NSString *const kMXKRoomBubbleCellTapOnContentView = @"kMXKRoomBubbleCellTapOnContentView";

NSString *const kMXKRoomBubbleCellUnsentButtonPressed = @"kMXKRoomBubbleCellUnsentButtonPressed";

NSString *const kMXKRoomBubbleCellLongPressOnEvent = @"kMXKRoomBubbleCellLongPressOnEvent";
NSString *const kMXKRoomBubbleCellLongPressOnProgressView = @"kMXKRoomBubbleCellLongPressOnProgressView";
NSString *const kMXKRoomBubbleCellLongPressOnAvatarView = @"kMXKRoomBubbleCellLongPressOnAvatarView";
NSString *const kMXKRoomBubbleCellShouldInteractWithURL = @"kMXKRoomBubbleCellShouldInteractWithURL";

NSString *const kMXKRoomBubbleCellUserIdKey = @"kMXKRoomBubbleCellUserIdKey";
NSString *const kMXKRoomBubbleCellEventKey = @"kMXKRoomBubbleCellEventKey";
NSString *const kMXKRoomBubbleCellEventIdKey = @"kMXKRoomBubbleCellEventIdKey";
NSString *const kMXKRoomBubbleCellReceiptsContainerKey = @"kMXKRoomBubbleCellReceiptsContainerKey";
NSString *const kMXKRoomBubbleCellUrl = @"kMXKRoomBubbleCellUrl";
NSString *const kMXKRoomBubbleCellUrlItemInteraction = @"kMXKRoomBubbleCellUrlItemInteraction";

static BOOL _disableLongPressGestureOnEvent;

@interface MXKRoomBubbleTableViewCell () <UIGestureRecognizerDelegate>
{
    // The list of UIViews used to fix the display of side borders for HTML blockquotes
    NSMutableArray<UIView*> *htmlBlockquoteSideBorderViews;
}

@property (nonatomic, weak) UIView *messageTextBackgroundView;
@property (nonatomic) double attachmentViewBottomConstraintDefaultConstant;

@end

@implementation MXKRoomBubbleTableViewCell
@synthesize delegate, bubbleData, readReceiptsAlignment;
@synthesize mxkCellData;

+ (instancetype)roomBubbleTableViewCell
{
    MXKRoomBubbleTableViewCell *instance = nil;
    
    // Check whether a xib is defined
    if ([[self class] nib])
    {
        @try {
            instance = [[[self class] nib] instantiateWithOwner:nil options:nil].firstObject;
        }
        @catch (NSException *exception) {
        }
    }
    
    if (!instance)
    {
        instance = [[self alloc] init];
    }
    
    return instance;
}

+ (void)disableLongPressGestureOnEvent:(BOOL)disable
{
    _disableLongPressGestureOnEvent = disable;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        [self finalizeInit];
    }
    return self;
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        [self finalizeInit];
    }
    return self;
}

- (void)finalizeInit
{
    self.readReceiptsAlignment = ReadReceiptAlignmentLeft;
    _allTextHighlighted = NO;
    _isAutoAnimatedGif = NO;
    _temperaryContentViewConstraints = [[NSMutableArray alloc] init];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self setupViews];
}

- (void)setupViews
{
    if (self.userNameLabel)
    {
        // Listen to name tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSenderNameTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        
        if (self.userNameTapGestureMaskView)
        {
            [self.userNameTapGestureMaskView addGestureRecognizer:tapGesture];
        }
        else
        {
            [self.userNameLabel addGestureRecognizer:tapGesture];
            self.userNameLabel.userInteractionEnabled = YES;
        }
    }
    
    if (self.pictureView)
    {
        self.pictureView.mediaFolder = kMXMediaManagerAvatarThumbnailFolder;
        
        // Listen to avatar tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAvatarTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.pictureView addGestureRecognizer:tapGesture];
        self.pictureView.userInteractionEnabled = YES;
        
        // Add a long gesture recognizer on avatar (in order to display for example the member details)
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
        [self.pictureView addGestureRecognizer:longPress];
    }
    
    if (self.messageTextView)
    {
        // Listen to textView tap
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onMessageTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.messageTextView addGestureRecognizer:tapGesture];
        self.messageTextView.userInteractionEnabled = YES;

        // Recognise and make tappable phone numbers, address, etc.
        self.messageTextView.dataDetectorTypes = UIDataDetectorTypeAll;

        // Listen to link click
        self.messageTextView.delegate = self;
        
        if (_disableLongPressGestureOnEvent == NO)
        {
            // Add a long gesture recognizer on text view (in order to display for example the event details)
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            longPress.delegate = self;
            
            // MXKMessageTextView does not catch touches outside of links. Add a background view to handle long touch.
            if ([self.messageTextView isKindOfClass:[MXKMessageTextView class]])
            {
                UIView *messageTextBackgroundView = [[UIView alloc] initWithFrame:self.messageTextView.frame];
                messageTextBackgroundView.backgroundColor = [UIColor clearColor];
                [self.contentView insertSubview:messageTextBackgroundView belowSubview:self.messageTextView];
                messageTextBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
                [messageTextBackgroundView.leftAnchor constraintEqualToAnchor:self.messageTextView.leftAnchor].active = YES;
                [messageTextBackgroundView.rightAnchor constraintEqualToAnchor:self.messageTextView.rightAnchor].active = YES;
                [messageTextBackgroundView.topAnchor constraintEqualToAnchor:self.messageTextView.topAnchor].active = YES;
                [messageTextBackgroundView.bottomAnchor constraintEqualToAnchor:self.messageTextView.bottomAnchor].active = YES;
                
                [messageTextBackgroundView addGestureRecognizer:longPress];
                
                self.messageTextBackgroundView = messageTextBackgroundView;
            }
            else
            {
                [self.messageTextView addGestureRecognizer:longPress];
            }
        }
    }
    
    if (self.playIconView)
    {
        self.playIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"play"];
    }
    
    if (self.bubbleOverlayContainer)
    {
        // Add tap recognizer on overlay container
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onOverlayTap:)];
        [tapGesture setNumberOfTouchesRequired:1];
        [tapGesture setNumberOfTapsRequired:1];
        [tapGesture setDelegate:self];
        [self.bubbleOverlayContainer addGestureRecognizer:tapGesture];
    }
    
    // Listen to content view tap by default
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onContentViewTap:)];
    [tapGesture setNumberOfTouchesRequired:1];
    [tapGesture setNumberOfTapsRequired:1];
    [tapGesture setDelegate:self];
    [self.contentView addGestureRecognizer:tapGesture];
    
    if (_disableLongPressGestureOnEvent == NO)
    {
        // Add a long gesture recognizer on text view (in order to display for example the event details)
        UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
        longPressGestureRecognizer.delegate = self;
        [self.contentView addGestureRecognizer:longPressGestureRecognizer];
    }
    
    [self setupConstraintsConstantDefaultValues];
}

- (void)customizeTableViewCellRendering
{
    [super customizeTableViewCellRendering];
    
    // Clear the default background color of a MXKImageView instance
    self.pictureView.defaultBackgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.pictureView)
    {
        // Round image view
        [self.pictureView.layer setCornerRadius:self.pictureView.frame.size.width / 2];
        self.pictureView.clipsToBounds = YES;
    }
}

/**
 Manually add a side border for HTML blockquotes.

 @discussion
 `NSAttributedString` and `UITextView` classes do not support it natively. This
 method add an `UIView` to the `UITextView` that implements this border.

 @param canRetry YES if the method can retry later if the UI is not yet ready.
 */
- (void)fixHTMLBlockQuoteRendering:(BOOL)canRetry
{
    if (self.messageTextView && htmlBlockquoteSideBorderViews.count == 0)
    {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{

            if (weakSelf)
            {
                typeof(self) self = weakSelf;
                [MXKTools enumerateMarkedBlockquotesInAttributedString:self.messageTextView.attributedText
                                                            usingBlock:^(NSRange range, BOOL *stop)
                 {
                     // Compute the UITextRange of the blockquote
                     UITextPosition *beginning = self.messageTextView.beginningOfDocument;
                     UITextPosition *start = [self.messageTextView positionFromPosition:beginning offset:range.location];
                     UITextPosition *end = [self.messageTextView positionFromPosition:start offset:range.length];
                     UITextRange *textRange = [self.messageTextView textRangeFromPosition:start toPosition:end];

                     // Get the rect area of this blockquote within the cell
                     // There can be several rects in case of multilines. Hence, the merge
                     NSArray<UITextSelectionRect*> *array = [self.messageTextView selectionRectsForRange:textRange];
                     CGRect textRect = CGRectNull;
                     for (UITextSelectionRect *rect in array)
                     {
                         if (rect.rect.size.width)
                         {
                             textRect = CGRectUnion(textRect, rect.rect);
                         }
                     }

                     if (!CGRectIsNull(textRect))
                     {
                         // Add a left border with a height that covers all the blockquote block height
                         // TODO: Manage RTL language
                         UIView *sideBorderView = [[UIView alloc] initWithFrame:CGRectMake(5, textRect.origin.y, 4, textRect.size.height)];
                         sideBorderView.backgroundColor = self.bubbleData.eventFormatter.htmlBlockquoteBorderColor;
                         [sideBorderView setTranslatesAutoresizingMaskIntoConstraints:NO];
                         
                         [self.messageTextView addSubview:sideBorderView];

                         if (!self->htmlBlockquoteSideBorderViews)
                         {
                             self->htmlBlockquoteSideBorderViews = [NSMutableArray array];
                         }

                         [self->htmlBlockquoteSideBorderViews addObject:sideBorderView];
                     }
                     else if (canRetry)
                     {
                         // Have not found rect area that corresponds to the blockquote
                         // Try again later when the UI is more ready. Try it only once
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             [self fixHTMLBlockQuoteRendering:NO];
                         });
                     }
                 }];
            }
        });
    }
}

- (void)dealloc
{
    // remove any pending observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setIsAutoAnimatedGif:(BOOL)isAutoAnimatedGif
{
    _isAutoAnimatedGif = isAutoAnimatedGif;
    
    [self renderGif];
}

- (void)setAllTextHighlighted:(BOOL)allTextHighlighted
{
    _allTextHighlighted = allTextHighlighted;
    
    if (self.messageTextView && bubbleData.textMessage.length != 0)
    {
        if (_allTextHighlighted)
        {
            NSMutableAttributedString *highlightedString = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
            UIColor *color = self.tintColor ? self.tintColor : [UIColor lightGrayColor];
            [highlightedString addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange(0, highlightedString.length)];
            self.messageTextView.attributedText = highlightedString;
        }
        else
        {
            self.messageTextView.attributedText = bubbleData.attributedTextMessage;
        }
    }
}

- (void)highlightTextMessageForEvent:(NSString*)eventId
{
    if (self.messageTextView)
    {
        if (eventId.length)
        {
            self.messageTextView.attributedText = [bubbleData attributedTextMessageWithHighlightedEvent:eventId tintColor:self.tintColor];
        }
        else
        {
            // Restore original string
            self.messageTextView.attributedText = bubbleData.attributedTextMessage;
        }
    }
}

- (CGFloat)topPositionOfEvent:(NSString*)eventId
{
    CGFloat topPositionOfEvent = 0;

    // Retrieve the component that hosts the event
    MXKRoomBubbleComponent *theComponent;
    for (MXKRoomBubbleComponent *component in bubbleData.bubbleComponents)
    {
        if ([component.event.eventId isEqualToString:eventId])
        {
            theComponent = component;
            break;
        }
    }

    if (theComponent)
    {
        topPositionOfEvent = theComponent.position.y + self.msgTextViewTopConstraint.constant;
    }
    return topPositionOfEvent;
}

- (CGFloat)bottomPositionOfEvent:(NSString*)eventId
{
    CGFloat bottomPositionOfEvent = self.frame.size.height - self.msgTextViewBottomConstraint.constant;
    
    // Parse each component by the end of the array in order to compute the bottom position.
    NSArray *bubbleComponents = bubbleData.bubbleComponents;
    NSInteger index = bubbleComponents.count;
    
    while (index --)
    {
        MXKRoomBubbleComponent *component = bubbleComponents[index];
        if ([component.event.eventId isEqualToString:eventId])
        {
            break;
        }
        else
        {
            // Update the bottom position
            bottomPositionOfEvent = component.position.y + self.msgTextViewTopConstraint.constant;
        }
    }
    return bottomPositionOfEvent;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (void)render:(MXKCellData *)cellData
{
    [self prepareRender:cellData];
    
    if (bubbleData)
    {
        // Check conditions to display the message sender name
        if (self.userNameLabel)
        {
            // Display sender's name except if the name appears in the displayed text (see emote and membership events)
            if (bubbleData.shouldHideSenderName == NO)
            {
                if (bubbleData.senderFlair)
                {
                    [self renderSenderFlair];
                }
                else
                {
                    self.userNameLabel.text = bubbleData.senderDisplayName;
                }
                
                
                self.userNameLabel.hidden = NO;
                self.userNameTapGestureMaskView.userInteractionEnabled = YES;
            }
            else
            {
                self.userNameLabel.hidden = YES;
                self.userNameTapGestureMaskView.userInteractionEnabled = NO;
            }
        }
        
        // Check whether the sender's picture is actually displayed before loading it.
        if (self.pictureView)
        {
            self.pictureView.enableInMemoryCache = YES;
            // Consider here the sender avatar is stored unencrypted on Matrix media repo
            [self.pictureView setImageURI:bubbleData.senderAvatarUrl
                                 withType:nil
                      andImageOrientation:UIImageOrientationUp
                            toFitViewSize:self.pictureView.frame.size
                               withMethod:MXThumbnailingMethodCrop
                             previewImage:bubbleData.senderAvatarPlaceholder ? bubbleData.senderAvatarPlaceholder : self.picturePlaceholder
                             mediaManager:bubbleData.mxSession.mediaManager];
        }
        
        if (self.attachmentView && bubbleData.isAttachmentWithThumbnail)
        {
            // Set attached media folders
            self.attachmentView.mediaFolder = bubbleData.roomId;
            
            self.attachmentView.backgroundColor = [UIColor clearColor];
            
            // Retrieve the suitable content size for the attachment thumbnail
            CGSize contentSize = bubbleData.contentSize;
            
            // Update image view frame in order to center loading wheel (if any)
            CGRect frame = self.attachmentView.frame;
            frame.size.width = contentSize.width;
            frame.size.height = contentSize.height;
            self.attachmentView.frame = frame;
            
            // Set play icon visibility
            self.playIconView.hidden = (bubbleData.attachment.type != MXKAttachmentTypeVideo);
            
            // Hide by default file type icon
            self.fileTypeIconView.hidden = YES;
            
            // Display the attachment thumbnail
            [self.attachmentView setAttachmentThumb:bubbleData.attachment];
            
            if (bubbleData.attachment.contentURL)
            {
                // Add tap recognizer to open attachment
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onAttachmentTap:)];
                [tap setNumberOfTouchesRequired:1];
                [tap setNumberOfTapsRequired:1];
                [tap setDelegate:self];
                [self.attachmentView addGestureRecognizer:tap];
            }
            
            [self startProgressUI];
            
            // Adjust Attachment width constant
            self.attachViewWidthConstraint.constant = contentSize.width;
            
            // Add a long gesture recognizer on progressView to cancel the current operation (Note: only the download can be cancelled).
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
            [self.progressView addGestureRecognizer:longPress];
            
            if (_disableLongPressGestureOnEvent == NO)
            {
                // Add a long gesture recognizer on attachment view in order to display for example the event details
                longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGesture:)];
                [self.attachmentView addGestureRecognizer:longPress];
            }
            
            // Handle here the case of the attached gif
            [self renderGif];
        }
        else if (self.messageTextView)
        {
            // Compute message content size
            bubbleData.maxTextViewWidth = self.frame.size.width - (self.msgTextViewLeadingConstraint.constant + self.msgTextViewTrailingConstraint.constant);
            CGSize contentSize = bubbleData.contentSize;
            
            // Prepare displayed text message
            NSAttributedString* newText = nil;
            
            // Underline attached file name
            if (self.isBubbleDataContainsFileAttachment)
            {
                NSMutableAttributedString *updatedText = [[NSMutableAttributedString alloc] initWithAttributedString:bubbleData.attributedTextMessage];
                [updatedText addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInteger:NSUnderlineStyleSingle] range:NSMakeRange(0, updatedText.length)];
                
                newText = updatedText;
            }
            else
            {
                newText = bubbleData.attributedTextMessage;
            }
            
            // update the text only if it is required
            // updating a text is quite long (even with the same text).
            if (![self.messageTextView.attributedText isEqualToAttributedString:newText])
            {
                self.messageTextView.attributedText = newText;

                if (bubbleData.displayFix & MXKRoomBubbleComponentDisplayFixHtmlBlockquote)
                {
                    [self fixHTMLBlockQuoteRendering:YES];
                }
            }
            
            // Update msgTextView width constraint to align correctly the text
            if (self.msgTextViewWidthConstraint.constant != contentSize.width)
            {
                self.msgTextViewWidthConstraint.constant = contentSize.width;
            }
        }
        
        // Check and update each component position (used to align timestamps label in front of events, and to handle tap gesture on events)
        [bubbleData prepareBubbleComponentsPosition];
        
        // Handle here timestamp display (only if a container has been defined)
        if (self.bubbleInfoContainer)
        {
            if ((bubbleData.showBubbleDateTime && !bubbleData.useCustomDateTimeLabel)
                || (bubbleData.showBubbleReceipts && !bubbleData.useCustomReceipts))
            {
                // Add datetime label for each component
                self.bubbleInfoContainer.hidden = NO;
                
                // ensure that older subviews are removed
                // They should be (they are removed when the is not anymore used).
                // But, it seems that is not always true.
                NSArray* views = [self.bubbleInfoContainer subviews];
                for(UIView* view in views)
                {
                    [view removeFromSuperview];
                }
                
                for (MXKRoomBubbleComponent *component in bubbleData.bubbleComponents)
                {
                    if (component.event.sentState != MXEventSentStateFailed)
                    {
                        CGFloat timeLabelOffset = 0;
                        
                        if (component.date && bubbleData.showBubbleDateTime && !bubbleData.useCustomDateTimeLabel)
                        {
                            UILabel *dateTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, component.position.y, self.bubbleInfoContainer.frame.size.width , 15)];
                            
                            dateTimeLabel.text = [bubbleData.eventFormatter dateStringFromDate:component.date withTime:YES];
                            if (bubbleData.isIncoming)
                            {
                                dateTimeLabel.textAlignment = NSTextAlignmentRight;
                            }
                            else
                            {
                                dateTimeLabel.textAlignment = NSTextAlignmentLeft;
                            }
                            dateTimeLabel.textColor = [UIColor lightGrayColor];
                            dateTimeLabel.font = [UIFont systemFontOfSize:11];
                            dateTimeLabel.adjustsFontSizeToFitWidth = YES;
                            dateTimeLabel.minimumScaleFactor = 0.6;
                            
                            [dateTimeLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
                            [self.bubbleInfoContainer addSubview:dateTimeLabel];
                            // Force dateTimeLabel in full width (to handle auto-layout in case of screen rotation)
                            NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                              attribute:NSLayoutAttributeLeading
                                                                                              relatedBy:NSLayoutRelationEqual
                                                                                                 toItem:self.bubbleInfoContainer
                                                                                              attribute:NSLayoutAttributeLeading
                                                                                             multiplier:1.0
                                                                                               constant:0];
                            NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                               attribute:NSLayoutAttributeTrailing
                                                                                               relatedBy:NSLayoutRelationEqual
                                                                                                  toItem:self.bubbleInfoContainer
                                                                                               attribute:NSLayoutAttributeTrailing
                                                                                              multiplier:1.0
                                                                                                constant:0];
                            // Vertical constraints are required for iOS > 8
                            NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                             attribute:NSLayoutAttributeTop
                                                                                             relatedBy:NSLayoutRelationEqual
                                                                                                toItem:self.bubbleInfoContainer
                                                                                             attribute:NSLayoutAttributeTop
                                                                                            multiplier:1.0
                                                                                              constant:component.position.y];
                            NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:dateTimeLabel
                                                                                                attribute:NSLayoutAttributeHeight
                                                                                                relatedBy:NSLayoutRelationEqual
                                                                                                   toItem:nil
                                                                                                attribute:NSLayoutAttributeNotAnAttribute
                                                                                               multiplier:1.0
                                                                                                 constant:15];
                            if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
                            {
                                [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, heightConstraint]];
                            }
                            else
                            {
                                [self.bubbleInfoContainer addConstraint:leftConstraint];
                                [self.bubbleInfoContainer addConstraint:rightConstraint];
                                [self.bubbleInfoContainer addConstraint:topConstraint];
                                [dateTimeLabel addConstraint:heightConstraint];
                            }
                            
                            timeLabelOffset += 15;
                        }
                        
                        if (bubbleData.showBubbleReceipts && !bubbleData.useCustomReceipts)
                        {
                            NSMutableArray* roomMembers = nil;
                            NSMutableArray* placeholders = nil;
                            NSArray<MXReceiptData*> *receipts = bubbleData.readReceipts[component.event.eventId];
                            
                            // Check whether some receipts are found
                            if (receipts.count)
                            {
                                MXRoom* room = [bubbleData.mxSession roomWithRoomId:bubbleData.roomId];
                                if (room)
                                {
                                    // Retrieve the corresponding room members
                                    roomMembers = [[NSMutableArray alloc] initWithCapacity:receipts.count];
                                    placeholders = [[NSMutableArray alloc] initWithCapacity:receipts.count];

                                    MXRoomMembers *stateRoomMembers = room.dangerousSyncState.members;
                                    for (MXReceiptData* data in receipts)
                                    {
                                        MXRoomMember * roomMember = [stateRoomMembers memberWithUserId:data.userId];
                                        if (roomMember)
                                        {
                                            [roomMembers addObject:roomMember];
                                            [placeholders addObject:self.picturePlaceholder];
                                        }
                                    }
                                }
                            }
                            
                            if (roomMembers.count)
                            {
                                MXKReceiptSendersContainer* avatarsContainer = [[MXKReceiptSendersContainer alloc] initWithFrame:CGRectMake(0, component.position.y + timeLabelOffset, self.bubbleInfoContainer.frame.size.width , 15) andMediaManager:bubbleData.mxSession.mediaManager];
                                
                                [avatarsContainer refreshReceiptSenders:roomMembers withPlaceHolders:placeholders andAlignment:self.readReceiptsAlignment];
                                
                                [self.bubbleInfoContainer addSubview:avatarsContainer];
                                
                                // Force dateTimeLabel in full width (to handle auto-layout in case of screen rotation)
                                NSLayoutConstraint *leftConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                  attribute:NSLayoutAttributeLeading
                                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                                     toItem:self.bubbleInfoContainer
                                                                                                  attribute:NSLayoutAttributeLeading
                                                                                                 multiplier:1.0
                                                                                                   constant:0];
                                NSLayoutConstraint *rightConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                   attribute:NSLayoutAttributeTrailing
                                                                                                   relatedBy:NSLayoutRelationEqual
                                                                                                      toItem:self.bubbleInfoContainer
                                                                                                   attribute:NSLayoutAttributeTrailing
                                                                                                  multiplier:1.0
                                                                                                    constant:0];
                                // Vertical constraints are required for iOS > 8
                                NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                 attribute:NSLayoutAttributeTop
                                                                                                 relatedBy:NSLayoutRelationEqual
                                                                                                    toItem:self.bubbleInfoContainer
                                                                                                 attribute:NSLayoutAttributeTop
                                                                                                multiplier:1.0
                                                                                                  constant:(component.position.y + timeLabelOffset)];
                                
                                NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:avatarsContainer
                                                                                                    attribute:NSLayoutAttributeHeight
                                                                                                    relatedBy:NSLayoutRelationEqual
                                                                                                       toItem:nil
                                                                                                    attribute:NSLayoutAttributeNotAnAttribute
                                                                                                   multiplier:1.0
                                                                                                     constant:15];
                                
                                if ([NSLayoutConstraint respondsToSelector:@selector(activateConstraints:)])
                                {
                                    [NSLayoutConstraint activateConstraints:@[leftConstraint, rightConstraint, topConstraint, heightConstraint]];
                                }
                                else
                                {
                                    [self.bubbleInfoContainer addConstraint:leftConstraint];
                                    [self.bubbleInfoContainer addConstraint:rightConstraint];
                                    [self.bubbleInfoContainer addConstraint:topConstraint];
                                    [avatarsContainer addConstraint:heightConstraint];
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                self.bubbleInfoContainer.hidden = YES;
            }
        }
    }
}

- (void)prepareRender:(MXKCellData *)cellData
{
    // Sanity check: accept only object of MXKRoomBubbleCellData classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKRoomBubbleCellData class]]);
    
    bubbleData = (MXKRoomBubbleCellData*)cellData;
    mxkCellData = cellData;
}

- (void)renderSenderFlair
{
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@  ", bubbleData.senderDisplayName]];
    
    NSUInteger index = 0;
    
    for (MXGroup *group in bubbleData.senderFlair)
    {
        NSString *mxcAvatarURI = group.profile.avatarUrl;
        NSString *cacheFilePath = [MXMediaManager thumbnailCachePathForMatrixContentURI:mxcAvatarURI andType:@"image/jpeg" inFolder:kMXMediaManagerDefaultCacheFolder toFitViewSize:CGSizeMake(12, 12) withMethod:MXThumbnailingMethodCrop];
        
        // Check whether the avatar url is valid
        if (cacheFilePath)
        {
            UIImage *image = [MXMediaManager loadThroughCacheWithFilePath:cacheFilePath];
            if (image)
            {
                NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
                textAttachment.image = [MXKTools resizeImageWithRoundedCorners:image toSize:CGSizeMake(12, 12)];
                NSAttributedString *attrStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachment];
                [attributedString appendAttributedString:attrStringWithImage];
                [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
            }
            else
            {
                NSString *downloadId = [MXMediaManager thumbnailDownloadIdForMatrixContentURI:mxcAvatarURI
                                                                                     inFolder:kMXMediaManagerDefaultCacheFolder
                                                                                toFitViewSize:CGSizeMake(12, 12)
                                                                                   withMethod:MXThumbnailingMethodCrop];
                // Check whether the download is in progress.
                MXMediaLoader* loader = [MXMediaManager existingDownloaderWithIdentifier:downloadId];
                if (loader)
                {
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:loader];
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onFlairDownloadStateChange:) name:kMXMediaLoaderStateDidChangeNotification object:loader];
                }
                else
                {
                    MXWeakify(self);
                    [bubbleData.mxSession.mediaManager downloadThumbnailFromMatrixContentURI:mxcAvatarURI
                                                                                    withType:@"image/jpeg"
                                                                                    inFolder:kMXMediaManagerDefaultCacheFolder
                                                                               toFitViewSize:CGSizeMake(12, 12)
                                                                                  withMethod:MXThumbnailingMethodCrop
                                                                                     success:^(NSString *outputFilePath) {
                                                                                         // Refresh sender flair
                                                                                         MXStrongifyAndReturnIfNil(self);
                                                                                         [self renderSenderFlair];
                                                                                     }
                                                                                     failure:nil];
                }
            }
            
            index++;
            if (index == 3)
            {
                if (bubbleData.senderFlair.count > 3)
                {
                    NSAttributedString *more = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"+%tu", (bubbleData.senderFlair.count - 3)] attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11.0], NSBaselineOffsetAttributeName:@(+2)}];
                    [attributedString appendAttributedString:more];
                }
                break;
            }
        }
    }
    
    self.userNameLabel.attributedText = attributedString;
}

- (void)renderGif
{
    if (self.attachmentView && bubbleData.attachment)
    {
        NSString *mimetype = nil;
        if (bubbleData.attachment.thumbnailInfo)
        {
            mimetype = bubbleData.attachment.thumbnailInfo[@"mimetype"];
        }
        else if (bubbleData.attachment.contentInfo)
        {
            mimetype = bubbleData.attachment.contentInfo[@"mimetype"];
        }
        
        if ([mimetype isEqualToString:@"image/gif"])
        {
            if (_isAutoAnimatedGif)
            {
                // Hide the file type icon, and the progress UI
                self.fileTypeIconView.hidden = YES;
                [self stopProgressUI];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:nil];
                
                // Animated gif is displayed in a webview added on the attachment view
                self.attachmentWebView = [[WKWebView alloc] initWithFrame:self.attachmentView.bounds];
                self.attachmentWebView.opaque = NO;
                self.attachmentWebView.backgroundColor = [UIColor clearColor];
                self.attachmentWebView.contentMode = UIViewContentModeScaleAspectFit;
                self.attachmentWebView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
                self.attachmentWebView.userInteractionEnabled = NO;
                self.attachmentWebView.hidden = YES;
                [self.attachmentView addSubview:self.attachmentWebView];
                
                __weak WKWebView *weakAnimatedGifViewer = self.attachmentWebView;
                __weak typeof(self) weakSelf = self;
                
                void (^onDownloaded)(NSData *) = ^(NSData *data){
                    
                    if (weakAnimatedGifViewer && weakAnimatedGifViewer.superview)
                    {
                        WKWebView *strongAnimatedGifViewer = weakAnimatedGifViewer;
                        strongAnimatedGifViewer.navigationDelegate = weakSelf;
                        [strongAnimatedGifViewer loadData:data MIMEType:@"image/gif" characterEncodingName:@"UTF-8" baseURL:[NSURL URLWithString:@"http://"]];
                    }
                };
                
                void (^onFailure)(NSError *) = ^(NSError *error){
                    
                    NSLog(@"[MXKRoomBubbleTableViewCell] gif download failed");
                    // Notify the end user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                };
                
                [bubbleData.attachment getAttachmentData:^(NSData *data) {
                    onDownloaded(data);
                } failure:^(NSError *error) {
                    onFailure(error);
                }];
            }
            else
            {
                self.fileTypeIconView.image = [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"filetype-gif"];
                self.fileTypeIconView.hidden = NO;
                
                // Check whether a download is in progress
                [self startProgressUI];
            }
        }
    }
}

+ (CGFloat)heightForCellData:(MXKCellData*)cellData withMaximumWidth:(CGFloat)maxWidth
{
    // Sanity check: accept only object of MXKRoomBubbleCellData classes or sub-classes
    NSParameterAssert([cellData isKindOfClass:[MXKRoomBubbleCellData class]]);
    
    MXKRoomBubbleCellData *bubbleData = (MXKRoomBubbleCellData*)cellData;
    MXKRoomBubbleTableViewCell* cell = [self cellWithOriginalXib];
    CGFloat rowHeight = cell.frame.size.height;
    
    if (cell.attachmentView && bubbleData.isAttachmentWithThumbnail)
    {
        // retrieve the suggested image view height
        rowHeight = bubbleData.contentSize.height;
        
        // Check here the minimum height defined in cell view for text message
        if (cell.attachViewMinHeightConstraint && rowHeight < cell.attachViewMinHeightConstraint.constant)
        {
            rowHeight = cell.attachViewMinHeightConstraint.constant;
        }
        
        // Finalize the row height by adding the vertical constraints.
        rowHeight += cell.attachViewTopConstraint.constant + cell.attachViewBottomConstraint.constant;
    }
    else if (cell.messageTextView)
    {
        // Update maximum width available for the textview // (RiotSettings.shared.bubbleStyle
        if (MXKAppSettings.standardAppSettings.isBubbleStyle) {
            if (bubbleData.isIncoming) {
                bubbleData.maxTextViewWidth = maxWidth - (cell.msgTextViewLeadingConstraint.constant + 83 + 5);
            } else {
                bubbleData.maxTextViewWidth = maxWidth - (cell.msgTextViewTrailingConstraint.constant + 93 + 5);
            }
        } else {
            bubbleData.maxTextViewWidth = maxWidth - (cell.msgTextViewLeadingConstraint.constant + cell.msgTextViewTrailingConstraint.constant);

        }
        // Retrieve the suggested height of the message content
        rowHeight = bubbleData.contentSize.height;
        
        // Consider here the minimum height defined in cell view for text message
        if (cell.msgTextViewMinHeightConstraint && rowHeight < cell.msgTextViewMinHeightConstraint.constant)
        {
            rowHeight = cell.msgTextViewMinHeightConstraint.constant;
        }
        
        // Finalize the row height by adding the top and bottom constraints of the message text view in cell
        rowHeight += cell.msgTextViewTopConstraint.constant + cell.msgTextViewBottomConstraint.constant + 6;
    }
    
    return rowHeight;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [self didEndDisplay];
}

- (void)didEndDisplay
{
    bubbleData = nil;

    for (UIView *sideBorder in htmlBlockquoteSideBorderViews)
    {
        [sideBorder removeFromSuperview];
    }
    [htmlBlockquoteSideBorderViews removeAllObjects];
    htmlBlockquoteSideBorderViews = nil;

    if (_attachmentWebView)
    {
        [_attachmentWebView removeFromSuperview];
        _attachmentWebView.navigationDelegate = nil;
        _attachmentWebView = nil;
    }
    
    if (_readMarkerView)
    {
        [_readMarkerView removeFromSuperview];
        _readMarkerView = nil;
        _readMarkerViewTopConstraint = nil;
        _readMarkerViewLeadingConstraint = nil;
        _readMarkerViewTrailingConstraint = nil;
        _readMarkerViewHeightConstraint = nil;
    }
    
    if (self.attachmentView)
    {
        // Remove all gesture recognizer
        while (self.attachmentView.gestureRecognizers.count)
        {
            [self.attachmentView removeGestureRecognizer:self.attachmentView.gestureRecognizers[0]];
        }
        
        // Prevent the cell from displaying again the image in case of reuse.
        self.attachmentView.image = nil;
    }
    
    // Remove potential dateTime (or unsent) label(s)
    if (self.bubbleInfoContainer && self.bubbleInfoContainer.subviews.count > 0)
    {
        NSArray* subviews = self.bubbleInfoContainer.subviews;
             
        for (UIView *view in subviews)
        {
            [view removeFromSuperview];
        }
    }
    self.bubbleInfoContainer.hidden = YES;
    
    // Remove temporary subviews
    if (self.tmpSubviews)
    {
        for (UIView *view in self.tmpSubviews)
        {
            [view removeFromSuperview];
        }
        self.tmpSubviews = nil;
    }
    
    // Remove potential overlay subviews
    if (self.bubbleOverlayContainer)
    {
        NSArray* subviews = self.bubbleOverlayContainer.subviews;
        
        for (UIView *view in subviews)
        {
            [view removeFromSuperview];
        }
        
        self.bubbleOverlayContainer.hidden = YES;
    }
    
    if (self.progressView)
    {
        [self stopProgressUI];
        
        // Remove long tap gesture on the progressView
        while (self.progressView.gestureRecognizers.count)
        {
            [self.progressView removeGestureRecognizer:self.progressView.gestureRecognizers[0]];
        }
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    delegate = nil;
    
    self.readReceiptsAlignment = ReadReceiptAlignmentLeft;
    _allTextHighlighted = NO;
    _isAutoAnimatedGif = NO;
    
    [self resetConstraintsConstantToDefault];
    
    if (_temperaryContentViewConstraints) {
        [self.contentView removeConstraints:_temperaryContentViewConstraints];
        [_temperaryContentViewConstraints removeAllObjects];
    }
}

- (BOOL)shouldInteractWithURL:(NSURL *)URL urlItemInteraction:(UITextItemInteraction)urlItemInteraction associatedEvent:(MXEvent*)associatedEvent
API_AVAILABLE(ios(10.0)) {
    return [self shouldInteractWithURL:URL urlItemInteractionValue:@(urlItemInteraction) associatedEvent:associatedEvent];
}

- (BOOL)shouldInteractWithURL:(NSURL *)URL urlItemInteractionValue:(NSNumber*)urlItemInteractionValue associatedEvent:(MXEvent*)associatedEvent
{    
    NSMutableDictionary *userInfo = [@{
                               kMXKRoomBubbleCellUrl:URL,
                               kMXKRoomBubbleCellUrlItemInteraction:urlItemInteractionValue
                               } mutableCopy];
    
    if (associatedEvent)
    {
        userInfo[kMXKRoomBubbleCellEventKey] = associatedEvent;
    }
    
    return [delegate cell:self shouldDoAction:kMXKRoomBubbleCellShouldInteractWithURL userInfo:userInfo defaultValue:YES];
}

- (BOOL)isBubbleDataContainsFileAttachment
{
    return bubbleData.attachment
    && (bubbleData.attachment.type == MXKAttachmentTypeFile || bubbleData.attachment.type == MXKAttachmentTypeAudio)
    && bubbleData.attachment.contentURL
    && bubbleData.attachment.contentInfo;
}

- (MXKRoomBubbleComponent*)closestBubbleComponentForGestureRecognizer:(UIGestureRecognizer*)gestureRecognizer locationInView:(UIView*)view
{
    CGPoint tapPoint = [gestureRecognizer locationInView:view];
    MXKRoomBubbleComponent *tappedComponent;
    
    if (tapPoint.y >= 0 && tapPoint.y <= view.frame.size.height)
    {
        tappedComponent = [self closestBubbleComponentAtPosition:tapPoint];
    }
    
    return tappedComponent;
}

- (MXKRoomBubbleComponent*)closestBubbleComponentAtPosition:(CGPoint)position
{
    MXKRoomBubbleComponent *tappedComponent;
    
    NSArray *bubbleComponents = bubbleData.bubbleComponents;
    
    for (MXKRoomBubbleComponent *component in bubbleComponents)
    {
        // Ignore components without display (For example redacted event or state events)
        if (!component.attributedTextMessage)
        {
            continue;
        }
        
        if (component.position.y > position.y)
        {
            break;
        }
        
        tappedComponent = component;
    }
    
    return tappedComponent;
}

- (void)setupConstraintsConstantDefaultValues
{
    self.attachmentViewBottomConstraintDefaultConstant = self.attachViewBottomConstraint.constant;
}

- (void)resetAttachmentViewBottomConstraintConstant
{
    self.attachViewBottomConstraint.constant = self.attachmentViewBottomConstraintDefaultConstant;
}

- (void)resetConstraintsConstantToDefault
{
    [self resetAttachmentViewBottomConstraintConstant];
}

#pragma mark - Attachment progress handling

- (void)updateProgressUI:(NSDictionary*)statisticsDict
{
    self.progressView.hidden = !statisticsDict;
    
    NSNumber* downloadRate = [statisticsDict valueForKey:kMXMediaLoaderCurrentDataRateKey];
    
    NSNumber* completedBytesCount = [statisticsDict valueForKey:kMXMediaLoaderCompletedBytesCountKey];
    NSNumber* totalBytesCount = [statisticsDict valueForKey:kMXMediaLoaderTotalBytesCountKey];
    
    NSMutableString* text = [[NSMutableString alloc] init];
    
    if (completedBytesCount && totalBytesCount)
    {
        NSString* progressString = [NSString stringWithFormat:@"%@ / %@", [NSByteCountFormatter stringFromByteCount:completedBytesCount.longLongValue countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalBytesCount.longLongValue countStyle:NSByteCountFormatterCountStyleFile]];
        
        [text appendString:progressString];
    }
    
    if (downloadRate && downloadRate.longLongValue)
    {
        [text appendFormat:@"\n%@/s", [NSByteCountFormatter stringFromByteCount:downloadRate.longLongValue countStyle:NSByteCountFormatterCountStyleFile]];
        
        if (completedBytesCount && totalBytesCount)
        {
            CGFloat remainimgTime = ((totalBytesCount.floatValue - completedBytesCount.floatValue)) / downloadRate.floatValue;
            [text appendFormat:@"\n%@", [MXKTools formatSecondsInterval:remainimgTime]];
        }
    }
    
    self.statsLabel.text = text;
    
    NSNumber* progressNumber = [statisticsDict valueForKey:kMXMediaLoaderProgressValueKey];
    
    if (progressNumber)
    {
        self.progressChartView.progress = progressNumber.floatValue;
    }
}

- (void)onAttachmentLoaderStateChange:(NSNotification *)notif
{
    MXMediaLoader *loader = (MXMediaLoader*)notif.object;
    switch (loader.state) {
        case MXMediaLoaderStateDownloadInProgress:
            [self updateProgressUI:loader.statisticsDict];
            break;
        case MXMediaLoaderStateDownloadCompleted:
        case MXMediaLoaderStateDownloadFailed:
        case MXMediaLoaderStateCancelled:
            [self stopProgressUI];
            // remove the observer
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:loader];
            break;
        default:
            break;
    }
}

- (void)onFlairDownloadStateChange:(NSNotification *)notif
{
    MXMediaLoader *loader = (MXMediaLoader*)notif.object;
    switch (loader.state) {
        case MXMediaLoaderStateDownloadCompleted:
            [self renderSenderFlair];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:loader];
            break;
        case MXMediaLoaderStateDownloadFailed:
        case MXMediaLoaderStateCancelled:
            [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:loader];
            break;
        default:
            break;
    }
}

- (void)startProgressUI
{
    self.progressView.hidden = YES;
    
    // there is an attachment URL
    if (bubbleData.attachment.contentURL)
    {
        // remove any pending observers
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kMXMediaLoaderStateDidChangeNotification object:nil];
        
        // check if there is a download in progress
        MXMediaLoader *loader = [MXMediaManager existingDownloaderWithIdentifier:bubbleData.attachment.downloadId];
        if (loader)
        {
            // defines the text to display
            [self updateProgressUI:loader.statisticsDict];
            
            // anyway listen to the progress event
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onAttachmentLoaderStateChange:)
                                                         name:kMXMediaLoaderStateDidChangeNotification
                                                       object:loader];
        }
    }
}

- (void)stopProgressUI
{
    self.progressView.hidden = YES;
    
    // do not remove the observer here
    // the download could restart without recomposing the cell
}

#pragma mark - Original Xib values

/**
 `childClasses` hosts one instance of each child classes of `MXKRoomBubbleTableViewCell`.
 The key is the child class name. The value, the instance.
 */
static NSMutableDictionary *childClasses;

+ (MXKRoomBubbleTableViewCell*)cellWithOriginalXib
{
    MXKRoomBubbleTableViewCell *cellWithOriginalXib;
    
    @synchronized(self)
    {
        if (childClasses == nil)
        {
            childClasses = [NSMutableDictionary dictionary];
        }
        
        // To save memory, use only one original instance per child class
        cellWithOriginalXib = childClasses[NSStringFromClass(self.class)];
        if (nil == cellWithOriginalXib)
        {
            cellWithOriginalXib = [self roomBubbleTableViewCell];
            
            childClasses[NSStringFromClass(self.class)] = cellWithOriginalXib;
        }
    }
    return cellWithOriginalXib;
}

#pragma mark - User actions

- (IBAction)onMessageTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        // Check whether the current displayed text corresponds to an attached file
        // NOTE: This assumes that a cell with attachment has only one `MXKRoomBubbleComponent`
        if (self.isBubbleDataContainsFileAttachment)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAttachmentView userInfo:nil];
        }
        else
        {
            NSURL *tappedUrl;
            
            // Hyperlinks in UITextView does not respond instantly to touch.
            // To overcome this, check manually if a link has been touched in UITextView when performing a quick tap.
            // Otherwise UITextViewDelegate method `- (BOOL)textView:shouldInteractWithURL:inRange:interaction:` is still called for long press and force touch.
            if ([sender.view isEqual:self.messageTextView])
            {
                UITextView *textView = self.messageTextView;
                CGPoint tapLocation = [sender locationInView:textView];
                UITextPosition *textPosition = [textView closestPositionToPoint:tapLocation];
                NSDictionary *attributes = [textView textStylingAtPosition:textPosition inDirection:UITextStorageDirectionForward];
                
                // The value of `NSLinkAttributeName` attribute could be an NSURL or an NSString object.
                id tappedURLObject = attributes[NSLinkAttributeName];
                
                if (tappedURLObject)
                {
                    if ([tappedURLObject isKindOfClass:[NSURL class]])
                    {
                        tappedUrl = (NSURL*)tappedURLObject;
                    }
                    else if ([tappedURLObject isKindOfClass:[NSString class]])
                    {
                        tappedUrl = [NSURL URLWithString:(NSString*)tappedURLObject];
                    }
                }
            }
            
            MXKRoomBubbleComponent *tappedComponent = [self closestBubbleComponentForGestureRecognizer:sender locationInView:sender.view];
            MXEvent *tappedEvent = tappedComponent.event;
            
            // If a link has been touched warn delegate immediately.
            if (tappedUrl)
            {
                // Send default URL interaction `UITextItemInteractionInvokeDefaultAction` for a quick tap as received by UITextViewDelegate method `- (BOOL)textView:shouldInteractWithURL:inRange:interaction:` for a tap.
                if (@available(iOS 10.0, *))
                {
                    [self shouldInteractWithURL:tappedUrl urlItemInteraction:UITextItemInteractionInvokeDefaultAction associatedEvent:tappedEvent];
                }
                else
                {
                    // Use UITextItemInteractionInvokeDefaultAction raw value for iOS 9
                    [self shouldInteractWithURL:tappedUrl urlItemInteractionValue:@(0) associatedEvent:tappedEvent];
                }
            }
            else
            {
                [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnMessageTextView userInfo:(tappedEvent ? @{kMXKRoomBubbleCellEventKey:tappedEvent} : nil)];
            }
        }
    }
}

- (IBAction)onSenderNameTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnSenderNameLabel userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
    }
}

- (IBAction)onAvatarTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAvatarView userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
    }
}

- (IBAction)onAttachmentTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAttachmentView userInfo:nil];
    }
}

- (IBAction)showHideDateTime:(id)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnDateTimeContainer userInfo:nil];
    }
}

- (IBAction)onOverlayTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnOverlayContainer userInfo:nil];
    }
}

- (IBAction)onContentViewTap:(UITapGestureRecognizer*)sender
{
    if (delegate)
    {
        // Check whether a bubble component is displayed at the level of the tapped line.
        MXKRoomBubbleComponent *tappedComponent = nil;
        
        if (self.attachmentView)
        {
            // Check whether the user tapped on the side of the attachment.
            tappedComponent = [self closestBubbleComponentForGestureRecognizer:sender locationInView:self.attachmentView];
        }
        else if (self.messageTextView)
        {
            // NOTE: A tap on messageTextView using `MXKMessageTextView` class fallback here if the user does not tap on a link.
            
            // Use the same hack as `onMessageTap:`, check whether the current displayed text corresponds to an attached file
            // NOTE: This assumes that a cell with attachment has only one `MXKRoomBubbleComponent`
            if (self.isBubbleDataContainsFileAttachment)
            {
                // This assume that an attachment use one cell in the application using MatrixKit
                // This condition is a fix to handle
                [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnAttachmentView userInfo:nil];
            }
            else
            {
                // Check whether the user tapped in front of a text component.
                tappedComponent = [self closestBubbleComponentForGestureRecognizer:sender locationInView:self.messageTextView];
            }
        }
        else
        {
            tappedComponent = [self.bubbleData getFirstBubbleComponentWithDisplay];
        }
        
        [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellTapOnContentView userInfo:(tappedComponent ? @{kMXKRoomBubbleCellEventKey:tappedComponent.event} : nil)];
    }
}

- (IBAction)onLongPressGesture:(UILongPressGestureRecognizer*)longPressGestureRecognizer
{
    if (longPressGestureRecognizer.state == UIGestureRecognizerStateBegan && delegate)
    {
        UIView* view = longPressGestureRecognizer.view;
        
        // Check the view on which long press has been detected
        if (view == self.progressView)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnProgressView userInfo:nil];
        }
        else if (view == self.messageTextView || view == self.messageTextBackgroundView || view == self.attachmentView)
        {
            MXKRoomBubbleComponent *tappedComponent = [self closestBubbleComponentForGestureRecognizer:longPressGestureRecognizer locationInView:view];
            MXEvent *selectedEvent = tappedComponent.event;
            
            if (selectedEvent)
            {
                [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnEvent userInfo:@{kMXKRoomBubbleCellEventKey:selectedEvent}];
            }
        }
        else if (view == self.pictureView)
        {
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnAvatarView userInfo:@{kMXKRoomBubbleCellUserIdKey: bubbleData.senderId}];
        }
        else if (view == self.contentView)
        {
            // Check whether a bubble component is displayed at the level of the tapped line.
            MXKRoomBubbleComponent *tappedComponent = nil;
            
            if (self.attachmentView)
            {
                // Check whether the user tapped on the side of the attachment.
                tappedComponent = [self closestBubbleComponentForGestureRecognizer:longPressGestureRecognizer locationInView:self.attachmentView];
            }
            else if (self.messageTextView)
            {
                // Check whether the user tapped in front of a text component.
                tappedComponent = [self closestBubbleComponentForGestureRecognizer:longPressGestureRecognizer locationInView:self.messageTextView];
            }
            else
            {
                tappedComponent = [self.bubbleData getFirstBubbleComponentWithDisplay];
            }
            
            [delegate cell:self didRecognizeAction:kMXKRoomBubbleCellLongPressOnEvent userInfo:(tappedComponent ? @{kMXKRoomBubbleCellEventKey:tappedComponent.event} : nil)];
        }
    }
}

#pragma mark - UITextView delegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange interaction:(UITextItemInteraction)interaction API_AVAILABLE(ios(10.0))
{
    BOOL shouldInteractWithURL = YES;
    
    if (delegate && URL)
    {
        MXEvent *associatedEvent;
        
        if ([textView isMemberOfClass:[MXKMessageTextView class]])
        {
            MXKMessageTextView *mxkMessageTextView = (MXKMessageTextView *)textView;
            MXKRoomBubbleComponent *bubbleComponent = [self closestBubbleComponentAtPosition:mxkMessageTextView.lastHitTestLocation];
            associatedEvent = bubbleComponent.event;
        }
        
        // Ask the delegate if iOS can open the link
        shouldInteractWithURL = [self shouldInteractWithURL:URL urlItemInteraction:interaction associatedEvent:associatedEvent];
    }
    
    return shouldInteractWithURL;
}

// Delegate method only called on iOS 9. iOS 10+ use method above.
- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    BOOL shouldInteractWithURL = YES;
    
    if (delegate && URL)
    {
        MXEvent *associatedEvent;
        
        if ([textView isMemberOfClass:[MXKMessageTextView class]])
        {
            MXKMessageTextView *mxkMessageTextView = (MXKMessageTextView *)textView;
            MXKRoomBubbleComponent *bubbleComponent = [self closestBubbleComponentAtPosition:mxkMessageTextView.lastHitTestLocation];
            associatedEvent = bubbleComponent.event;
        }
        
        // Ask the delegate if iOS can open the link
        shouldInteractWithURL = [self shouldInteractWithURL:URL urlItemInteractionValue:@(0) associatedEvent:associatedEvent];
    }
    
    return shouldInteractWithURL;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    if (webView == _attachmentWebView && self.attachmentView)
    {
        // The attachment webview is ready to replace the attachment view.
        _attachmentWebView.hidden = NO;
        self.attachmentView.image = nil;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    UIView *recognizerView = gestureRecognizer.view;
    
    if ([recognizerView isDescendantOfView:self.contentView])
    {
        UIView *touchedView = touch.view;
        
        if ([touchedView isKindOfClass:[UIButton class]])
        {
            return NO;
        }
        
        // Prevent gesture recognizer to be recognized by a custom view added to the cell contentView and with user interaction enabled
        for (UIView *tmpSubview in self.tmpSubviews)
        {
            if (tmpSubview.isUserInteractionEnabled && [tmpSubview isDescendantOfView:self.contentView])
            {
                CGPoint touchedPoint = [touch locationInView:tmpSubview];
                
                if (CGRectContainsPoint(tmpSubview.bounds, touchedPoint))
                {
                    return NO;
                }
            }
        }
        
        // Prevent gesture recognizer to be recognized when user hits a link in a UITextView, let UITextViewDelegate handle links.
        if ([touchedView isKindOfClass:[UITextView class]])
        {
            UITextView *textView = (UITextView*)touchedView;
            CGPoint touchLocation = [touch locationInView:textView];
            
            return [textView isThereALinkNearPoint:touchLocation] == NO;
        }
    }
    
    return YES;
}

@end

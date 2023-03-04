//
//  OABaseNavbarViewController.m
//  OsmAnd Maps
//
//  Created by Skalii on 08.02.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OABaseNavbarViewController.h"
#import "OASimpleTableViewCell.h"
#import "OAUtilities.h"
#import "OASizes.h"
#import "OAColors.h"
#import "Localization.h"

#define kRightIconLargeTitleSmall 34.
#define kRightIconLargeTitleLarge 40.

@implementation OABaseNavbarViewController
{
    BOOL _isHeaderBlurred;
    BOOL _isRotating;
    CGFloat _navbarHeightCurrent;
    CGFloat _navbarHeightSmall;
    CGFloat _navbarHeightLarge;
    UIView *_rightIconLargeTitle;

    UIBarButtonItem *_leftNavbarButton;
    UIBarButtonItem *_rightNavbarButton;
}

#pragma mark - Initialization

- (instancetype)init
{
    self = [super initWithNibName:@"OABaseNavbarViewController" bundle:nil];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
}

// use in overridden init method if class properties have complex dependencies
- (void)postInit
{
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [self generateData];

    [super viewDidLoad];

    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    
    if ([self getNavbarStyle] == EOABaseNavbarStyleCustomLargeTitle)
        [self.navigationItem hideTitleInStackView:YES defaultTitle:[self getTitle] defaultSubtitle:[self getSubtitle]];

    self.navigationController.interactivePopGestureRecognizer.delegate = self;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = UIColorFromRGB(color_primary_table_background);
    self.tableView.tintColor = UIColorFromRGB(color_primary_purple);

    [self updateNavbar];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.navigationController.navigationBar.prefersLargeTitles = YES;
    if ([self.navigationController isNavigationBarHidden] && [self isNavbarVisible])
        [self.navigationController setNavigationBarHidden:NO animated:YES];

    BOOL isLargeTitle = [self getNavbarStyle] == EOABaseNavbarStyleLargeTitle;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [self getNavbarBackgroundColor];
    appearance.titleTextAttributes = @{
        NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
        NSForegroundColorAttributeName : [self getTitleColor]
    };
    appearance.largeTitleTextAttributes = @{
        NSForegroundColorAttributeName : [self getLargeTitleColor]
    };

    if (![self isNavbarSeparatorVisible])
    {
        appearance.shadowImage = nil;
        appearance.shadowColor = nil;
    }

    self.navigationController.navigationBar.standardAppearance = [self isNavbarBlurring] ? [[UINavigationBarAppearance alloc] init] : appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

    self.navigationController.navigationBar.tintColor = [self getNavbarButtonsTintColor];
    self.navigationItem.largeTitleDisplayMode = isLargeTitle ? UINavigationItemLargeTitleDisplayModeAlways : UINavigationItemLargeTitleDisplayModeNever;

    if (_navbarHeightSmall == 0)
        _navbarHeightSmall = self.navigationController.navigationBar.frame.size.height;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    CGFloat navbarHeight = self.navigationController.navigationBar.frame.size.height;
    _navbarHeightCurrent = navbarHeight;
    [self updateRightIconLargeTitle];
    [self moveAndResizeImage:_navbarHeightCurrent];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (_rightIconLargeTitle)
    {
        [_rightIconLargeTitle removeFromSuperview];
        _rightIconLargeTitle = nil;
    }

    if (![self isModal] && ![self.navigationController isNavigationBarHidden])
    {
        //hide root navbar if open screen without navbar
        if (![self.navigationController.viewControllers.lastObject isNavbarVisible])
            [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    _isRotating = YES;
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavbar];
        [self updateRightIconLargeTitle];
        [self moveAndResizeImage:self.navigationController.navigationBar.frame.size.height];
        [self onRotation];
    } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
        _isRotating = NO;
    }];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if ([self getNavbarColorScheme] == EOABaseNavbarColorSchemeOrange)
        return UIStatusBarStyleLightContent;

    return UIStatusBarStyleDarkContent;
}

#pragma mark - Base setup UI

- (void)applyLocalization
{
    self.title = [self getTitle];
    NSString *sub = [self getSubtitle];
    BOOL isCustomLargeTitle = [self getNavbarStyle] == EOABaseNavbarStyleCustomLargeTitle;
    if ((sub && sub.length > 0) || isCustomLargeTitle)
    {
        [self.navigationItem setStackViewWithTitle:[self getTitle]
                                        titleColor:[self getTitleColor]
                                         titleFont:[UIFont scaledSystemFontOfSize:17. weight:UIFontWeightSemibold maximumSize:22.]
                                          subtitle:sub
                                     subtitleColor:UIColorFromRGB(color_text_footer)
                                      subtitleFont:[UIFont scaledSystemFontOfSize:13. maximumSize:18.]];
    }
    [self updateNavbarButtonTitles];
}

- (void)addAccessibilityLabels
{
    NSString *leftButtonTitle = [self getLeftNavbarButtonTitle];
    _leftNavbarButton.accessibilityLabel = leftButtonTitle ? leftButtonTitle : OALocalizedString(@"shared_string_back");
    NSString *rightButtonTitle = [self getRightNavbarButtonTitle];
    if (rightButtonTitle)
    _rightNavbarButton.accessibilityLabel = rightButtonTitle;
}

- (BOOL)isNavbarVisible
{
    return YES;
}

- (void)updateNavbar
{
    [self setupNavbarButtons];
    [self setupCustomLargeTitleView];
}

- (void)updateUI
{
    [self generateData];
    [self.tableView reloadData];
    [self applyLocalization];
    [self updateNavbar];
}

- (void)updateUIAnimated
{
    [UIView transitionWithView:self.view
                      duration:.2
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^(void)
                    {
                        [self updateUI];
                    }
                    completion:nil];
}

- (void)updateRightIconLargeTitle
{
    if (_rightIconLargeTitle)
    {
        [_rightIconLargeTitle removeFromSuperview];
        _rightIconLargeTitle = nil;
    }

    UIImage *rightIconLargeTitle = [self getRightIconLargeTitle];
    if (rightIconLargeTitle && [self getNavbarStyle] == EOABaseNavbarStyleLargeTitle)
    {
        CGFloat navbarHeight = _navbarHeightCurrent;
        if (navbarHeight > _navbarHeightSmall)
        {
            navbarHeight -= _navbarHeightSmall;
            if (_navbarHeightLarge == 0)
                _navbarHeightLarge = navbarHeight;
        }
        CGFloat baseIconSize = navbarHeight == _navbarHeightLarge ? kRightIconLargeTitleLarge : kRightIconLargeTitleSmall;
        CGFloat iconFrameOffsetSize = 2.;
        CGFloat iconFrameSize = baseIconSize - iconFrameOffsetSize * 2;

        UIImageView *iconView = [[UIImageView alloc] init];
        UIView *iconContainer = [[UIView alloc] init];
        [iconContainer addSubview:iconView];

        iconView.clipsToBounds = YES;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [iconView.leadingAnchor constraintEqualToAnchor:iconContainer.leadingAnchor constant:iconFrameOffsetSize],
            [iconView.topAnchor constraintEqualToAnchor:iconContainer.topAnchor constant:iconFrameOffsetSize],
            [iconView.heightAnchor constraintEqualToConstant:iconFrameSize],
            [iconView.widthAnchor constraintEqualToAnchor:iconView.heightAnchor]
        ]];

        iconContainer.backgroundColor = UIColor.whiteColor;
        iconView.contentMode = UIViewContentModeCenter;
        iconView.image = rightIconLargeTitle;
        UIColor *tintColor = [self getRightIconTintColorLargeTitle];
        if (tintColor)
            iconView.tintColor = tintColor;

        [self.navigationController.navigationBar addSubview:iconContainer];
        iconContainer.layer.cornerRadius = baseIconSize / 2;
        iconContainer.clipsToBounds = YES;
        iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [iconContainer.rightAnchor constraintEqualToAnchor:self.navigationController.navigationBar.rightAnchor constant:-(16. + [OAUtilities getLeftMargin])],
            [iconContainer.bottomAnchor constraintEqualToAnchor:self.navigationController.navigationBar.bottomAnchor constant:-((navbarHeight - baseIconSize) / 2)],
            [iconContainer.heightAnchor constraintEqualToConstant:baseIconSize],
            [iconContainer.widthAnchor constraintEqualToAnchor:iconContainer.heightAnchor]
        ]];
        _rightIconLargeTitle = iconContainer;
    }
}

- (void)updateNavbarButtonTitles
{
    if (_leftNavbarButton)
    {
        UIButton *leftButton = _leftNavbarButton.customView;
        [leftButton setTitle:[self getLeftNavbarButtonTitle] forState:UIControlStateNormal];
    }
    if (_rightNavbarButton)
    {
        UIButton *rightButton = _rightNavbarButton.customView;
        [rightButton setTitle:[self getRightNavbarButtonTitle] forState:UIControlStateNormal];
    }
}

- (void)setupNavbarButtons
{
    NSString *rightButtonTitle = [self getRightNavbarButtonTitle];
    NSString *leftButtonTitle = [self getLeftNavbarButtonTitle];
    UIImage *leftNavbarButtonCustomIcon = [self getCustomIconForLeftNavbarButton];
    if ((([self isModal] && !leftButtonTitle) || (![self isModal] && leftButtonTitle && leftButtonTitle.length == 0)) && !leftNavbarButtonCustomIcon)
        leftNavbarButtonCustomIcon = [UIImage templateImageNamed:@"ic_navbar_chevron"];

    CGFloat freeSpaceForTitle = DeviceScreenWidth - (kPaddingOnSideOfContent + [OAUtilities getLeftMargin]) * 2;
    CGFloat freeSpaceForNavbarButton = freeSpaceForTitle;
    if (leftNavbarButtonCustomIcon)
        freeSpaceForTitle -= 71.;

    NSMutableParagraphStyle *titleParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    titleParagraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary<NSAttributedStringKey, id> *titleAttributes = @{
        NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
        NSParagraphStyleAttributeName : titleParagraphStyle
    };
    CGFloat titleWidth = [OAUtilities calculateTextBounds:[[NSAttributedString alloc] initWithString:self.title
                                                                                          attributes:titleAttributes]
                                                    width:freeSpaceForTitle].width;
    freeSpaceForNavbarButton -= titleWidth;
    freeSpaceForNavbarButton /= 2;
    freeSpaceForNavbarButton -= 12.;
    BOOL isLongTitle = freeSpaceForNavbarButton < 50.;

    if (leftButtonTitle || leftNavbarButtonCustomIcon)
    {
        UIButton *leftButton = [[UIButton alloc] initWithFrame:CGRectMake(0., 0., freeSpaceForNavbarButton, 30.)];
        leftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        leftButton.titleLabel.textAlignment = NSTextAlignmentLeft;
        leftButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        leftButton.titleLabel.numberOfLines = 1;
        leftButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        leftButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [leftButton setTintColor:[self getNavbarButtonsTintColor]];
        [leftButton setTitleColor:[self getNavbarButtonsTintColor] forState:UIControlStateNormal];
        [leftButton setTitleColor:[[self getNavbarButtonsTintColor] colorWithAlphaComponent:.3] forState:UIControlStateHighlighted];
        [leftButton setTitle:isLongTitle ? nil : leftButtonTitle forState:UIControlStateNormal];
        if (isLongTitle && !leftNavbarButtonCustomIcon)
        {
            leftNavbarButtonCustomIcon = [UIImage templateImageNamed:@"ic_navbar_chevron"];
            freeSpaceForNavbarButton = 30.;
        }
        [leftButton setImage:leftNavbarButtonCustomIcon forState:UIControlStateNormal];
        leftButton.imageEdgeInsets = UIEdgeInsetsMake(0., -10., 0., 0.);
        [leftButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [leftButton addTarget:self action:@selector(onLeftNavbarButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        leftButton.translatesAutoresizingMaskIntoConstraints = NO;
        [leftButton.widthAnchor constraintLessThanOrEqualToConstant:freeSpaceForNavbarButton].active = YES;

        _leftNavbarButton = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
        [self.navigationItem setLeftBarButtonItem:_leftNavbarButton animated:YES];
    }

    if (rightButtonTitle)
    {
        UIButton *rightButton = [[UIButton alloc] initWithFrame:CGRectMake(0., 0., freeSpaceForNavbarButton, 30.)];
        rightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentTrailing;
        rightButton.titleLabel.textAlignment = NSTextAlignmentRight;
        rightButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        rightButton.titleLabel.numberOfLines = 1;
        rightButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        rightButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        [rightButton setTintColor:[self getNavbarButtonsTintColor]];
        [rightButton setTitleColor:[self getNavbarButtonsTintColor] forState:UIControlStateNormal];
        [rightButton setTitleColor:[[self getNavbarButtonsTintColor] colorWithAlphaComponent:.3] forState:UIControlStateHighlighted];
        [rightButton setTitle:rightButtonTitle forState:UIControlStateNormal];
        [rightButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [rightButton addTarget:self action:@selector(onRightNavbarButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        rightButton.translatesAutoresizingMaskIntoConstraints = NO;
        [rightButton.widthAnchor constraintLessThanOrEqualToConstant:isLongTitle ? 50. : freeSpaceForNavbarButton].active = YES;

        _rightNavbarButton = [[UIBarButtonItem alloc] initWithCustomView:rightButton];
        [self.navigationItem setRightBarButtonItem:_rightNavbarButton animated:YES];
    }
}

- (BOOL)isAnyLargeTitle
{
    return [self getNavbarStyle] == EOABaseNavbarStyleLargeTitle || [self getNavbarStyle] == EOABaseNavbarStyleCustomLargeTitle;
}

- (UIColor *)getNavbarBackgroundColor
{
    if ([self isAnyLargeTitle])
        return self.tableView.backgroundColor;

    EOABaseNavbarColorScheme colorScheme = [self getNavbarColorScheme];
    switch (colorScheme)
    {
        case EOABaseNavbarColorSchemeOrange:
            return UIColorFromRGB(color_primary_orange_navbar_background);
        case EOABaseNavbarColorSchemeWhite:
            return UIColor.whiteColor;
        default:
            return self.tableView.backgroundColor;
    }
}

- (UIColor *)getNavbarButtonsTintColor
{
    return [self getNavbarColorScheme] == EOABaseNavbarColorSchemeOrange ? UIColor.whiteColor : UIColorFromRGB(color_primary_purple);
}

- (UIColor *)getTitleColor
{
    return [self getNavbarColorScheme] == EOABaseNavbarColorSchemeOrange ? UIColor.whiteColor : UIColor.blackColor;
}

- (UIColor *)getLargeTitleColor
{
    return UIColor.blackColor;
}

#pragma mark - Base UI

- (NSString *)getTitle
{
    return @"";
}

- (NSString *)getSubtitle
{
    return @"";
}

- (NSString *)getLeftNavbarButtonTitle
{
    return nil;
}

- (UIImage *)getCustomIconForLeftNavbarButton
{
    return nil;
}

- (NSString *)getRightNavbarButtonTitle
{
    return @"";
}

- (EOABaseNavbarColorScheme)getNavbarColorScheme
{
    return EOABaseNavbarColorSchemeGray;
}

- (BOOL)isNavbarBlurring
{
    return [self getNavbarColorScheme] != EOABaseNavbarColorSchemeOrange;
}

- (BOOL)isNavbarSeparatorVisible
{
    return [self getNavbarColorScheme] != EOABaseNavbarColorSchemeOrange;
}

- (UIImage *)getRightIconLargeTitle
{
    return nil;
}

- (UIColor *)getRightIconTintColorLargeTitle
{
    return nil;
}

- (EOABaseNavbarStyle)getNavbarStyle
{
    return EOABaseNavbarStyleSimple;
}

- (NSString *)getCustomTableViewDescription
{
    return @"";
}

- (void)setupCustomLargeTitleView
{
    EOABaseNavbarStyle style = [self getNavbarStyle];
    UIView *tableHeaderView;
    BOOL isCustomLargeTitle = style == EOABaseNavbarStyleCustomLargeTitle;
    if (isCustomLargeTitle || style == EOABaseNavbarStyleDescription)
    {
        tableHeaderView = [OAUtilities setupTableHeaderViewWithText:isCustomLargeTitle ? [self getTitle] : [self getCustomTableViewDescription]
                                                               font:isCustomLargeTitle ? kHeaderBigTitleFont : kHeaderDescriptionFontSmall
                                                          textColor:isCustomLargeTitle ? UIColor.blackColor : UIColorFromRGB(color_text_footer)
                                                        isBigTitle:isCustomLargeTitle];
    }
    self.tableView.tableHeaderView = tableHeaderView;
}

#pragma mark - Table data

- (void)generateData
{
}

- (BOOL)hideFirstHeader
{
    return NO;
}

- (NSString *)getTitleForHeader:(NSInteger)section
{
    return @"";
}

- (NSString *)getTitleForFooter:(NSInteger)section
{
    return @"";
}

- (NSInteger)rowsCount:(NSInteger)section
{
    return 0;
}

- (UITableViewCell *)getRow:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSInteger)sectionsCount
{
    return 0;
}

- (CGFloat)getCustomHeightForHeader:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (CGFloat)getCustomHeightForFooter:(NSInteger)section
{
    return UITableViewAutomaticDimension;
}

- (UIView *)getCustomViewForHeader:(NSInteger)section
{
    return nil;
}

- (UIView *)getCustomViewForFooter:(NSInteger)section
{
    return nil;
}

- (void)onRowSelected:(NSIndexPath *)indexPath
{
}
- (void)onRowDeselected:(NSIndexPath *)indexPath
{
}

#pragma mark - IBAction

- (IBAction)onRightNavbarButtonPressed:(UIButton *)sender
{
    [self onRightNavbarButtonPressed];
}

#pragma mark - Selectors

- (void)onRightNavbarButtonPressed
{
    [self dismissViewController];
}

// override with super to work correctly
- (void)onContentSizeChanged:(NSNotification *)notification
{
    [self setupCustomLargeTitleView];
}

- (void)onScrollViewDidScroll:(UIScrollView *)scrollView
{
}

- (void)onRotation
{
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - UIScrollViewDelegate

- (void)moveAndResizeImage:(CGFloat)height
{
    if (_rightIconLargeTitle && [self getNavbarStyle] == EOABaseNavbarStyleLargeTitle)
    {
        CGFloat delta = height - _navbarHeightSmall;
        CGFloat heightDifferenceBetweenStates = _navbarHeightLarge - _navbarHeightSmall;
        CGFloat coeff = delta / heightDifferenceBetweenStates;
        CGFloat factor = kRightIconLargeTitleSmall / kRightIconLargeTitleLarge;
        CGFloat sizeAddendumFactor = coeff * (1. - factor);
        CGFloat scale = MIN(1., sizeAddendumFactor + factor);

        CGFloat sizeDiff = kRightIconLargeTitleLarge * (1. - factor);
        CGFloat iconBottomMarginForLargeState = (_navbarHeightLarge - kRightIconLargeTitleLarge) / 2;
        CGFloat iconBottomMarginForSmallState = (_navbarHeightSmall - kRightIconLargeTitleSmall) / 2;
        CGFloat maxYTranslation = iconBottomMarginForLargeState - iconBottomMarginForSmallState + sizeDiff;
        CGFloat yTranslation = MAX(0, MIN(maxYTranslation, (maxYTranslation - coeff * (iconBottomMarginForSmallState + sizeDiff))));
        CGFloat xTranslation = MAX(0, sizeDiff - coeff * sizeDiff);

        _rightIconLargeTitle.transform = CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformIdentity, scale, scale), xTranslation, yTranslation);
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (!_isRotating && [self isScreenLoaded])
    {
        CGFloat navbarHeight = self.navigationController.navigationBar.frame.size.height;
        if (_navbarHeightCurrent != navbarHeight && (navbarHeight >= (_navbarHeightLarge + _navbarHeightSmall) && [self getNavbarStyle] == EOABaseNavbarStyleLargeTitle))
        {
            _navbarHeightCurrent = _navbarHeightLarge + _navbarHeightSmall;
            [self updateRightIconLargeTitle];
        }
        
        [self moveAndResizeImage:self.navigationController.navigationBar.frame.size.height];
        
        if ([self getNavbarStyle] == EOABaseNavbarStyleCustomLargeTitle)
        {
            CGFloat y = scrollView.contentOffset.y + _navbarHeightSmall + _navbarHeightLarge;
            if (![self isModal])
                y += [OAUtilities getTopMargin];
            CGFloat tableHeaderHeight = self.tableView.tableHeaderView.frame.size.height;
            if (y > 0)
            {
                if (y > tableHeaderHeight * .75 && [self.navigationItem isTitleInStackViewHided])
                    [self.navigationItem hideTitleInStackView:NO defaultTitle:[self getTitle] defaultSubtitle:[self getSubtitle]];
                else if (y < tableHeaderHeight * .75 && ![self.navigationItem isTitleInStackViewHided])
                    [self.navigationItem hideTitleInStackView:YES defaultTitle:[self getTitle] defaultSubtitle:[self getSubtitle]];
            }
            else if (y <= 0 && ![self.navigationItem isTitleInStackViewHided])
            {
                [self.navigationItem hideTitleInStackView:NO defaultTitle:[self getTitle] defaultSubtitle:[self getSubtitle]];
            }
        }
        
        [self onScrollViewDidScroll:scrollView];
    }
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0 && [self hideFirstHeader])
        return 0.001;

    return [self getCustomHeightForHeader:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [self getCustomHeightForFooter:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return [self getCustomViewForHeader:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [self getCustomViewForFooter:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onRowSelected:indexPath];

    if (!self.tableView.allowsMultipleSelectionDuringEditing)
    {
        UITableViewCell *row = [self getRow:indexPath];
        if (row && row.selectionStyle != UITableViewCellSelectionStyleNone)
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onRowDeselected:indexPath];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self rowsCount:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self getRow:indexPath];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self sectionsCount];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self getTitleForHeader:section];
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [self getTitleForFooter:section];
}

@end

// !!!
// remove from project:
//
//tableView.separatorInset =
//- (CGFloat)heightForRow:(NSIndexPath *)indexPath
//- (CGFloat)heightForRow:(NSIndexPath *)indexPath estimated:(BOOL)estimated
//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
//- (NSIndexPath *) tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
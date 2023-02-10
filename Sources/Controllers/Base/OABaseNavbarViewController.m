//
//  OABaseNavbarViewController.m
//  OsmAnd Maps
//
//  Created by Skalii on 08.02.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OABaseNavbarViewController.h"
#import "OAUtilities.h"
#import "OASizes.h"
#import "OAColors.h"

@interface OABaseNavbarViewController ()

@property (weak, nonatomic) IBOutlet UIView *navbarBackgroundView;
@property (weak, nonatomic) IBOutlet UIStackView *navbarStackView;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *navbarEstimatedHeightConstraint;
@property (weak, nonatomic) IBOutlet UIView *leftNavbarMarginView;
@property (weak, nonatomic) IBOutlet UIView *rightNavbarMarginView;

@property (weak, nonatomic) IBOutlet UIStackView *leftNavbarButtonStackView;
@property (weak, nonatomic) IBOutlet UIView *leftNavbarButtonMarginView;

@property (weak, nonatomic) IBOutlet UIStackView *rightNavbarButtonStackView;
@property (weak, nonatomic) IBOutlet UIView *rightNavbarButtonMarginView;

@end

@implementation OABaseNavbarViewController
{
    BOOL _isHeaderBlurred;
}

#pragma mark - Initialization methods

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
    [super viewDidLoad];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;

    [self setupNavbarButtons];
    [self setupNavbarFonts];

    NSString *title = [self getTitle];
    self.titleLabel.hidden = !title || title.length == 0;
    NSString *subtitle = [self getSubtitle];
    self.subtitleLabel.hidden = !subtitle || subtitle.length == 0;
    self.separatorNavbarView.hidden = ![self isNavbarSeparatorVisible];
    self.navbarBackgroundView.backgroundColor = [self getNavbarColor];

    [self generateData];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self updateNavbarEstimatedHeight];
        [self onRotation];
        [self.tableView reloadData];
    } completion:nil];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (@available(iOS 13.0, *))
        return UIStatusBarStyleDarkContent;

    return UIStatusBarStyleDefault;
}

#pragma mark - UI base setup methods

- (void)applyLocalization
{
    self.titleLabel.text = [self getTitle];
    self.subtitleLabel.text = [self getSubtitle];
    [self.leftNavbarButton setTitle:[self getLeftNavbarButtonTitle] forState:UIControlStateNormal];
    [self.rightNavbarButton setTitle:[self getRightNavbarButtonTitle] forState:UIControlStateNormal];
}

- (void)setupNavbarButtons
{
    [self.leftNavbarButton setTitleColor:[self getNavbarButtonsTintColor] forState:UIControlStateNormal];
    self.leftNavbarButton.tintColor = [self getNavbarButtonsTintColor];
    [self.rightNavbarButton setTitleColor:[self getNavbarButtonsTintColor] forState:UIControlStateNormal];
    self.rightNavbarButton.tintColor = [self getNavbarButtonsTintColor];

    BOOL isChevronIconVisible = [self isChevronIconVisible];
    [self.leftNavbarButton setImage:isChevronIconVisible ? [UIImage templateImageNamed:@"ic_navbar_chevron"] : nil
                           forState:UIControlStateNormal];
    self.leftNavbarButton.titleEdgeInsets = UIEdgeInsetsMake(0., isChevronIconVisible ? -10. : 0., 0., 0.);

    NSString *leftNavbarButtonTitle = [self getLeftNavbarButtonTitle];
    BOOL hasLeftButton = (leftNavbarButtonTitle && leftNavbarButtonTitle.length > 0) || isChevronIconVisible;
    self.leftNavbarButton.hidden = !hasLeftButton;
    self.leftNavbarButtonMarginView.hidden = !hasLeftButton || isChevronIconVisible;

    NSString *rightNavbarButtonTitle = [self getRightNavbarButtonTitle];
    BOOL hasRightButton = rightNavbarButtonTitle && rightNavbarButtonTitle.length > 0;
    self.rightNavbarButton.hidden = !hasRightButton;
    self.rightNavbarButtonMarginView.hidden = !hasRightButton;

    self.leftNavbarButtonStackView.hidden = !hasLeftButton && !hasRightButton;
    self.rightNavbarButtonStackView.hidden = !hasLeftButton && !hasRightButton;
}

- (void)setupNavbarFonts
{
    self.leftNavbarButton.titleLabel.font = [UIFont scaledSystemFontOfSize:17. weight:UIFontWeightSemibold maximumSize:22.];
    self.rightNavbarButton.titleLabel.font = [UIFont scaledSystemFontOfSize:17. weight:UIFontWeightSemibold maximumSize:22.];
    self.titleLabel.font = [UIFont scaledSystemFontOfSize:17. weight:UIFontWeightSemibold maximumSize:22.];
    self.subtitleLabel.font = [UIFont scaledSystemFontOfSize:13. weight:UIFontWeightSemibold maximumSize:18.];
}

- (CGFloat)getNavbarHeight
{
    return self.navbarStackView.frame.size.height;
}

- (CGFloat)getNavbarEstimatedHeight
{
    return self.navbarEstimatedHeightConstraint.constant;
}

- (void)updateNavbarEstimatedHeight
{
    self.navbarEstimatedHeightConstraint.constant = [self getNavbarHeight];
    self.tableView.contentInset = UIEdgeInsetsMake(self.navbarEstimatedHeightConstraint.constant, 0, 0, 0);
}

- (void)resetNavbarEstimatedHeight
{
    self.navbarEstimatedHeightConstraint.constant = 0;
}

#pragma mark - UI override methods

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
    return @"";
}

- (NSString *)getRightNavbarButtonTitle
{
    return @"";
}

- (UIColor *)getNavbarColor
{
    return UIColorFromRGB(color_bottom_sheet_background);
}

- (UIColor *)getNavbarButtonsTintColor
{
    return UIColorFromRGB(color_primary_purple);
}

- (BOOL)isNavbarSeparatorVisible
{
    return YES;
}

- (BOOL)isChevronIconVisible
{
    return YES;
}

- (BOOL)isNavbarBlurring
{
    return YES;
}

#pragma mark - Table data methods

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

- (void)onRowPressed:(NSIndexPath *)indexPath
{
}

#pragma mark - Selectors

- (void)onScrollViewDidScroll:(UIScrollView *)scrollView
{
}

- (void)onRotation
{
}

- (IBAction)onLeftNavbarButtonPressed:(UIButton *)sender
{
    [self dismissViewController];
}

- (IBAction)onRightNavbarButtonPressed:(UIButton *)sender
{
    [self dismissViewController];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if ([self isNavbarBlurring])
    {
        CGFloat extraMargin = [self isModal] ? 0. : [OAUtilities getTopMargin];
        CGFloat y = scrollView.contentOffset.y - (scrollView.contentOffset.y < 0 ? -extraMargin : extraMargin);
        CGFloat navbarHeight = [self getNavbarHeight];
        if (!_isHeaderBlurred && y > -(navbarHeight))
        {
            [UIView animateWithDuration:.2 animations:^{
                [self.navbarBackgroundView addBlurEffect:YES cornerRadius:0. padding:0.];
                _isHeaderBlurred = YES;
            }];
        }
        else if (_isHeaderBlurred && y <= -(navbarHeight))
        {
            [UIView animateWithDuration:.2 animations:^{
                [self.navbarBackgroundView removeBlurEffect:[self getNavbarColor]];
                _isHeaderBlurred = NO;
            }];
        }
    }

    [self onScrollViewDidScroll:scrollView];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([self hideFirstHeader])
        return 0.001;

    return [self getCustomHeightForHeader:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [self getCustomHeightForFooter:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onRowPressed:indexPath];
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

//
//  OATableViewCellSimple.m
//  OsmAnd Maps
//
//  Created by Skalii on 22.09.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OATableViewCellSimple.h"

@interface OATableViewCellSimple ()

@property (weak, nonatomic) IBOutlet UIStackView *textCustomMarginTopStackView;
@property (weak, nonatomic) IBOutlet UIStackView *contentInsideStackView;
@property (weak, nonatomic) IBOutlet UIStackView *textStackView;
@property (weak, nonatomic) IBOutlet UIStackView *textCustomMarginBottomStackView;

@end

@implementation OATableViewCellSimple

- (void)leftIconVisibility:(BOOL)show
{
    self.leftIconView.hidden = !show;
    [self updateMargins];
}

- (void)titleVisibility:(BOOL)show
{
    self.titleLabel.hidden = !show;
    [self updateMargins];
}

- (void)descriptionVisibility:(BOOL)show
{
    self.descriptionLabel.hidden = !show;
    [self updateMargins];
}

- (void)updateMargins
{
    self.topContentSpaceView.hidden = (self.descriptionLabel.hidden || self.titleLabel.hidden) && [self checkSubviewsToUpdateMargins];
    self.bottomContentSpaceView.hidden = (self.descriptionLabel.hidden || self.titleLabel.hidden) && [self checkSubviewsToUpdateMargins];
}

- (BOOL)checkSubviewsToUpdateMargins
{
    return !self.leftIconView.hidden;
}

- (void)textIndentsStyle:(EOATableViewCellTextIndentsStyle)style
{
    if (style == EOATableViewCellTextNormalIndentsStyle)
    {
        self.textCustomMarginTopStackView.spacing = 5.;
        self.textStackView.spacing = 2.;
        self.textCustomMarginBottomStackView.spacing = 5.;
    }
    else if (style == EOATableViewCellTextIncreasedTopCenterIndentStyle)
    {
        self.textCustomMarginTopStackView.spacing = 9.;
        self.textStackView.spacing = 6.;
        self.textCustomMarginBottomStackView.spacing = 5.;
    }
}

- (void)anchorContent:(EOATableViewCellContentStyle)style
{
    if (style == EOATableViewCellContentCenterStyle)
    {
        self.contentInsideStackView.alignment = UIStackViewAlignmentCenter;
    }
    else if (style == EOATableViewCellContentTopStyle)
    {
        self.contentInsideStackView.alignment = UIStackViewAlignmentTop;
    }
}

@end
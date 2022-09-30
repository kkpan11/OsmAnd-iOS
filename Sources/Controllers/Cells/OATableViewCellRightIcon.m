//
//  OATableViewCellRightIcon.m
//  OsmAnd Maps
//
//  Created by Skalii on 22.09.2022.
//  Copyright © 2022 OsmAnd. All rights reserved.
//

#import "OATableViewCellRightIcon.h"

@implementation OATableViewCellRightIcon

- (void)rightIconVisibility:(BOOL)show
{
    self.rightIconView.hidden = !show;
    [self updateMargins];
}

- (BOOL)checkSubviewsToUpdateMargins
{
    return !self.leftIconView.hidden || !self.rightIconView.hidden;
}

@end

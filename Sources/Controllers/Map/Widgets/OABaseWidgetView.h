//
//  OABaseWidgetView.h
//  OsmAnd Maps
//
//  Created by Paul on 20.08.2021.
//  Copyright © 2021 OsmAnd. All rights reserved.
//

#import <UIKit/UIKit.h>

@class OABaseWidgetView, OAWidgetType, OAWidgetState, OAWidgetsPanel, OAApplicationMode, OACommonBoolean, OACommonPreference, OATableDataModel, OATextState;

@protocol OAWidgetListener <NSObject>

@required
- (void) widgetChanged:(OABaseWidgetView *_Nullable)widget;
- (void) widgetVisibilityChanged:(OABaseWidgetView *_Nonnull)widget visible:(BOOL)visible;
- (void) widgetClicked:(OABaseWidgetView *_Nonnull)widget;

@end

@protocol OAWidgetListener;

@interface OABaseWidgetView : UIView

@property (nonatomic) OAWidgetType * _Nullable widgetType;
@property (nonatomic, readonly, assign) BOOL nightMode;
@property (nonatomic, assign) BOOL isSimpleLayout;
@property (nonatomic, assign) BOOL isVerticalStackImageTitleSubtitleLayout;
@property (nonatomic, assign) BOOL isFullRow;

@property (nonatomic, weak) id<OAWidgetListener> _Nullable delegate;

- (instancetype _Nonnull )initWithType:(OAWidgetType * _Nonnull)type;
- (void)initSeparatorsView;

- (BOOL)updateInfo;
- (void)updateColors:(OATextState * _Nonnull)textState;
- (BOOL)isNightMode;
- (BOOL)isTopText;
- (BOOL)isTextInfo;
- (void)updateSimpleLayout;
- (void)updateVerticalStackImageTitleSubtitleLayout;
- (void)updatesSeparatorsColor:(UIColor *_Nonnull)color;

- (void)updateHeightConstraintWithRelation:(NSLayoutRelation)relation constant:(CGFloat)constant priority:(UILayoutPriority)priority;
- (void)updateHeightConstraint:(NSLayoutConstraint * _Nullable)constraint;

- (OACommonBoolean * _Nullable ) getWidgetVisibilityPref;
- (OACommonPreference * _Nullable ) getWidgetSettingsPrefToReset:(OAApplicationMode *_Nonnull)appMode;
- (void) copySettings:(OAApplicationMode *_Nonnull)appMode customId:(NSString *_Nullable)customId;
- (OAWidgetState *_Nullable) getWidgetState;
- (BOOL)isExternal;
- (OATableDataModel *_Nullable)getSettingsData:(OAApplicationMode * _Nonnull)appMode;
- (OATableDataModel *_Nullable)getSettingsDataForSimpleWidget:(OAApplicationMode * _Nonnull)appMode;

- (void)showBottomSeparator:(BOOL)show;
- (void)showRightSeparator:(BOOL)show;
- (void)adjustViewSize;
- (void)attachView:(UIView *_Nonnull)container specialContainer:(UIView *_Nullable)specialContainer order:(NSInteger)order followingWidgets:(NSArray<OABaseWidgetView *> *_Nullable)followingWidgets;
- (void)detachView:(OAWidgetsPanel * _Nonnull)widgetsPanel;

@end


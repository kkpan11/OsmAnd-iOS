//
//  OAOsmEditsLayer.m
//  OsmAnd
//
//  Created by Paul on 17/01/2019.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

#import "OAOsmEditsLayer.h"
#import "OADefaultFavorite.h"
#import "OAFavoriteItem.h"
#import "OANativeUtilities.h"
#import "OAMapViewController.h"
#import "OAMapRendererView.h"
#import "OATargetPoint.h"
#import "OAUtilities.h"
#import "OAOsmEditsDBHelper.h"
#import "OAOpenStreetMapPoint.h"
#import "OAOsmEditingPlugin.h"
#import "OAOsmBugsDBHelper.h"
#import "OAEntity.h"
#import "OAPOI.h"
#import "OAPOIType.h"
#import "OAPlugin.h"
#import "OAOsmNotePoint.h"
#import "OAOpenStreetMapPoint.h"
#import "OAPOIHelper.h"
#import "OAAutoObserverProxy.h"
#import "OAEditPOIData.h"
#import "OAColors.h"
#import "OACompoundIconUtils.h"
#import "OAPluginsHelper.h"
#import "OAAppSettings.h"
#import "OAAppData.h"
#import "OAObservable.h"

#include <OsmAndCore.h>
#include <OsmAndCore/Utilities.h>
#include <OsmAndCore/Map/MapMarker.h>
#include <OsmAndCore/Map/MapMarkerBuilder.h>
#include <OsmAndCore/Map/FavoriteLocationsPresenter.h>
#include <OsmAndCore/SingleSkImage.h>
#include <QReadWriteLock>

@implementation OAOsmEditsLayer
{
    std::shared_ptr<OsmAnd::MapMarkersCollection> _osmEditsCollection;
    OAOsmEditingPlugin *_plugin;
    
    QReadWriteLock _iconsCacheLock;
    QHash<QString, sk_sp<SkImage>> _iconsCache;

    OAAutoObserverProxy *_editsChangedObserver;
    
    BOOL _showCaptionsCache;
    double _textSize;
    double _captionTopSpace;
}

- (instancetype) initWithMapViewController:(OAMapViewController *)mapViewController baseOrder:(int)baseOrder
{
    self = [super initWithMapViewController:mapViewController baseOrder:baseOrder];
    if (self) {
        _plugin = (OAOsmEditingPlugin *) [OAPluginsHelper getPlugin:OAOsmEditingPlugin.class];
    }
    return self;
}

- (NSString *) layerId
{
    return kOsmEditsLayerId;
}

- (void) initLayer
{
    [super initLayer];
    
    _textSize = OAAppSettings.sharedManager.textSize.get;
    _showCaptionsCache = self.showCaptions;
    // TODO: migrate to compound icons and probably remove this (for now, it's used to compensate for the edits' icon transparent space)
    _captionTopSpace = -4 * self.displayDensityFactor;
    
    _editsChangedObserver = [[OAAutoObserverProxy alloc] initWith:self
                                                       withHandler:@selector(onEditsCollectionChanged)
                                                       andObserve:self.app.osmEditsChangeObservable];
    
    BOOL shouldShow = [_plugin isEnabled] && [[OAAppSettings sharedManager].mapSettingShowOfflineEdits get];
    
    [self refreshOsmEditsCollection];
    [self.app.data.mapLayersConfiguration setLayer:self.layerId
                                        Visibility:shouldShow];
}

- (BOOL)isVisible
{
    return [_plugin isEnabled] && [[OAAppSettings sharedManager].mapSettingShowOfflineEdits get];
}

- (BOOL) updateLayer
{
    if (![super updateLayer])
        return NO;

    CGFloat textSize = [[OAAppSettings sharedManager].textSize get];
    BOOL textSizeChanged = _textSize != textSize;
    if (self.showCaptions != _showCaptionsCache || textSizeChanged)
    {
        _showCaptionsCache = self.showCaptions;
        _textSize = textSize;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hide];
            if (textSizeChanged)
            {
                QWriteLocker scopedLocker(&_iconsCacheLock);
                _iconsCache.clear();
            }
            [self refreshOsmEditsCollection];
            [self show];
        });
    }
    return YES;
}

- (std::shared_ptr<OsmAnd::MapMarkersCollection>) getOsmEditsCollection
{
    return _osmEditsCollection;
}

- (void) refreshOsmEditsCollection
{
    _osmEditsCollection.reset(new OsmAnd::MapMarkersCollection());
    NSArray * data = [self getAllPoints];
    for (OAOsmPoint *point in data)
    {
        NSString *description = [self getPointDescription:point];
        OsmAnd::MapMarkerBuilder builder;
        builder.setIsAccuracyCircleSupported(false)
        .setBaseOrder(self.pointsOrder)
        .setIsHidden(false)
        .setPinIcon(OsmAnd::SingleSkImage([self getIcon:point]))
        .setPosition(OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon([point getLatitude], [point getLongitude])))
        .setPinIconVerticalAlignment(OsmAnd::MapMarker::CenterVertical)
        .setPinIconHorisontalAlignment(OsmAnd::MapMarker::CenterHorizontal);
        
        if (self.showCaptions && description.length > 0)
        {
            builder.setCaption(QString::fromNSString(description));
            builder.setCaptionStyle(self.captionStyle);
            builder.setCaptionTopSpace(_captionTopSpace);
        }
        builder.buildAndAddToCollection(_osmEditsCollection);
    }
}

- (sk_sp<SkImage>) getIcon:(OAOsmPoint *)point
{
    sk_sp<SkImage> bitmap;
    if ([point isKindOfClass:OAOpenStreetMapPoint.class])
    {
        OAOpenStreetMapPoint *osmP = (OAOpenStreetMapPoint *)point;
        NSString *poiTranslation = [osmP.getEntity getTagFromString:POI_TYPE_TAG];
        if (poiTranslation != nil)
        {
            NSDictionary<NSString *, OAPOIType *> *poiTypeMap = [OAPOIHelper.sharedInstance getAllTranslatedNames:NO];
            OAPOIType *type = poiTypeMap[poiTranslation.lowerCase];
            if (type)
            {
                auto iconId = QString::fromNSString(type.name);
                bool isNew = false;
                {
                    QReadLocker scopedLocker(&_iconsCacheLock);
                    const auto bitmapIt = _iconsCache.find(iconId);
                    isNew = bitmapIt == _iconsCache.end();
                    if (!isNew)
                    {
                        bitmap = bitmapIt.value();
                    }
                }
                if (isNew)
                {
                    bitmap = [OACompoundIconUtils createCompositeIconWithcolor:UIColorFromARGB(color_osm_edit)
                                                                     shapeName:DEFAULT_ICON_SHAPE_KEY
                                                                      iconName:type.name
                                                                    isFullSize:YES
                                                                          icon:type.icon
                                                                         scale:_textSize];

                    QWriteLocker scopedLocker(&_iconsCacheLock);
                    _iconsCache[iconId] = bitmap;
                }
            }
        }
        if (!bitmap)
        {
            bitmap = [OACompoundIconUtils createCompositeIconWithcolor:UIColorFromARGB(color_osm_edit) 
                                                             shapeName:DEFAULT_ICON_SHAPE_KEY
                                                              iconName:@"ic_custom_poi"
                                                            isFullSize:YES
                                                                  icon:[UIImage imageNamed:@"ic_custom_poi"]
                                                                 scale:_textSize];
        }
    }
    else
    {
        auto iconId = QStringLiteral("osm_note");
        bool isNew = false;
        {
            QReadLocker scopedLocker(&_iconsCacheLock);
            const auto bitmapIt = _iconsCache.find(iconId);
            isNew = bitmapIt == _iconsCache.end();
            if (!isNew)
            {
                bitmap = bitmapIt.value();
            }
        }
        if (isNew)
        {
            [self getOsmNoteBitmap:bitmap];
            QWriteLocker scopedLocker(&_iconsCacheLock);
            _iconsCache[iconId] = bitmap;
        }
    }

    return bitmap;
}

- (NSString *) getPointDescription:(OAOsmPoint *)point
{
    NSString *res = @"";
    if ([point isKindOfClass:OAOpenStreetMapPoint.class])
    {
        res = ((OAOpenStreetMapPoint *)point).getName;
    }
    return res == nil ? @"" : res;
}

- (void) show
{
    [self.mapViewController runWithRenderSync:^{
        [self.mapView addKeyedSymbolsProvider:_osmEditsCollection];
    }];
}

- (void) hide
{
    [self.mapViewController runWithRenderSync:^{
        [self.mapView removeKeyedSymbolsProvider:_osmEditsCollection];
    }];
}

- (void) onEditsCollectionChanged
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hide];
        [self refreshOsmEditsCollection];
        if ([[OAAppSettings sharedManager].mapSettingShowOfflineEdits get])
            [self show];
    });
}

#pragma mark - OAContextMenuProvider

- (OATargetPoint *)getTargetPointFromPoint:(OAOsmPoint *)point {
    OATargetPoint *targetPoint = [[OATargetPoint alloc] init];
    targetPoint.location = CLLocationCoordinate2DMake(point.getLatitude, point.getLongitude);
    NSString *title = point.getName;
    targetPoint.title = title.length == 0 ? [NSString stringWithFormat:@"%@ • %@", point.getLocalizedAction, [OAOsmEditingPlugin getCategory:point]] : title;
    
    targetPoint.values = point.getTags;
    targetPoint.icon = [self getUIImageForPoint:point];
    
    targetPoint.type = point.getGroup == EOAGroupPoi ? OATargetOsmEdit : OATargetOsmNote;
    
    targetPoint.targetObj = point;
    
    targetPoint.sortIndex = (NSInteger)targetPoint.type;
    return targetPoint;
}

-(UIImage *)getUIImageForPoint:(OAOsmPoint *)point
{
    if (point.getGroup == EOAGroupPoi)
    {
        OAOpenStreetMapPoint *osmP = (OAOpenStreetMapPoint *) point;
        NSString *poiTranslation = [osmP.getEntity getTagFromString:POI_TYPE_TAG];
        
        if (poiTranslation)
        {
            OAPOIHelper *poiHelper = [OAPOIHelper sharedInstance];
            NSDictionary *translatedNames = [poiHelper getAllTranslatedNames:NO];
            OAPOIType *poiType = translatedNames[[poiTranslation lowerCase]];
            if (poiType)
                return poiType.icon;
        }
    }
    
    return [UIImage mapSvgImageNamed:@"mx_special_information"];
}

- (OATargetPoint *) getTargetPoint:(id)obj
{
    if ([obj isKindOfClass:OAOsmPoint.class])
        return [self getTargetPointFromPoint:(OAOsmPoint *)obj];
    return nil;
}

- (OATargetPoint *) getTargetPointCpp:(const void *)obj
{
    return nil;
}

- (NSArray *)getAllPoints {
    NSMutableArray *data = [NSMutableArray new];
    [data addObjectsFromArray:[[OAOsmEditsDBHelper sharedDatabase] getOpenstreetmapPoints]];
    [data addObjectsFromArray:[[OAOsmBugsDBHelper sharedDatabase] getOsmBugsPoints]];
    return [NSArray arrayWithArray:data];
}

- (void) collectObjectsFromPoint:(CLLocationCoordinate2D)point touchPoint:(CGPoint)touchPoint symbolInfo:(const OsmAnd::IMapRenderer::MapSymbolInformation *)symbolInfo found:(NSMutableArray<OATargetPoint *> *)found unknownLocation:(BOOL)unknownLocation
{
    if (![[OAAppSettings sharedManager].mapSettingShowOfflineEdits get])
        return;
    for (const auto& edit : _osmEditsCollection->getMarkers())
    {
        double lat = OsmAnd::Utilities::get31LatitudeY(edit->getPosition().y);
        double lon = OsmAnd::Utilities::get31LongitudeX(edit->getPosition().x);
        NSArray * data = [self getAllPoints];
        for (OAOsmPoint *osmPoint in data)
        {
            double pointLat = osmPoint.getLatitude;
            double pointLon = osmPoint.getLongitude;
            if ([OAUtilities isCoordEqual:pointLat srcLon:pointLon destLat:lat destLon:lon])
            {
                if (OsmAnd::Utilities::distance(pointLon, pointLat, point.longitude, point.latitude) < 15) {
                    OATargetPoint *targetPoint = [self getTargetPoint:osmPoint];
                    if (![found containsObject:targetPoint])
                        [found addObject:targetPoint];
                }
            }
        }
    }
}

#pragma mark - OAMoveObjectProvider

- (BOOL)isObjectMovable:(id)object
{
    return [object isKindOfClass:OAOsmPoint.class];
}

- (void)applyNewObjectPosition:(id)object position:(CLLocationCoordinate2D)position
{
    if (object && [self isObjectMovable:object])
    {
        OAOsmPoint *p = (OAOsmPoint *)object;
        if ([p isKindOfClass:OAOpenStreetMapPoint.class])
        {
            OAOpenStreetMapPoint *point = (OAOpenStreetMapPoint *)p;
            [[OAOsmEditsDBHelper sharedDatabase] updateEditLocation:point.getId newPosition:position];
        }
        else if ([p isKindOfClass:OAOsmNotePoint.class])
        {
            OAOsmNotePoint *point = (OAOsmNotePoint *) p;
            [[OAOsmBugsDBHelper sharedDatabase] updateOsmBugLocation:point.getId newPosition:position];
        }
        [self.app.osmEditsChangeObservable notifyEvent];
    }
}

- (void)getOsmNoteBitmap:(sk_sp<SkImage> &)bitmap
{
    UIImage *img = [UIImage mapSvgImageNamed:@"mx_special_information"];
    bitmap = [OACompoundIconUtils createCompositeIconWithcolor:UIColorFromARGB(color_osm_edit) shapeName:DEFAULT_ICON_SHAPE_KEY iconName:@"special_information" isFullSize:YES icon:img scale:_textSize];
}

- (UIImage *) getPointIcon:(id)point
{
    sk_sp<SkImage> bitmap = [self getIcon:point];
    return [OAUtilities resizeImage:[OANativeUtilities skImageToUIImage:bitmap] newSize:CGSizeMake(60., 60.)];
}

- (void)setPointVisibility:(id)object hidden:(BOOL)hidden
{
    if (object && [self isObjectMovable:object])
    {
        OAOsmPoint *p = (OAOsmPoint *)object;
        const auto& pos = OsmAnd::Utilities::convertLatLonTo31(OsmAnd::LatLon([p getLatitude], [p getLongitude]));
        for (const auto& marker : _osmEditsCollection->getMarkers())
        {
            if (pos == marker->getPosition())
            {
                marker->setIsHidden(hidden);
            }
        }
    }
}

- (EOAPinVerticalAlignment) getPointIconVerticalAlignment
{
    return EOAPinAlignmentCenterVertical;
}


- (EOAPinHorizontalAlignment) getPointIconHorizontalAlignment
{
    return EOAPinAlignmentCenterHorizontal;
}

@end

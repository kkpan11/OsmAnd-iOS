//
//  OAGPXMutableDocument.m
//  OsmAnd
//
//  Created by Alexey Kulish on 30/04/15.
//  Copyright (c) 2015 OsmAnd. All rights reserved.
//

#import "OAGPXMutableDocument.h"
#import "OAUtilities.h"
#import "OAAppVersionDependentConstants.h"
#import "OAGPXAppearanceCollection.h"
#import "OANativeUtilities.h"

@implementation OAGPXMutableDocument
{
    std::shared_ptr<OsmAnd::GpxDocument> document;
    NSTimeInterval _analysisModifiedTime;
    OAGPXTrackAnalysis *_trackAnalysis;
}

@dynamic points, tracks, routes, pointsGroups;

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.metadata = [[OAMetadata alloc] init];
        self.points = [NSMutableArray array];
        self.tracks = [NSMutableArray array];
        self.routes = [NSMutableArray array];
        self.pointsGroups = [NSMutableDictionary dictionary];
        _modifiedTime = 0;
        _pointsModifiedTime = 0;
        
        document.reset(new OsmAnd::GpxDocument());
        
        [self initBounds];
    }
    return self;
}

- (instancetype)initWithGpxDocument:(std::shared_ptr<OsmAnd::GpxDocument>)gpxDocument
{
    self = [super initWithGpxDocument:gpxDocument];
    if (self)
    {
        document = gpxDocument;
        _modifiedTime = 0;
        _pointsModifiedTime = 0;
    }
    return self;
}

- (BOOL)loadFrom:(NSString *)filename
{
    if (filename && filename.length > 0)
    {
        document = OsmAnd::GpxDocument::loadFrom(QString::fromNSString(filename));
        _trackAnalysis = nil;
        _modifiedTime = 0;
        _pointsModifiedTime = 0;
        return [self fetch:document];
    }
    else
    {
        return false;
    }
}

- (const std::shared_ptr<OsmAnd::GpxDocument>&) getDocument
{
    return document;
}

- (void) updateDocAndMetadata
{
    std::shared_ptr<OsmAnd::GpxDocument::Metadata> metadata;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> wpt;
    std::shared_ptr<OsmAnd::GpxDocument::PointsGroup> pg;

    document->version = QString::fromNSString(self.version);
    document->creator = QString::fromNSString(self.creator);

    metadata.reset(new OsmAnd::GpxDocument::Metadata());
    if (self.metadata)
    {
        metadata->name = QString::fromNSString(self.metadata.name);
        metadata->description = QString::fromNSString(self.metadata.desc);

        OAWptPt *pt = [self findPointToShow];
        metadata->timestamp = pt != nil && pt.time > 0 ? QDateTime::fromTime_t(pt.time).toUTC() : QDateTime::currentDateTime().toUTC();

        [self.class fillLinks:metadata->links linkArray:self.metadata.links];
        
        [self.metadata fillExtensions:metadata];
    }
    document->metadata = metadata;
    metadata = nullptr;

    if (self.pointsGroups.count > 0)
    {
        BOOL hasExt = YES;
        OAGpxExtension *ext = [self getExtensionByKey:@"points_groups"];
        if (!ext)
        {
            hasExt = NO;
            ext = [[OAGpxExtension alloc] init];
            ext.name = @"points_groups";
        }

        for (NSString *key in self.pointsGroups.allKeys)
        {
            OAPointsGroup *pointsGroup = self.pointsGroups[key];
            NSDictionary *attributes = [pointsGroup toStringBundle];

            if ([ext containsSubextension:@"group" attributes:attributes])
                continue;

            pg.reset(new OsmAnd::GpxDocument::PointsGroup());
            pg->name = QString::fromNSString(pointsGroup.name);
            pg->iconName = QString::fromNSString(pointsGroup.iconName);
            pg->backgroundType = QString::fromNSString(pointsGroup.backgroundType);
            pg->color = [pointsGroup.color toFColorARGB];

            for (OAWptPt *wptPt in pointsGroup.points)
            {
                wpt.reset(new OsmAnd::GpxDocument::WptPt());
                [self.class fillWpt:wpt usingWpt:wptPt];
                pg->points.append(wpt);
                wpt = nullptr;
            }

            document->pointsGroups.insert(QString::fromNSString(key), pg);
            pg = nullptr;

            OAGpxExtension *subExt = [[OAGpxExtension alloc] init];
            subExt.name = @"group";
            subExt.attributes = attributes;
            [ext addSubextension:subExt];
        }

        if (!hasExt)
            [self addExtension:ext];
    }
    [self fillExtensions:document];
}

- (void)addPointsGroup:(OAPointsGroup *)group
{
    [self.points addObjectsFromArray:group.points];
    self.pointsGroups[group.name] = group;
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
    _pointsModifiedTime = _modifiedTime;
}

- (void)addPointsToGroups:(NSArray<OAWptPt *> *)points
{
    for (OAWptPt *point in points)
    {
        OAPointsGroup *pointsGroup = [self getOrCreateGroup:point];
        pointsGroup.pg->points.append(point.wpt);
        [pointsGroup.points addObject:point];
    }
}

- (OAPointsGroup *)getOrCreateGroup:(OAWptPt *)point
{
    OAPointsGroup *pointsGroup;

    if (point.type == nil && self.pointsGroups[kDefaultWptGroupName])
    {
        pointsGroup = self.pointsGroups[kDefaultWptGroupName];
    }
    else if (self.pointsGroups[point.type])
    {
        pointsGroup = self.pointsGroups[point.type];
    }
    else
    {
        pointsGroup = [[OAPointsGroup alloc] initWithWptPt:point];
        self.pointsGroups[pointsGroup.name] = pointsGroup;
    }
    if (pointsGroup.pg == nullptr)
    {
        std::shared_ptr<OsmAnd::GpxDocument::PointsGroup> pg;
        pg.reset(new OsmAnd::GpxDocument::PointsGroup());
        pg->name = QString::fromNSString(point.type);
        pg->iconName = QString::fromNSString([point getIcon]);
        pg->backgroundType = QString::fromNSString([point getBackgroundIcon]);
        pg->color = [[point getColor] toFColorARGB];
        pointsGroup.pg = pg;
    }
    if (!document->pointsGroups.contains(QString::fromNSString(point.type)))
        document->pointsGroups.insert(QString::fromNSString(point.type), pointsGroup.pg);
    return pointsGroup;
}

- (void) addWpts:(NSArray<OAWptPt *> *)wpts
{
    [wpts enumerateObjectsUsingBlock:^(OAWptPt * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self addWpt:obj];
    }];
}

- (void) addWpt:(OAWptPt *)w
{
    NSMutableArray<OAGpxExtension *> *extArray = [w.extensions mutableCopy];

    int color = [w getColor:0];
    if (color != 0 && ![w getExtensionByKey:@"color"])
    {
        OAGpxExtension *e = [[OAGpxExtension alloc] init];
        e.name = @"color";
        e.value = UIColorFromRGBA(color).toHexRGBAString;
        [extArray addObject:e];
    }
    w.extensions = extArray;

    std::shared_ptr<OsmAnd::GpxDocument::WptPt> wpt;
    wpt.reset(new OsmAnd::GpxDocument::WptPt());
    [self.class fillWpt:wpt usingWpt:w];
    w.wpt = wpt;
    document->points.append(wpt);
    wpt = nullptr;

    [self processBounds:w.position];
    
    [self.points addObject:w];
    [self addPointsToGroups:@[w]];
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
    _pointsModifiedTime = _modifiedTime;
}

- (void)deleteWpt:(OAWptPt *)w
{
    for (OAWptPt *wpt in self.points)
    {
        if (wpt == w || wpt.time == w.time)
        {
            [self.points removeObject:wpt];
            document->points.removeOne(wpt.wpt);
            w.wpt = nullptr;
            break;
        }
    }
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
    _pointsModifiedTime = _modifiedTime;
}

- (void)deleteAllWpts
{
    [self.points removeAllObjects];
    document->points.clear();
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
    _pointsModifiedTime = _modifiedTime;
}

- (void) addRoutePoints:(NSArray<OAWptPt *> *)points addRoute:(BOOL)addRoute
{
    if (self.routes.count == 0 || addRoute)
    {
        OARoute *route = [[OARoute alloc] init];
        [self addRoute:route];
    }
    for (OAWptPt *pt in points)
        [self addRoutePoint:pt route:self.routes.lastObject];
}

- (void) addRoutes:(NSArray<OARoute *> *)routes
{
    [routes enumerateObjectsUsingBlock:^(OARoute * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self addRoute:obj];
    }];
}

- (void) addRoute:(OARoute *)r
{
    std::shared_ptr<OsmAnd::GpxDocument::Route> rte;
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> rtept;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;

    if (!r.points)
        r.points = [NSMutableArray new];
    
    rte.reset(new OsmAnd::GpxDocument::Route());
    rte->name = QString::fromNSString(r.name);
    rte->description = QString::fromNSString(r.desc);

    for (OAWptPt *p in r.points)
    {
        rtept.reset(new OsmAnd::GpxDocument::WptPt());
        rtept->position.latitude = p.position.latitude;
        rtept->position.longitude = p.position.longitude;
        rtept->name = QString::fromNSString(p.name);
        rtept->description = QString::fromNSString(p.desc);
        rtept->elevation = p.elevation;
        rtept->timestamp = p.time != 0 ? QDateTime::fromTime_t(p.time).toUTC() : QDateTime().toUTC();
        rtept->comment = QString::fromNSString(p.comment);
        rtept->type = QString::fromNSString(p.type);
        rtept->horizontalDilutionOfPrecision = p.horizontalDilutionOfPrecision;
        rtept->verticalDilutionOfPrecision = p.verticalDilutionOfPrecision;
        rtept->heading = p.heading;
        rtept->speed = p.speed;
        
        [self.class fillLinks:rtept->links linkArray:p.links];

        [p fillExtensions:rtept];
        
        p.wpt = rtept;
        rte->points.append(rtept);
        rtept = nullptr;
        
        [self processBounds:p.position];
    }
    
    [r fillExtensions:rte];

    r.rte = rte;
    document->routes.append(rte);
    rte = nullptr;
    
    [self.routes addObject:r];
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
}

- (void) addRoutePoint:(OAWptPt *)p route:(OARoute *)route
{
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> rtept;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;

    rtept.reset(new OsmAnd::GpxDocument::WptPt());
    rtept->position.latitude = p.position.latitude;
    rtept->position.longitude = p.position.longitude;
    rtept->name = QString::fromNSString(p.name);
    rtept->description = QString::fromNSString(p.desc);
    rtept->elevation = p.elevation;
    rtept->timestamp = p.time != 0 ? QDateTime::fromTime_t(p.time).toUTC() : QDateTime().toUTC();
    rtept->comment = QString::fromNSString(p.comment);
    rtept->type = QString::fromNSString(p.type);
    rtept->horizontalDilutionOfPrecision = p.horizontalDilutionOfPrecision;
    rtept->verticalDilutionOfPrecision = p.verticalDilutionOfPrecision;
    rtept->heading = p.heading;
    rtept->speed = p.speed;
    
    [self.class fillLinks:rtept->links linkArray:p.links];
    
    [p fillExtensions:rtept];

    p.wpt = rtept;
    route.rte->points.append(rtept);
    rtept = nullptr;
    
    [self processBounds:p.position];

    [((NSMutableArray *)route.points) addObject:p];
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
    _pointsModifiedTime = _modifiedTime;
}

- (void) addTracks:(NSArray<OATrack *> *)tracks
{
    [tracks enumerateObjectsUsingBlock:^(OATrack * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self addTrack:obj];
    }];
}

- (void) addTrack:(OATrack *)t
{
    std::shared_ptr<OsmAnd::GpxDocument::Track> trk;
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> trkpt;
    std::shared_ptr<OsmAnd::GpxDocument::TrkSegment> trkseg;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;

    if (!t.segments)
        t.segments = [NSMutableArray array];
    
    trk.reset(new OsmAnd::GpxDocument::Track());
    trk->name = QString::fromNSString(t.name);
    trk->description = QString::fromNSString(t.desc);

    for (OATrkSegment *s in t.segments)
    {
        trkseg.reset(new OsmAnd::GpxDocument::TrkSegment());
        
        for (OAWptPt *p in s.points)
        {
            trkpt.reset(new OsmAnd::GpxDocument::WptPt());
            trkpt->position.latitude = p.position.latitude;
            trkpt->position.longitude = p.position.longitude;
            trkpt->name = QString::fromNSString(p.name);
            trkpt->description = QString::fromNSString(p.desc);
            trkpt->elevation = p.elevation;
            trkpt->timestamp = p.time != 0 ? QDateTime::fromTime_t(p.time).toUTC() : QDateTime().toUTC();
            trkpt->comment = QString::fromNSString(p.comment);
            trkpt->type = QString::fromNSString(p.type);
            trkpt->horizontalDilutionOfPrecision = p.horizontalDilutionOfPrecision;
            trkpt->verticalDilutionOfPrecision = p.verticalDilutionOfPrecision;
            trkpt->heading = p.heading;
            trkpt->speed = p.speed;
            
            [self.class fillLinks:trkpt->links linkArray:p.links];

            [p fillExtensions:trkpt];

            p.wpt = trkpt;
            trkseg->points.append(trkpt);
            trkpt = nullptr;
            
            [self processBounds:p.position];
        }
        
        [s fillExtensions:trkseg];

        s.trkseg = trkseg;
        trk->segments.append(trkseg);
        trkseg = nullptr;
    }

    [t fillExtensions:trk];

    t.trk = trk;
    document->tracks.append(trk);
    trk = nullptr;
    
    [self.tracks addObject:t];
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
}

- (void)addTrackSegment:(OATrkSegment *)s track:(OATrack *)track
{
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> trkpt;
    std::shared_ptr<OsmAnd::GpxDocument::TrkSegment> trkseg;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;

    if (!s.points)
        s.points = [NSMutableArray array];
    
    trkseg.reset(new OsmAnd::GpxDocument::TrkSegment());
    
    for (OAWptPt *p in s.points)
    {
        trkpt.reset(new OsmAnd::GpxDocument::WptPt());
        trkpt->position.latitude = p.position.latitude;
        trkpt->position.longitude = p.position.longitude;
        trkpt->name = QString::fromNSString(p.name);
        trkpt->description = QString::fromNSString(p.desc);
        trkpt->elevation = p.elevation;
        trkpt->timestamp = p.time != 0 ? QDateTime::fromTime_t(p.time).toUTC() : QDateTime().toUTC();
        trkpt->comment = QString::fromNSString(p.comment);
        trkpt->type = QString::fromNSString(p.type);
        trkpt->horizontalDilutionOfPrecision = p.horizontalDilutionOfPrecision;
        trkpt->verticalDilutionOfPrecision = p.verticalDilutionOfPrecision;
        trkpt->heading = p.heading;
        trkpt->speed = p.speed;
        
        [self.class fillLinks:trkpt->links linkArray:p.links];

        [p fillExtensions:trkpt];

        p.wpt = trkpt;
        trkseg->points.append(trkpt);
        trkpt = nullptr;

        [self processBounds:p.position];
    }
    
    [s fillExtensions:trkseg];

    s.trkseg = trkseg;
    track.trk->segments.append(trkseg);
    trkseg = nullptr;

    if ([track.segments isKindOfClass:NSMutableArray.class])
    {
        [((NSMutableArray *)track.segments) addObject:s];
    }
    else
    {
        NSMutableArray<OATrkSegment *> *segments = [NSMutableArray arrayWithArray:track.segments];
        [segments addObject:s];
        track.segments = segments;
    }

    _modifiedTime = [[NSDate date] timeIntervalSince1970];
}

- (BOOL)removeTrackSegment:(OATrkSegment *)segment
{
    [self removeGeneralTrackIfExists];

    for (OATrack *track in self.tracks)
    {
        if ([track.segments containsObject:segment] && segment.trkseg != nullptr)
        {
            BOOL removed = track.trk->segments.removeOne(std::dynamic_pointer_cast<OsmAnd::GpxDocument::TrkSegment>(segment.trkseg));
            if (removed)
            {
                if (track.segments.count > 1)
                {
                    NSMutableArray<OATrkSegment *> *segments = [NSMutableArray array];
                    for (OATrkSegment *trackSeg in track.segments)
                    {
                        if (trackSeg != segment)
                            [segments addObject:trackSeg];
                    }
                    track.segments = segments;
                }
                else
                {
                    track.segments = [NSMutableArray array];
                }

                [self addGeneralTrack];
                _modifiedTime = [[NSDate date] timeIntervalSince1970];
            }
            return removed;
        }
    }
    return NO;
}

- (void)removeGeneralTrackIfExists
{
    if (self.generalTrack)
    {
        NSMutableArray *tracks = [self.tracks mutableCopy];
        [tracks removeObject:self.generalTrack];
        self.tracks = tracks;
        self.generalTrack = nil;
        self.generalSegment = nil;
        _modifiedTime = [[NSDate date] timeIntervalSince1970];
    }
}

- (void) addTrackPoint:(OAWptPt *)p segment:(OATrkSegment *)segment
{
    std::shared_ptr<OsmAnd::GpxDocument::WptPt> trkpt;
    std::shared_ptr<OsmAnd::GpxDocument::Link> link;

    trkpt.reset(new OsmAnd::GpxDocument::WptPt());
    trkpt->position.latitude = p.position.latitude;
    trkpt->position.longitude = p.position.longitude;
    trkpt->name = QString::fromNSString(p.name);
    trkpt->description = QString::fromNSString(p.desc);
    trkpt->elevation = p.elevation;
    trkpt->timestamp = p.time != 0 ? QDateTime::fromTime_t(p.time).toUTC() : QDateTime().toUTC();
    trkpt->comment = QString::fromNSString(p.comment);
    trkpt->type = QString::fromNSString(p.type);
    trkpt->horizontalDilutionOfPrecision = p.horizontalDilutionOfPrecision;
    trkpt->verticalDilutionOfPrecision = p.verticalDilutionOfPrecision;
    trkpt->heading = p.heading;
    trkpt->speed = p.speed;
    
    [self.class fillLinks:trkpt->links linkArray:p.links];
    
    [p fillExtensions:trkpt];

    p.wpt = trkpt;
    segment.trkseg->points.append(trkpt);
    trkpt = nullptr;
    
    [self processBounds:p.position];

    [((NSMutableArray *)segment.points) addObject:p];
    _modifiedTime = [[NSDate date] timeIntervalSince1970];
}

- (BOOL) saveTo:(NSString *)filename
{
    [self updateDocAndMetadata];
    [self applyBounds];
    return document->saveTo(QString::fromNSString(filename), QString::fromNSString([OAAppVersionDependentConstants getAppVersionWithBundle]));
}

- (BOOL) writeGpxFile:(NSString *)filename
{
    OAWptPt *pt = [self findPointToShow];
    if (pt && self.metadata)
        self.metadata.time = pt.time;
    return [super saveTo:filename];
}

- (OAGPXTrackAnalysis*) getAnalysis:(long)fileTimestamp
{
    NSTimeInterval modifiedTime = _modifiedTime;
    if (!_trackAnalysis || _analysisModifiedTime != modifiedTime)
        [self update:modifiedTime];
    return _trackAnalysis;
}

- (void) update:(NSTimeInterval)modifiedTime
{
    _analysisModifiedTime = modifiedTime;
    
    NSTimeInterval fileTimestamp = 0;
    if (self.path && self.path.length > 0)
    {
        NSFileManager *manager = NSFileManager.defaultManager;
        NSError *err = nil;
        NSDictionary *attrs = [manager attributesOfItemAtPath:self.path error:&err];
        if (!err)
            fileTimestamp = attrs.fileModificationDate.timeIntervalSince1970;
    }
    else
    {
        fileTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    
    _trackAnalysis = [super getAnalysis:fileTimestamp];
}

@end

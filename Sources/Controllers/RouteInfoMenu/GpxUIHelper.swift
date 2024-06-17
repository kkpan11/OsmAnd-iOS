//
//  OARouteStatisticsViewController.swift
//  OsmAnd
//
//  Created by Paul on 9/3/19.
//  Copyright © 2019 OsmAnd. All rights reserved.
//

import UIKit
import Charts

@objc public enum GPXDataSetType: Int {
    case altitude, speed, slope, sensorSpeed, sensorHeartRate, sensorBikePower, sensorBikeCadence, sensorTemperature

    public func getTitle() -> String {
        OAGPXDataSetType.getTitle(self.rawValue)
    }

    public func getIconName() -> String {
        OAGPXDataSetType.getIconName(self.rawValue)
    }

    public func getDatakey() -> String {
        OAGPXDataSetType.getDataKey(self.rawValue)
    }

    public func getTextColor() -> UIColor {
        OAGPXDataSetType.getTextColor(self.rawValue)
    }

    public func getFillColor() -> UIColor {
        OAGPXDataSetType.getFillColor(self.rawValue)
    }

    public func getMainUnitY() -> String {
        OAGPXDataSetType.getMainUnitY(self.rawValue)
    }
}

@objc public enum GPXDataSetAxisType: Int {
    case distance, time, timeOfDay

    public func getName() -> String {
        switch self {
        case .distance:
            return OAUtilities.getLocalizedString("shared_string_distance");
        case .time:
            return OAUtilities.getLocalizedString("shared_string_time");
        case .timeOfDay:
            return OAUtilities.getLocalizedString("time_of_day");
        }
    }

    public func getImageName() -> String {
        switch self {
        case .distance:
            return ""
        case .time:
            return ""
        case .timeOfDay:
            return ""
        }
    }
}

@objc class GpxUIHelper: NSObject {
    
    static let METERS_IN_KILOMETER: Double = 1000
    static let METERS_IN_ONE_NAUTICALMILE: Double = 1852
    static let METERS_IN_ONE_MILE: Double = 1609.344
    static let FEET_IN_ONE_METER: Double = 3.2808
    static let YARDS_IN_ONE_METER: Double = 1.0936
    
    private static let MAX_CHART_DATA_ITEMS: Double = 10000
    
    final class ValueFormatter: IAxisValueFormatter
    {
        private var formatX: String?
        private var unitsX: String
        
        init(formatX: String?, unitsX: String) {
            self.formatX = formatX
            self.unitsX = unitsX
        }
        
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            if (formatX != nil && formatX?.length ?? 0 > 0) {
                return String(format: formatX!, value) + " " + self.unitsX
            } else {
                return String(format: "%.0f", value) + " " + self.unitsX
            }
        }
    }
    
    private class HeightFormatter: IFillFormatter
    {
        func getFillLinePosition(dataSet: ILineChartDataSet, dataProvider: LineChartDataProvider) -> CGFloat {
            return CGFloat(dataProvider.chartYMin)
        }
    }
    
    private class TimeFormatter: IAxisValueFormatter
    {
        private var useHours: Bool
        
        init(useHours: Bool) {
            self.useHours = useHours
        }
        
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            let seconds = Int(value)
            if (useHours) {
                let hours = seconds / (60 * 60)
                let minutes = (seconds / 60) % 60
                let sec = seconds % 60
                let strHours = String(hours)
                let strMinutes = String(minutes)
                let strSeconds = String(sec)
                return strHours + ":" + (minutes < 10 ? "0" + strMinutes : strMinutes) + ":" + (sec < 10 ? "0" + strSeconds : strSeconds)
            } else {
                let minutes = (seconds / 60) % 60
                let sec = seconds % 60
                let strMinutes = String(minutes)
                let strSeconds = String(sec)
                return (minutes < 10 ? "0" + strMinutes : strMinutes) + ":" + (sec < 10 ? "0" + strSeconds : strSeconds)
            }
        }
    }
    
    private class TimeSpanFormatter : IAxisValueFormatter
    {
        private var startTime: Int64
        
        init(startTime: Int64) {
            self.startTime = startTime
        }
        
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            let seconds = Double(startTime/1000) + value
            let date = Date(timeIntervalSince1970: seconds)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            dateFormatter.timeZone = .current
            return dateFormatter.string(from: date)
        }
    }

    final class OrderedLineDataSet: LineChartDataSet {
        
        private var dataSetType: GPXDataSetType;
        private var dataSetAxisType: GPXDataSetAxisType;
        
        var priority: Float;
        var units: String;
        var divX: Double = 1;
        var divY: Double = 1;
        var mulY: Double = 1;
        var color: UIColor;
        
        init(entries: [ChartDataEntry]?, label: String?, dataSetType: GPXDataSetType, dataSetAxisType: GPXDataSetAxisType) {
            self.dataSetType = dataSetType
            self.dataSetAxisType = dataSetAxisType
            self.priority = 0
            self.units = ""
            self.color = dataSetType.getTextColor()
            super.init(entries: entries, label: label)
            self.mode = LineChartDataSet.Mode.linear
        }
        
        required init() {
            fatalError("init() has not been implemented")
        }
        
        public func getDataSetType() -> GPXDataSetType {
            return dataSetType;
        }
        
        public func getDataSetAxisType() -> GPXDataSetAxisType {
            return dataSetAxisType;
        }
        
        public func getPriority() -> Float {
            return priority;
        }
        
        public override func getDivX() -> Double {
            return divX;
        }
        
        public func getDivY() -> Double {
            return divY;
        }
        
        public func getMulY() -> Double {
            return mulY;
        }
        
        public func getUnits() -> String {
            return units;
        }
    }

    @objc static public func getDivX(dataSet: IChartDataSet) -> Double
    {
        let orderedDataSet: OrderedLineDataSet? = dataSet as? OrderedLineDataSet
        return orderedDataSet?.divX ?? 0
    }

    @objc static public func getDataSetAxisType(dataSet: IChartDataSet) -> GPXDataSetAxisType
    {
        let orderedDataSet: OrderedLineDataSet? = dataSet as? OrderedLineDataSet
        return orderedDataSet?.getDataSetAxisType() ?? GPXDataSetAxisType.distance
    }

    private class GPXChartMarker: MarkerView {
        
        private var text: NSAttributedString = NSAttributedString(string: "")
        
        private let widthOffset: CGFloat = 3.0
        private let heightOffset: CGFloat = 2.0

        override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
            super.refreshContent(entry: entry, highlight: highlight)
            
            let chartData = self.chartView?.data
            
            let res = NSMutableAttributedString(string: "")
            
            
            if (chartData?.dataSetCount ?? 0 == 1)
            {
                let dataSet = chartData?.dataSets[0] as! OrderedLineDataSet
                res.append(NSAttributedString(string: "\(lround(entry.y)) " + dataSet.units, attributes:[NSAttributedString.Key.foregroundColor: dataSet.color]))
            }
            else if (chartData?.dataSetCount ?? 0 == 2) {
                let dataSet1 = chartData?.dataSets[0] as! OrderedLineDataSet
                let dataSet2 = chartData?.dataSets[1] as! OrderedLineDataSet

                let useFirst = dataSet1.visible
                let useSecond = dataSet2.visible

                if (useFirst) {
                    let entry1 = dataSet1.entryForXValue(entry.x, closestToY: Double.nan, rounding: .up)
                    
                    res.append(NSAttributedString(string: "\(lround(entry1?.y ?? 0)) " + dataSet1.units, attributes:[NSAttributedString.Key.foregroundColor: dataSet1.color]))
                }
                if (useSecond) {
                    let entry2 = dataSet2.entryForXValue(entry.x, closestToY: Double.nan, rounding: .up)
                    
                    if (useFirst) {
                        res.append(NSAttributedString(string: ", \(lround(entry2?.y ?? 0)) " + dataSet2.units, attributes:[NSAttributedString.Key.foregroundColor: dataSet2.color]))
                    } else {
                        res.append(NSAttributedString(string: "\(lround(entry2?.y ?? 0)) " + dataSet2.units, attributes:[NSAttributedString.Key.foregroundColor: dataSet2.color]))
                    }
                }
            }
            text = res
        }

        override func draw(context: CGContext, point: CGPoint) {
            super.draw(context: context, point: point)
            
            self.bounds.size = text.size()
            self.offset = CGPoint(x: 0.0, y: 0.0)

            let offset = self.offsetForDrawing(atPoint: CGPoint(x: point.x - text.size().width / 2 + widthOffset, y: point.y))
            
            let labelRect = CGRect(origin: CGPoint(x: point.x - text.size().width / 2 + offset.x, y: heightOffset), size: self.bounds.size)
            
            let outline = CALayer()
            
            outline.borderColor = UIColor.chartSliderLabelStroke.cgColor
            outline.backgroundColor = UIColor.chartSliderLabelBg.cgColor
            outline.borderWidth = 1.0
            outline.cornerRadius = 2.0
            outline.bounds = CGRect(origin: CGPoint(x: labelRect.origin.x - widthOffset, y: labelRect.origin.y), size: CGSize(width: labelRect.size.width + widthOffset * 2, height: labelRect.size.height + heightOffset * 2))
            
            outline.render(in: context)
            
            drawText(text: text, rect: labelRect)
        }

        private func drawText(text: NSAttributedString, rect: CGRect) {
            let size = text.size()
            let centeredRect = CGRect(x: rect.origin.x, y: rect.origin.y + (rect.size.height + heightOffset - size.height) / 2.0, width: size.width, height: size.height)
            text.draw(in: centeredRect)
        }
        
        open override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint
        {
            guard let chart = chartView else { return self.offset }
            
            var offset = self.offset
            
            let width = self.bounds.size.width
            let height = self.bounds.size.height
            
            if point.x + offset.x < chart.extraLeftOffset
            {
                offset.x = -point.x + chart.extraLeftOffset + widthOffset * 2
            }
            else if point.x + width + offset.x > chart.bounds.size.width - chart.extraRightOffset
            {
                offset.x = chart.bounds.size.width - point.x - width - chart.extraRightOffset
            }
            
            if point.y + offset.y < 0
            {
                offset.y = -point.y
            }
            else if point.y + height + offset.y > chart.bounds.size.height
            {
                offset.y = chart.bounds.size.height - point.y - height
            }
            
            return offset
        }
    }

    private static func getDataSet(chartView: LineChartView,
                                   analysis: OAGPXTrackAnalysis,
                                   type: GPXDataSetType,
                                   calcWithoutGaps: Bool,
                                   useRightAxis: Bool) -> OrderedLineDataSet? {
        switch type {
            case .altitude:
            return createGPXElevationDataSet(chartView: chartView, analysis: analysis, graphType: type, axisType: GPXDataSetAxisType.distance, useRightAxis: useRightAxis, drawFilled: true, calcWithoutGaps: calcWithoutGaps)
            case .slope:
                return createGPXSlopeDataSet(chartView: chartView, analysis: analysis, graphType: type, axisType: GPXDataSetAxisType.distance, eleValues: Array(), useRightAxis: useRightAxis, drawFilled: true, calcWithoutGaps: calcWithoutGaps)
            case .speed:
                return createGPXSpeedDataSet(chartView: chartView, analysis: analysis, graphType: type, axisType: GPXDataSetAxisType.distance, useRightAxis: useRightAxis, drawFilled: true, calcWithoutGaps: calcWithoutGaps)
            default:
            return OAPluginsHelper.getOrderedLineDataSet(chart: chartView, analysis: analysis, graphType: type, axisType: GPXDataSetAxisType.distance, calcWithoutGaps: calcWithoutGaps, useRightAxis: useRightAxis)
        }
    }

        @objc static public func refreshLineChart(chartView: LineChartView,
                                              analysis: OAGPXTrackAnalysis,
                                              useGesturesAndScale: Bool,
                                              firstType: GPXDataSetType,
                                              useRightAxis: Bool,
                                              calcWithoutGaps: Bool)
    {
        var dataSets = [ILineChartDataSet]()
        let firstDataSet: OrderedLineDataSet? = getDataSet(chartView: chartView, analysis: analysis, type: firstType, calcWithoutGaps: calcWithoutGaps, useRightAxis: useRightAxis)
        if (firstDataSet != nil) {
            dataSets.append(firstDataSet!);
        }
        if (useRightAxis) {
            chartView.leftAxis.enabled = false
            chartView.leftAxis.drawLabelsEnabled = false
            chartView.leftAxis.drawGridLinesEnabled = false
            chartView.rightAxis.enabled = true
        }
        else {
            chartView.rightAxis.enabled = false
            chartView.leftAxis.enabled = true
        }

        var highlightValues: Array<Highlight> = []
        for i in 0..<chartView.highlighted.count
        {
            var h: Highlight = chartView.highlighted[i]
            h = Highlight(x: h.x, y: h.y, xPx: h.xPx, yPx: h.yPx, dataIndex: h.dataIndex, dataSetIndex: dataSets.count - 1, stackIndex: h.stackIndex, axis: h.axis)
            highlightValues.append(h)
        }
        chartView.clear()
        chartView.data = LineChartData(dataSets: dataSets)
        chartView.highlightValues(highlightValues)
    }

    @objc static public func refreshLineChart(chartView: LineChartView,
                                              analysis: OAGPXTrackAnalysis,
                                              useGesturesAndScale: Bool,
                                              firstType: GPXDataSetType,
                                              secondType: GPXDataSetType,
                                              calcWithoutGaps: Bool)
    {
        var dataSets = [ILineChartDataSet]()
        let firstDataSet: OrderedLineDataSet? = getDataSet(chartView: chartView, analysis: analysis, type: firstType, calcWithoutGaps: calcWithoutGaps, useRightAxis: false)
        let secondDataSet: OrderedLineDataSet? = getDataSet(chartView: chartView, analysis: analysis, type: secondType, calcWithoutGaps: calcWithoutGaps, useRightAxis: true)

        if (firstDataSet != nil) {
            dataSets.append(firstDataSet!);
        }

        if (secondDataSet != nil)
        {
            dataSets.append(secondDataSet!)
            chartView.leftAxis.drawLabelsEnabled = false
            chartView.leftAxis.drawGridLinesEnabled = false
        } else {
            chartView.rightAxis.enabled = false
            chartView.leftAxis.enabled = true
        }
        var highlightValues: Array<Highlight> = []
        for i in 0..<chartView.highlighted.count
        {
            var h: Highlight = chartView.highlighted[i]
            h = Highlight(x: h.x, y: h.y, xPx: h.xPx, yPx: h.yPx, dataIndex: h.dataIndex, dataSetIndex: dataSets.count - 1, stackIndex: h.stackIndex, axis: h.axis)
            highlightValues.append(h)
        }
        chartView.clear()
        chartView.data = LineChartData(dataSets: dataSets)
        chartView.highlightValues(highlightValues)
    }
    
    @objc static public func refreshBarChart(chartView: HorizontalBarChartView, statistics: OARouteStatistics, analysis: OAGPXTrackAnalysis, nightMode: Bool)
    {
        setupHorizontalGPXChart(chart: chartView, yLabelsCount: 4, topOffset: 20, bottomOffset: 4, useGesturesAndScale: true, nightMode: nightMode)
        chartView.extraLeftOffset = 16
        chartView.extraRightOffset = 16
        
        let barData = buildStatisticChart(chartView: chartView, routeStatistics: statistics, analysis: analysis, useRightAxis: true, nightMode: nightMode)
        
        chartView.data = barData
    }
    
    public static func setupHorizontalGPXChart(chart: HorizontalBarChartView, yLabelsCount : Int,
                                               topOffset: CGFloat, bottomOffset: CGFloat, useGesturesAndScale: Bool, nightMode: Bool) {
        chart.isUserInteractionEnabled = useGesturesAndScale
        chart.dragEnabled = useGesturesAndScale
        chart.scaleYEnabled = false
        chart.autoScaleMinMaxEnabled = true
        chart.drawBordersEnabled = true
        chart.chartDescription?.enabled = false
        chart.dragDecelerationEnabled = false
        chart.highlightPerTapEnabled = false
        chart.highlightPerDragEnabled = true
        
        chart.renderer = CustomBarChartRenderer(dataProvider: chart, animator: chart.chartAnimator, viewPortHandler: chart.viewPortHandler)

        chart.extraTopOffset = topOffset
        chart.extraBottomOffset = bottomOffset

        let xl = chart.xAxis
        xl.drawLabelsEnabled = false
        xl.enabled = false
        xl.drawAxisLineEnabled = false
        xl.drawGridLinesEnabled = false

        let yl = chart.leftAxis
        yl.labelCount = yLabelsCount
        
        yl.drawLabelsEnabled = false
        yl.enabled = false
        yl.drawAxisLineEnabled = false
        yl.drawGridLinesEnabled = false
        yl.axisMinimum = 0.0;

        let yr = chart.rightAxis
        yr.labelCount = yLabelsCount
        yr.drawAxisLineEnabled = false
        yr.drawGridLinesEnabled = false
        yr.axisMinimum = 0.0
        
        chart.minOffset = 16

        let mainFontColor = nightMode ? UIColor(rgbValue: color_icon_color_light) : .black
        yl.labelTextColor = mainFontColor
        yr.labelTextColor = mainFontColor

        chart.fitBars = true
        chart.highlightFullBarEnabled = false
        
        chart.borderColor = nightMode ? UIColor(rgbValue: color_icon_color_light) : .black
        
        chart.legend.enabled = false
    }

    @objc static public func setupGPXChart(chartView: LineChartView, yLabelsCount: Int, topOffset: CGFloat, bottomOffset: CGFloat, useGesturesAndScale: Bool)
    {
        chartView.clear()
        chartView.fitScreen()
        chartView.layer.drawsAsynchronously = true
        
        chartView.isUserInteractionEnabled = useGesturesAndScale
        chartView.dragEnabled = useGesturesAndScale
        chartView.setScaleEnabled(useGesturesAndScale)
        chartView.pinchZoomEnabled = useGesturesAndScale
        chartView.scaleYEnabled = false
        chartView.autoScaleMinMaxEnabled = true
        chartView.drawBordersEnabled = false
        chartView.chartDescription?.enabled = false
        chartView.maxVisibleCount = 10
        chartView.minOffset = 0.0
        chartView.rightYAxisRenderer = YAxisCombinedRenderer(viewPortHandler: chartView.viewPortHandler, yAxis: chartView.rightAxis, secondaryYAxis: chartView.leftAxis, transformer: chartView.getTransformer(forAxis: .right), secondaryTransformer:chartView.getTransformer(forAxis: .left))
        chartView.extraLeftOffset = 16
        chartView.extraRightOffset = 16
        chartView.dragDecelerationEnabled = false
        
        chartView.extraTopOffset = topOffset
        chartView.extraBottomOffset = bottomOffset

        let marker = GPXChartMarker()
        marker.chartView = chartView
        chartView.marker = marker
        chartView.drawMarkers = true
        
        let labelsColor = UIColor.chartTextColorAxisX
        let xAxis: XAxis = chartView.xAxis;
        xAxis.drawAxisLineEnabled = false
        xAxis.drawGridLinesEnabled = false
        xAxis.gridLineWidth = 1.5
        xAxis.gridColor = UIColor.chartAxisGridLine
        xAxis.gridLineDashLengths = [10]
        xAxis.labelPosition = .bottom
        xAxis.labelTextColor = labelsColor
        xAxis.resetCustomAxisMin()
        let yColor = UIColor.chartAxisGridLine
        var yAxis: YAxis = chartView.leftAxis;
        yAxis.gridLineDashLengths = [4.0, 4.0]
        yAxis.gridColor = yColor
        yAxis.drawAxisLineEnabled = false
        yAxis.drawGridLinesEnabled = true
        yAxis.labelPosition = .insideChart
        yAxis.xOffset = 16.0
        yAxis.yOffset = -6.0
        yAxis.labelCount = yLabelsCount
        yAxis.labelTextColor = UIColor.chartTextColorAxisX
        yAxis.labelFont = UIFont.systemFont(ofSize: 11)
        
        yAxis = chartView.rightAxis;
        yAxis.gridLineDashLengths = [4.0, 4.0]
        yAxis.gridColor = yColor
        yAxis.drawAxisLineEnabled = false
        yAxis.drawGridLinesEnabled = true
        yAxis.labelPosition = .insideChart
        yAxis.xOffset = 16.0
        yAxis.yOffset = -6.0
        yAxis.labelCount = yLabelsCount
        xAxis.labelTextColor = labelsColor
        yAxis.enabled = false
        yAxis.labelFont = UIFont.systemFont(ofSize: 11)
        
        let legend = chartView.legend
        legend.enabled = false
    }
    
    private static func buildStatisticChart(chartView: HorizontalBarChartView,
                                           routeStatistics: OARouteStatistics,
                                           analysis: OAGPXTrackAnalysis,
                                           useRightAxis: Bool,
                                           nightMode: Bool) -> BarChartData {

        let xAxis = chartView.xAxis
        xAxis.enabled = false

        var yAxis: YAxis
        if (useRightAxis) {
            yAxis = chartView.rightAxis
            yAxis.enabled = true
        } else {
            yAxis = chartView.leftAxis
        }
        let divX = setupAxisDistance(axisBase: yAxis, meters: Double(analysis.totalDistance))

        let segments = routeStatistics.elements
        var entries = [BarChartDataEntry]()
        var stacks = Array(repeating: 0 as Double, count: segments?.count ?? 0)
        
        var colors = Array(repeating: NSUIColor(cgColor: UIColor.white.cgColor), count: segments?.count ?? 0)
        
        for i in 0..<stacks.count {
            let segment: OARouteSegmentAttribute = segments![i]
            
            stacks[i] = Double(segment.distance) / divX
            colors[i] = NSUIColor(cgColor: UIColor(argbValue: UInt32(segment.color)).cgColor)
        }
        
        entries.append(BarChartDataEntry(x: 0, yValues: stacks))
        
        let barDataSet = BarChartDataSet(entries: entries, label: "")
        barDataSet.colors = colors
        barDataSet.highlightColor = UIColor(rgbValue: color_primary_purple)
        
        let dataSet = BarChartData(dataSet: barDataSet)
        
        dataSet.setDrawValues(false)
        dataSet.barWidth = 1
        
        chartView.rightAxis.axisMaximum = dataSet.yMax
        chartView.leftAxis.axisMaximum = dataSet.yMax

        return dataSet
    }
    
    private static func createGPXElevationDataSet(chartView: LineChartView,
                                                  analysis: OAGPXTrackAnalysis,
                                                  graphType: GPXDataSetType,
                                                  axisType: GPXDataSetAxisType,
                                                  useRightAxis: Bool,
                                                  drawFilled: Bool,
                                                  calcWithoutGaps: Bool) -> OrderedLineDataSet {
        let useFeet: Bool = OAMetricsConstant.shouldUseFeet(OAAppSettings.sharedManager().metricSystem.get())
        let convEle: Double = useFeet ? 3.28084 : 1.0
        let divX: Double = getDivX(lineChart: chartView, analysis: analysis, axisType: axisType, calcWithoutGaps: calcWithoutGaps)
        let mainUnitY: String = graphType.getMainUnitY()

        let yAxis: YAxis  = getYAxis(chart: chartView, textColor: UIColor.chartTextColorElevation, useRightAxis: useRightAxis)
        yAxis.granularity = 1
        yAxis.resetCustomAxisMax()
        yAxis.valueFormatter = ValueFormatter(formatX: nil, unitsX: mainUnitY)
        let values: Array<ChartDataEntry> = calculateElevationArray(analysis: analysis,axisType: axisType, divX: divX, convEle: convEle, useGeneralTrackPoints: true)
        let dataSet: OrderedLineDataSet = OrderedLineDataSet(entries: values, label: "", dataSetType: GPXDataSetType.altitude, dataSetAxisType: axisType)
        dataSet.priority = Float((analysis.avgElevation - analysis.minElevation) * convEle)
        dataSet.divX = divX
        dataSet.mulY = convEle
        dataSet.divY = Double.nan
        dataSet.units = mainUnitY

        let color: UIColor = graphType.getFillColor()
        setupDataSet(dataSet: dataSet, color: color, fillColor: color, drawFilled: drawFilled, drawCircles: false, useRightAxis: useRightAxis)
        dataSet.fillFormatter = HeightFormatter()
        return dataSet
    }
    
    private static func createGPXSlopeDataSet(chartView: LineChartView, analysis: OAGPXTrackAnalysis,
                                      graphType: GPXDataSetType,
                                      axisType: GPXDataSetAxisType,
                                      eleValues: Array<ChartDataEntry>,
                                      useRightAxis: Bool,
                                      drawFilled: Bool,
                                      calcWithoutGaps: Bool) -> OrderedLineDataSet? {
        if (axisType == GPXDataSetAxisType.time || axisType == GPXDataSetAxisType.timeOfDay) {
            return nil;
        }
        let mc: EOAMetricsConstant = OAAppSettings.sharedManager().metricSystem.get()
        let useFeet: Bool = (mc == EOAMetricsConstant.MILES_AND_FEET) || (mc == EOAMetricsConstant.MILES_AND_YARDS) || (mc == EOAMetricsConstant.NAUTICAL_MILES_AND_FEET)
        let convEle: Double = useFeet ? 3.28084 : 1.0
        let totalDistance: Double = Double(analysis.totalDistance)
        
        let divX: Double = getDivX(lineChart: chartView, analysis: analysis, axisType: axisType, calcWithoutGaps: calcWithoutGaps)

        let mainUnitY: String = graphType.getMainUnitY()
        
        let yAxis: YAxis = getYAxis(chart: chartView, textColor: UIColor.chartTextColorSlope, useRightAxis: useRightAxis)
        yAxis.granularity = 1.0
        yAxis.resetCustomAxisMin()
        yAxis.valueFormatter = ValueFormatter(formatX: nil, unitsX: mainUnitY)
        
        var values: Array<ChartDataEntry> = Array()
        if (eleValues.count == 0) {
            values = calculateElevationArray(analysis: analysis, axisType: .distance, divX: 1.0, convEle: 1.0, useGeneralTrackPoints: false)
        } else {
            for e in eleValues {
                values.append(ChartDataEntry(x: e.x * divX, y: e.y / convEle))
            }
        }
        
        if (values.count == 0) {
            if (useRightAxis) {
                yAxis.enabled = false
            }
            return nil
        }
        
        var lastIndex = values.count - 1
        
        var step: Double = 5
        var l: Int = 10
        while (l > 0 && totalDistance / step > GpxUIHelper.MAX_CHART_DATA_ITEMS) {
            step = max(step, totalDistance / Double(values.count * l))
            l -= 1
        }
        
        var calculatedDist: Array<Double> = Array(repeating: 0, count: Int(totalDistance / step) + 1)
        var calculatedH: Array<Double> = Array(repeating: 0, count: Int(totalDistance / step) + 1)
        var nextW: Int = 0
        for k in 0..<calculatedDist.count {
            if (k > 0) {
                calculatedDist[k] = calculatedDist[k - 1] + step
            }
            while (nextW < lastIndex && calculatedDist[k] > values[nextW].x) {
                nextW += 1
            }
            let pd: Double = nextW == 0 ? 0 : values[nextW - 1].x
            let ph: Double = nextW == 0 ? values[0].y : values[nextW - 1].y
            calculatedH[k] = ph + (values[nextW].y - ph) / (values[nextW].x - pd) * (calculatedDist[k] - pd)
        }
        
        let slopeProximity: Double = max(100, step * 2)
        
        if (totalDistance - slopeProximity < 0) {
            if (useRightAxis) {
                yAxis.enabled = false
            }
            return nil;
        }
        
        var calculatedSlopeDist: Array<Double> = Array(repeating: 0, count: Int(((totalDistance - slopeProximity) / step)) + 1)
        var calculatedSlope: Array<Double> = Array(repeating: 0, count: Int(((totalDistance - slopeProximity) / step)) + 1)
        let index: Int = Int((slopeProximity / step) / 2.0)
        for k in 0..<calculatedSlopeDist.count {
            calculatedSlopeDist[k] = calculatedDist[index + k]
            // Sometimes calculatedH.count - calculatedSlope.count < 2 which causes a rare crash
            calculatedSlope[k] = (2 * index + k) < calculatedH.count ? (calculatedH[2 * index + k] - calculatedH[k]) * 100 / slopeProximity : 0
            if (calculatedSlope[k].isNaN) {
                calculatedSlope[k] = 0
            }
        }
        
        var slopeValues = [ChartDataEntry]()
        var prevSlope: Double = -80000
        var slope: Double
        var x: Double
        var lastXSameY: Double = 0
        var hasSameY = false
        var lastEntry: ChartDataEntry? = nil
        lastIndex = calculatedSlopeDist.count - 1
        for i in 0..<calculatedSlopeDist.count {
            x = calculatedSlopeDist[i] / divX
            slope = calculatedSlope[i]
            if (prevSlope != -80000) {
                if (prevSlope == slope && i < lastIndex) {
                    hasSameY = true;
                    lastXSameY = x;
                    continue;
                }
                if (hasSameY && lastEntry != nil) {
                    slopeValues.append(ChartDataEntry(x: lastXSameY, y: lastEntry!.y))
                }
                hasSameY = false
            }
            prevSlope = slope;
            lastEntry = ChartDataEntry(x: x, y: slope)
            slopeValues.append(lastEntry!)
        }
        
        let dataSet: OrderedLineDataSet = OrderedLineDataSet(entries: slopeValues, label: "", dataSetType: GPXDataSetType.slope, dataSetAxisType: axisType)
        dataSet.divX = divX
        dataSet.units = mainUnitY

        let color: UIColor = graphType.getFillColor()
        GpxUIHelper.setupDataSet(dataSet: dataSet, color: color, fillColor: color, drawFilled: drawFilled, drawCircles: false, useRightAxis: useRightAxis)
        return dataSet;
    }
    
    private static func setupAxisDistance(axisBase: AxisBase, meters: Double) -> Double {
        let settings: OAAppSettings = OAAppSettings.sharedManager()
        let mc: EOAMetricsConstant = settings.metricSystem.get()
        var divX: Double = 0
        
        let format1 = "%.0f"
        let format2 = "%.1f"
        var fmt: String? = nil
        var granularity: Double = 1
        var mainUnitStr: String
        var mainUnitInMeters: Double
        if mc == EOAMetricsConstant.KILOMETERS_AND_METERS {
            mainUnitStr = OAUtilities.getLocalizedString("km")
            mainUnitInMeters = GpxUIHelper.METERS_IN_KILOMETER
        } else if (mc == EOAMetricsConstant.NAUTICAL_MILES_AND_METERS || mc == EOAMetricsConstant.NAUTICAL_MILES_AND_FEET) {
            mainUnitStr = OAUtilities.getLocalizedString("nm")
            mainUnitInMeters = GpxUIHelper.METERS_IN_ONE_NAUTICALMILE
        } else {
            mainUnitStr = OAUtilities.getLocalizedString("mile")
            mainUnitInMeters = GpxUIHelper.METERS_IN_ONE_MILE
        }
        if (meters > 9.99 * mainUnitInMeters) {
            fmt = format1;
            granularity = 0.1;
        }
        if (meters >= 100 * mainUnitInMeters ||
            meters > 9.99 * mainUnitInMeters ||
                meters > 0.999 * mainUnitInMeters ||
            mc == EOAMetricsConstant.MILES_AND_FEET && meters > 0.249 * mainUnitInMeters ||
            mc == EOAMetricsConstant.MILES_AND_METERS && meters > 0.249 * mainUnitInMeters ||
            mc == EOAMetricsConstant.MILES_AND_YARDS && meters > 0.249 * mainUnitInMeters ||
            mc == EOAMetricsConstant.NAUTICAL_MILES_AND_METERS && meters > 0.99 * mainUnitInMeters ||
            mc == EOAMetricsConstant.NAUTICAL_MILES_AND_FEET && meters > 0.99 * mainUnitInMeters) {
            
            divX = mainUnitInMeters;
            if (fmt == nil) {
                fmt = format2;
                granularity = 0.01;
            }
        } else {
            fmt = nil;
            granularity = 1;
            if (mc == EOAMetricsConstant.KILOMETERS_AND_METERS || mc == EOAMetricsConstant.MILES_AND_METERS) {
                divX = 1;
                mainUnitStr = OAUtilities.getLocalizedString("m")
            } else if (mc == EOAMetricsConstant.MILES_AND_FEET || mc == EOAMetricsConstant.NAUTICAL_MILES_AND_FEET) {
                divX = Double(1.0 / GpxUIHelper.FEET_IN_ONE_METER)
                mainUnitStr = OAUtilities.getLocalizedString("foot")
            } else if (mc == EOAMetricsConstant.MILES_AND_YARDS) {
                divX = Double(1.0 / GpxUIHelper.YARDS_IN_ONE_METER)
                mainUnitStr = OAUtilities.getLocalizedString("yard")
            } else {
                divX = 1.0;
                mainUnitStr = OAUtilities.getLocalizedString("m")
            }
        }
        
        let formatX: String? = fmt
        axisBase.granularity = granularity
        axisBase.valueFormatter = ValueFormatter(formatX: formatX, unitsX: mainUnitStr)
        
        return divX;
    }
    
    private static func calculateElevationArray(analysis: OAGPXTrackAnalysis, axisType: GPXDataSetAxisType, divX: Double, convEle: Double, useGeneralTrackPoints: Bool) -> Array<ChartDataEntry> {
        var values: Array<ChartDataEntry> = []
        if (analysis.elevationData == nil) {
            return values
        }
        let elevationData: Array<OAElevation> = analysis.elevationData
        var nextX: Double = 0
        var nextY: Double
        var elev: Double
        var prevElevOrig: Double = -80000
        var prevElev: Double = 0
        var i: Int = -1
        let lastIndex: Int = elevationData.count - 1
        var lastEntry: ChartDataEntry? = nil
        var lastXSameY: Double = -1
        var hasSameY: Bool = false
        var x: Double
        for e in elevationData {
            i += 1;
            if (axisType == .time || axisType == .timeOfDay) {
                x = Double(e.time);
            } else {
                x = e.distance;
            }
            if (x >= 0)
            {
                nextX += x / divX
                if (!e.elevation.isNaN) {
                    elev = e.elevation;
                    if (prevElevOrig != -80000) {
                        if (elev > prevElevOrig) {
                            elev -= 1;
                        } else if (prevElevOrig == elev && i < lastIndex) {
                            hasSameY = true;
                            lastXSameY = nextX;
                            continue;
                        }
                        if (prevElev == elev && i < lastIndex) {
                            hasSameY = true;
                            lastXSameY = nextX;
                            continue;
                        }
                        if (hasSameY && lastEntry != nil) {
                            values.append(ChartDataEntry(x: lastXSameY, y: lastEntry!.y))
                        }
                        hasSameY = false;
                    }
                    if (useGeneralTrackPoints && e.firstPoint && lastEntry != nil) {
                        values.append(ChartDataEntry(x: nextX, y:lastEntry!.y));
                    }
                    prevElevOrig = e.elevation;
                    prevElev = elev;
                    nextY = elev * convEle;
                    lastEntry = ChartDataEntry(x: nextX, y: nextY);
                    values.append(lastEntry!);
                }
            }
        }
        return values;
    }

    private static func createGPXSpeedDataSet(chartView: LineChartView,
                                              analysis: OAGPXTrackAnalysis,
                                              graphType: GPXDataSetType,
                                              axisType: GPXDataSetAxisType,
                                              useRightAxis: Bool,
                                              drawFilled: Bool,
                                              calcWithoutGaps: Bool) -> OrderedLineDataSet {
        let divX: Double = getDivX(lineChart: chartView, analysis: analysis, axisType: axisType, calcWithoutGaps: calcWithoutGaps)

        let pair: Pair<Double, Double>? = Self.getScalingY(graphType)
        let mulSpeed: Double = pair?.first ?? Double.nan
        let divSpeed: Double = pair?.second ?? Double.nan
        let mainUnitY: String = graphType.getMainUnitY()

        let yAxis: YAxis = getYAxis(chart: chartView, textColor: UIColor.chartTextColorSpeed, useRightAxis: useRightAxis)
        yAxis.axisMinimum = 0.0
        
        let values: Array<ChartDataEntry> = getPointAttributeValues(key: graphType.getDatakey(),
                                                                    pointAttributes: analysis.pointAttributes as! [PointAttributes],
                                                                    axisType: axisType,
                                                                    divX: divX,
                                                                    mulY: mulSpeed,
                                                                    divY: divSpeed,
                                                                    calcWithoutGaps: calcWithoutGaps)
        
        let dataSet: OrderedLineDataSet = OrderedLineDataSet(entries: values, label: "", dataSetType: GPXDataSetType.speed, dataSetAxisType: axisType)
        yAxis.valueFormatter = ValueFormatter(formatX: dataSet.yMax < 3 ? "%.0f" : nil, unitsX: mainUnitY)
        
        if (divSpeed.isNaN) {
            dataSet.priority = analysis.avgSpeed * Float(mulSpeed)
        } else {
            dataSet.priority = Float(divSpeed) / analysis.avgSpeed
        }
        dataSet.divX = divX
        if (divSpeed.isNaN) {
            dataSet.mulY = mulSpeed
            dataSet.divY = Double.nan
        } else {
            dataSet.divY = divSpeed
            dataSet.mulY = Double.nan
        }
        dataSet.units = mainUnitY

        let color: UIColor = graphType.getFillColor()
        GpxUIHelper.setupDataSet(dataSet: dataSet, color: color, fillColor: color, drawFilled: drawFilled, drawCircles: false, useRightAxis: useRightAxis)
        return dataSet;
    }
    
    private static func setupXAxisTime(xAxis: XAxis, timeSpan: Int64) -> Double {
        let useHours: Bool = timeSpan / 3600000 > 0
        xAxis.granularity = 1
        xAxis.valueFormatter = TimeFormatter(useHours: useHours)
        
        return 1
    }
    
    private static func setupXAxisTimeOfDay(xAxis: XAxis, startTime: Int64) -> Double {
        xAxis.granularity = 1
        xAxis.valueFormatter = TimeSpanFormatter(startTime: startTime)
        
        return 1
    }

    static func getScalingY(_ graphType: GPXDataSetType) -> Pair<Double, Double>? {
        if graphType == GPXDataSetType.speed || graphType == GPXDataSetType.sensorSpeed {
            var mulSpeed: Double = Double.nan
            var divSpeed: Double = Double.nan
            let speedConstants: EOASpeedConstant = OAAppSettings.sharedManager().speedSystem.get()
            if speedConstants == EOASpeedConstant.KILOMETERS_PER_HOUR {
                mulSpeed = 3.6
            } else if speedConstants == EOASpeedConstant.MILES_PER_HOUR {
                mulSpeed = 3.6 * GpxUIHelper.METERS_IN_KILOMETER / GpxUIHelper.METERS_IN_ONE_MILE
            } else if speedConstants == EOASpeedConstant.NAUTICALMILES_PER_HOUR {
                mulSpeed = 3.6 * GpxUIHelper.METERS_IN_KILOMETER / GpxUIHelper.METERS_IN_ONE_NAUTICALMILE
            } else if speedConstants == EOASpeedConstant.MINUTES_PER_KILOMETER {
                divSpeed = GpxUIHelper.METERS_IN_KILOMETER / 60.0
            } else if speedConstants == EOASpeedConstant.MINUTES_PER_MILE {
                divSpeed = GpxUIHelper.METERS_IN_ONE_MILE / 60.0
            } else {
                mulSpeed = 1
            }
            return Pair(mulSpeed, divSpeed)
        }
        return nil
    }

    static func getDivX(lineChart: LineChartView,
                        analysis: OAGPXTrackAnalysis,
                        axisType: GPXDataSetAxisType,
                        calcWithoutGaps: Bool) -> Double {
        let xAxis: XAxis = lineChart.xAxis
        if axisType == .time && analysis.isTimeSpecified() {
            return setupXAxisTime(xAxis: xAxis, timeSpan: Int64(calcWithoutGaps ? analysis.timeSpanWithoutGaps : analysis.timeSpan))
        } else if axisType == .timeOfDay && analysis.isTimeSpecified() {
            return setupXAxisTimeOfDay(xAxis: xAxis, startTime: Int64(analysis.startTime))
        } else {
            return setupAxisDistance(axisBase: xAxis, meters: Double(calcWithoutGaps ? analysis.totalDistanceWithoutGaps : analysis.totalDistance))
        }
    }

    static func getYAxis(chart: LineChartView, textColor: UIColor, useRightAxis: Bool) -> YAxis {
        let yAxis: YAxis = useRightAxis ? chart.rightAxis : chart.leftAxis
        yAxis.enabled = true
        yAxis.labelTextColor = textColor
        yAxis.labelBackgroundColor = UIColor.chartAxisValueBg
        return yAxis
    }

    static func getPointAttributeValues(key: String,
                                        pointAttributes: [PointAttributes],
                                        axisType: GPXDataSetAxisType,
                                        divX: Double,
                                        mulY: Double,
                                        divY: Double,
                                        calcWithoutGaps: Bool) -> [ChartDataEntry] {
        var values: [ChartDataEntry] = []
        var currentX: Double = 0

        for i in 0..<pointAttributes.count {
            let attribute: PointAttributes = pointAttributes[i]
            let stepX: Double = Double(axisType == .time || axisType == .timeOfDay ? attribute.timeDiff : attribute.distance)
            if i == 0 || stepX > 0 {
                if !(calcWithoutGaps && attribute.firstPoint) {
                    currentX += stepX / divX
                }
                if attribute.hasValidValue(for: key) {
                    let value: Float = attribute.getAttributeValue(for: key) ?? 1
                    var currentY: Float = divY.isNaN ? value * Float(mulY) : Float(divY) / value
                    if currentY < 0 || currentY.isInfinite {
                        currentY = 0
                    }
                    if attribute.firstPoint && currentY != 0 {
                        values.append(ChartDataEntry(x: currentX, y:0))
                    }
                    values.append(ChartDataEntry(x: currentX, y: Double(currentY)))
                    if attribute.lastPoint && currentY != 0 {
                        values.append(ChartDataEntry(x: currentX, y: 0))
                    }
                }
            }
        }
        return values
    }

    static func setupDataSet(dataSet: OrderedLineDataSet,
                                    color: UIColor,
                                    fillColor: UIColor,
                                    drawFilled: Bool,
                                    drawCircles: Bool,
                                    useRightAxis: Bool) {
            if drawCircles {
                dataSet.setCircleColor(color)
                dataSet.circleRadius = 3
                dataSet.circleHoleColor = UIColor.black
                dataSet.circleHoleRadius = 2
                dataSet.drawCircleHoleEnabled = false
                dataSet.drawCirclesEnabled = true
                dataSet.color = UIColor.black
            } else {
                dataSet.drawCirclesEnabled = false
                dataSet.drawCircleHoleEnabled = false
                dataSet.color = color
            }
            dataSet.lineWidth = 1
            if drawFilled && !drawCircles {
                dataSet.fillAlpha = 0.1
                dataSet.fillColor = fillColor
            }
            dataSet.drawFilledEnabled = drawFilled && !drawCircles
            dataSet.drawValuesEnabled = false
            if drawCircles {
                dataSet.highlightEnabled = false
                dataSet.drawVerticalHighlightIndicatorEnabled = false
                dataSet.drawHorizontalHighlightIndicatorEnabled = false
            } else {
                dataSet.valueFont = UIFont.systemFont(ofSize: 9)
                dataSet.formLineWidth = 1
                dataSet.formSize = 15

                dataSet.highlightEnabled = true
                dataSet.drawVerticalHighlightIndicatorEnabled = true
                dataSet.drawHorizontalHighlightIndicatorEnabled = false
                dataSet.highlightColor = UIColor.chartSliderLine
            }
            if useRightAxis {
                dataSet.axisDependency = YAxis.AxisDependency.right
            }
        }
}

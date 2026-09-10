import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;
using Toybox.Weather;
using Toybox.SensorHistory;

class TypeFaceView extends WatchUi.WatchFace {

    // ---- layout constants (280x280) ----
    const LABEL   = "SATISFY";   // right-column label
    const CX      = 140;
    const CY      = 140;
    const LABEL_X = 40;          // left column (labels / date / time)
    const COL2_X  = 176;         // right value column
    const BATT_Y  = 18;
    const DATE_Y  = 42;
    const TIME_Y  = 62;
    const SAT_Y   = 86;
    const BAND_Y  = 208;         // dotted band top
    const SHOW_RED_TICKS = true; // three red ticks at the right end of the scale

    // top scale: a row of hollow segments along the arc, filled from the left
    // by battery level (each segment = 20%)
    const SEG_COUNT = 5;
    const SEG_LEN   = 14.0;      // degrees per segment
    const SEG_GAP   = 4.0;       // degrees between segments
    const SEG_R_OUT = 132;
    const SEG_R_IN  = 125;

    var ROW_Y as Array<Number> = [124, 145, 166, 187];
    var RED_TICKS as Array<Float> = [42.0, 39.0, 36.0];
    var WEEK_CN as Array<String> = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    var LABELS as Array<String> = ["RUN", "HEART RATE", "RECOVERY", "KCAL"];

    var fTime as WatchUi.FontResource;
    var fText as WatchUi.FontResource;
    var bandBmp as WatchUi.BitmapResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as WatchUi.FontResource;
        fText = WatchUi.loadResource(Rez.Fonts.Text) as WatchUi.FontResource;
        bandBmp = WatchUi.loadResource(Rez.Drawables.Halftone) as WatchUi.BitmapResource;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        // ---- weather (for sun times) ----
        var cc = (Toybox has :Weather) ? Weather.getCurrentConditions() : null;

        // ---- bottom: dotted band, hill silhouette, sun time ----
        dc.drawBitmap(0, BAND_Y, bandBmp);
        drawHill(dc);
        drawSun(dc, cc);

        // ---- battery + top scale ----
        var batt = System.getSystemStats().battery;
        drawScale(dc, batt);
        dc.drawText(CX + 8, BATT_Y, fText, batt.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        drawBolt(dc, CX - 4, BATT_Y + 15);

        // ---- date ----
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = WEEK_CN[(g.day_of_week as Number) - 1] + "." +
            (g.month as Number).format("%02d") + "." + (g.day as Number).format("%02d");
        dc.drawText(LABEL_X, DATE_Y, fText, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ---- time ----
        var hh = g.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hh = hh % 12;
            if (hh == 0) { hh = 12; }
        }
        var timeStr = hh.format("%02d") + ":" + g.min.format("%02d");
        dc.drawText(LABEL_X - 4, TIME_Y, fTime, timeStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ---- right label ----
        dc.drawText(COL2_X, SAT_Y, fText, LABEL, Graphics.TEXT_JUSTIFY_LEFT);

        // ---- data rows ----
        var info = ActivityMonitor.getInfo();

        var runStr = "--";
        var dist = info.distance;
        if (dist != null) {
            runStr = (dist / 100000.0).format("%.1f") + "KM";
        }

        var hrStr = "--";
        var hr = currentHeartRate();
        if (hr != null) {
            hrStr = hr.format("%d") + "BPM";
        }

        var recStr = "--";
        var bb = bodyBattery();
        if (bb != null) {
            recStr = bb.format("%d") + "%";
        }

        var kcalStr = "--";
        var cal = info.calories;
        if (cal != null) {
            kcalStr = cal.format("%d");
        }

        var values = [runStr, hrStr, recStr, kcalStr];
        for (var i = 0; i < 4; i++) {
            dc.drawText(LABEL_X, ROW_Y[i], fText, LABELS[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(COL2_X, ROW_Y[i], fText, values[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ---- data helpers ----

    // live HR if a sensor is running, otherwise the newest history sample
    function currentHeartRate() as Number? {
        var ai = Activity.getActivityInfo();
        if (ai != null) {
            var live = ai.currentHeartRate;
            if (live != null) {
                return live;
            }
        }
        var it = ActivityMonitor.getHeartRateHistory(1, true);
        var s = it.next();
        if (s != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            return s.heartRate;
        }
        return null;
    }

    // Garmin's closest thing to COROS "recovery": Body Battery (0-100)
    function bodyBattery() as Number? {
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory)) {
            var it = Toybox.SensorHistory.getBodyBatteryHistory(
                {:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            var s = it.next();
            if (s != null) {
                var v = s.data;
                if (v != null) {
                    return v.toNumber();
                }
            }
        }
        return null;
    }

    // ---- drawing helpers ----

    function drawScale(dc as Dc, batt as Float) as Void {
        var filled = (batt / 20).toNumber();
        if (filled > SEG_COUNT) { filled = SEG_COUNT; }
        var total = SEG_COUNT * SEG_LEN + (SEG_COUNT - 1) * SEG_GAP;
        var left = 90.0 + total / 2;          // angle of the left end
        var rMid = (SEG_R_OUT + SEG_R_IN) / 2;
        for (var i = 0; i < SEG_COUNT; i++) {
            var a1 = left - i * (SEG_LEN + SEG_GAP);
            var a0 = a1 - SEG_LEN;
            if (i < filled) {
                dc.setPenWidth(SEG_R_OUT - SEG_R_IN + 1);
                dc.drawArc(CX, CY, rMid, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
            } else {
                dc.setPenWidth(1);
                dc.drawArc(CX, CY, SEG_R_OUT, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
                dc.drawArc(CX, CY, SEG_R_IN, Graphics.ARC_COUNTER_CLOCKWISE, a0, a1);
                drawRadial(dc, a0, SEG_R_IN, SEG_R_OUT);
                drawRadial(dc, a1, SEG_R_IN, SEG_R_OUT);
            }
        }
        if (SHOW_RED_TICKS) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var i = 0; i < RED_TICKS.size(); i++) {
                drawRadial(dc, RED_TICKS[i], SEG_R_IN, SEG_R_OUT);
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        dc.setPenWidth(1);
    }

    // short line from radius r0 to r1 at angle deg (Garmin degrees, 90 = up)
    function drawRadial(dc as Dc, deg as Float, r0 as Number, r1 as Number) as Void {
        var rad = Math.toRadians(deg);
        var c = Math.cos(rad);
        var sn = Math.sin(rad);
        dc.drawLine(CX + r0 * c, CY - r0 * sn, CX + r1 * c, CY - r1 * sn);
    }

    // white hill silhouette knocked out of the dot band
    function drawHill(dc as Dc) as Void {
        var pts = [] as Array<[Numeric, Numeric]>;
        pts.add([0, 281]);
        for (var i = 0; i < 71; i++) {
            var x = i * 4;
            pts.add([x, hillY(x)]);
        }
        pts.add([280, 281]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var x = 0; x < 278; x += 2) {
            dc.drawLine(x, hillY(x), x + 2, hillY(x + 2));
        }
        dc.setPenWidth(1);
    }

    function hillY(x as Number) as Number {
        var a = (x - 112) / 58.0;
        var b = (x - 268) / 46.0;
        var y = 272.0 - 24.0 * Math.pow(2.718281828, -(a * a))
                      - 12.0 * Math.pow(2.718281828, -(b * b));
        return y.toNumber();
    }

    // next sun event: sunrise before dawn, sunset during the day
    function drawSun(dc as Dc, cc as Weather.CurrentConditions?) as Void {
        var sunStr = "--:--";
        var pos = (cc != null) ? cc.observationLocationPosition : null;
        if (pos != null && (Weather has :getSunrise) && (Weather has :getSunset)) {
            var now = Time.now();
            var ev = Weather.getSunrise(pos, now);
            if (ev != null && ev.lessThan(now)) {
                var ss = Weather.getSunset(pos, now);
                if (ss != null) { ev = ss; }
            }
            if (ev != null) {
                var gi = Gregorian.info(ev, Time.FORMAT_SHORT);
                sunStr = gi.hour.format("%02d") + ":" + gi.min.format("%02d");
            }
        }
        var scy = BAND_Y + 12;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(CX - 52, scy - 14, 104, 27);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        // sun icon: half circle + horizon line
        dc.drawArc(CX - 38, scy + 6, 8, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(CX - 48, scy + 7, CX - 28, scy + 7);
        dc.setPenWidth(1);
        dc.drawText(CX - 24, scy - 15, fText, sunStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawBolt(dc as Dc, x as Number, y as Number) as Void {
        dc.fillPolygon([
            [x, y - 10], [x - 7, y + 2], [x - 2, y + 2],
            [x - 4, y + 10], [x + 4, y - 2], [x - 1, y - 2]
        ]);
    }
}

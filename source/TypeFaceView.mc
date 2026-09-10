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
    const DASH_R  = 128;         // radius of the top scale
    const SHOW_RED_TICKS = true; // three red ticks at the right end of the scale

    var ROW_Y = [124, 145, 166, 187];
    var WEEK_CN = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    var LABELS = ["RUN", "HEART RATE", "RECOVERY", "KCAL"];

    // top scale, left to right: [startDeg, lenDeg, penWidth]
    // (Garmin arc degrees: 90 = 12 o'clock, counter-clockwise positive)
    var DASHES = [
        [138.0, 5.0, 4],                                   // short heavy dash, left end
        [129.0, 3.0, 2], [123.5, 3.0, 2], [118.0, 3.0, 2], // three tiny dashes
        [98.0, 15.0, 4],                                   // long dash
        [90.0, 4.0, 3], [83.0, 4.0, 3],                    // two short dashes
        [63.0, 16.0, 4],                                   // long dash
        [55.0, 4.0, 3], [48.0, 4.0, 3],                    // two short dashes
    ];
    var RED_TICKS = [44.0, 41.0, 38.0];

    var fTime;
    var fText;
    var bandBmp;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        fTime = WatchUi.loadResource(Rez.Fonts.Time);
        fText = WatchUi.loadResource(Rez.Fonts.Text);
        bandBmp = WatchUi.loadResource(Rez.Drawables.Halftone);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        // ---- weather (for sun times) ----
        var cc = null;
        if (Toybox has :Weather) {
            cc = Weather.getCurrentConditions();
        }

        // ---- bottom: dotted band, hill silhouette, sun time ----
        dc.drawBitmap(0, BAND_Y, bandBmp);
        drawHill(dc);
        drawSun(dc, cc);

        // ---- top scale ----
        drawScale(dc);

        // ---- battery ----
        var batt = System.getSystemStats().battery;
        dc.drawText(CX + 8, BATT_Y, fText, batt.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        drawBolt(dc, CX - 4, BATT_Y + 15);

        // ---- date ----
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = WEEK_CN[g.day_of_week - 1] + "." +
            g.month.format("%02d") + "." + g.day.format("%02d");
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
        if (info.distance != null) {
            runStr = (info.distance / 100000.0).format("%.1f") + "KM";
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
        if (info.calories != null) {
            kcalStr = info.calories.format("%d");
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
        if (ai != null && ai.currentHeartRate != null) {
            return ai.currentHeartRate;
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
            if (s != null && s.data != null) {
                return s.data.toNumber();
            }
        }
        return null;
    }

    // ---- drawing helpers ----

    function drawScale(dc as Dc) as Void {
        for (var i = 0; i < DASHES.size(); i++) {
            var a0 = DASHES[i][0];
            var ln = DASHES[i][1];
            dc.setPenWidth(DASHES[i][2].toNumber());
            dc.drawArc(CX, CY, DASH_R, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + ln);
        }
        if (SHOW_RED_TICKS) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            for (var i = 0; i < RED_TICKS.size(); i++) {
                var rad = Math.toRadians(RED_TICKS[i]);
                var c = Math.cos(rad);
                var s = Math.sin(rad);
                var r0 = DASH_R - 4;
                var r1 = DASH_R + 4;
                dc.drawLine(CX + r0 * c, CY - r0 * s, CX + r1 * c, CY - r1 * s);
            }
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        }
        dc.setPenWidth(1);
    }

    // white hill silhouette knocked out of the dot band
    function drawHill(dc as Dc) as Void {
        var pts = new [73];
        pts[0] = [0, 281];
        for (var i = 0; i < 71; i++) {
            var x = i * 4;
            pts[i + 1] = [x, hillY(x)];
        }
        pts[72] = [280, 281];
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
    function drawSun(dc as Dc, cc) as Void {
        var sunStr = "--:--";
        if (cc != null && cc.observationLocationPosition != null
            && (Weather has :getSunrise) && (Weather has :getSunset)) {
            var now = Time.now();
            var pos = cc.observationLocationPosition;
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

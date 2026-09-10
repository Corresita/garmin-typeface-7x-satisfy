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
    const SAT_X   = 178;         // right label
    const BATT_Y  = 22;
    const BATT_X  = 133;         // battery digits
    const DATE_X  = 48;
    const DATE_Y  = 56;
    const TIME_Y  = 71;
    const TIME_X  = 34;
    const SAT_Y   = 97;          // bottom-aligned with the time
    const BAND_Y  = 211;         // dotted band top
    // hill line across the band; a marker dot slides along it from sunrise (x = MARK_X0)
    // to sunset (x = MARK_X1)
    const HILL_DX = 18;          // hill shape shifted right, per the mockup
    const MARK_X0 = 60;
    const MARK_X1 = 200;
    const SUN_BOX_X = 91;        // white box behind the sun time
    const SUN_BOX_Y = 222;
    const SUN_BOX_W = 83;
    const SUN_BOX_H = 19;
    const SHOW_RED_TICKS = false; // three red ticks at the right end of the scale

    // top scale: a row of hollow segments along the arc, filled from the left
    // by battery level (each segment = 20%)
    const SEG_COUNT = 5;
    const SEG_LEN   = 12.0;      // degrees per segment
    const SEG_GAP   = 3.5;       // degrees between segments
    const SEG_R_OUT = 131;
    const SEG_R_IN  = 126;

    var ROW_Y as Array<Number> = [122, 143, 164, 185];
    // outlined lightning bolt, absolute coordinates from the mockup
    var BOLT as Array<[Numeric, Numeric]> = [[128, 26], [124, 26], [122, 35], [126, 35], [124, 41], [130, 32], [126, 32]];
    var RED_TICKS as Array<Float> = [42.0, 39.0, 36.0];
    var WEEK as Array<String> = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    var LABELS as Array<String> = ["RUN", "HEART RATE", "RECOVERY", "KCAL"];

    var fTime as WatchUi.FontResource;
    var fLabel as WatchUi.FontResource;
    var fBold as WatchUi.FontResource;   // battery digits + sun time
    var fText as WatchUi.FontResource;
    var fDate as WatchUi.FontResource;
    var bandBmp as WatchUi.BitmapResource;

    function initialize() {
        WatchFace.initialize();
        fTime = WatchUi.loadResource(Rez.Fonts.Time) as WatchUi.FontResource;
        fLabel = WatchUi.loadResource(Rez.Fonts.Label) as WatchUi.FontResource;
        fBold = WatchUi.loadResource(Rez.Fonts.Bold) as WatchUi.FontResource;
        fText = WatchUi.loadResource(Rez.Fonts.Text) as WatchUi.FontResource;
        fDate = WatchUi.loadResource(Rez.Fonts.Date) as WatchUi.FontResource;
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

        // ---- bottom: dotted band, sun path, sun time ----
        dc.drawBitmap(0, BAND_Y, bandBmp);
        drawSun(dc, cc);

        // ---- battery + top scale ----
        var batt = System.getSystemStats().battery;
        drawScale(dc, batt);
        dc.drawText(BATT_X, BATT_Y, fBold, batt.format("%d"), Graphics.TEXT_JUSTIFY_LEFT);
        drawBolt(dc);

        // ---- date ----
        var g = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = WEEK[(g.day_of_week as Number) - 1] + "." +
            (g.month as Number).format("%02d") + "." + (g.day as Number).format("%02d");
        dc.drawText(DATE_X, DATE_Y, fDate, dateStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ---- time ----
        var hh = g.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hh = hh % 12;
            if (hh == 0) { hh = 12; }
        }
        var timeStr = hh.format("%02d") + ":" + g.min.format("%02d");
        dc.drawText(TIME_X, TIME_Y, fTime, timeStr, Graphics.TEXT_JUSTIFY_LEFT);

        // ---- right label ----
        dc.drawText(SAT_X, SAT_Y, fLabel, LABEL, Graphics.TEXT_JUSTIFY_LEFT);

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

    // hill line with a marker at `frac` (0 = sunrise, 1 = sunset)
    function drawSunPath(dc as Dc, frac as Float) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var x = 0; x < 278; x += 2) {
            dc.drawLine(x, hillY(x), x + 2, hillY(x + 2));
        }
        var mx = (MARK_X0 + frac * (MARK_X1 - MARK_X0)).toNumber();
        var my = hillY(mx);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(mx, my, 3);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(mx, my, 3);
        dc.setPenWidth(1);
    }

    function hillY(x as Number) as Number {
        var a = (x - HILL_DX - 112) / 58.0;
        var b = (x - HILL_DX - 268) / 46.0;
        var y = 273.0 - 24.0 * Math.pow(2.718281828, -(a * a))
                      - 12.0 * Math.pow(2.718281828, -(b * b));
        return y.toNumber();
    }

    // sun row: next sun event (sunrise before dawn, sunset during the day) and the path marker
    function drawSun(dc as Dc, cc as Weather.CurrentConditions?) as Void {
        var sunStr = "--:--";
        var now = Time.now();
        var g = Gregorian.info(now, Time.FORMAT_SHORT);
        // fallback marker position from the clock: 06:00 = left end, 18:00 = right end
        var frac = ((g.hour * 60 + g.min) - 360) / 720.0;
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }

        // position: weather observation point, else the watch's last GPS fix
        var pos = (cc != null) ? cc.observationLocationPosition : null;
        if (pos == null) {
            var ai = Activity.getActivityInfo();
            if (ai != null) {
                pos = ai.currentLocation;
            }
        }
        if (pos != null && (Weather has :getSunrise) && (Weather has :getSunset)) {
            var rise = Weather.getSunrise(pos, now);
            var set = Weather.getSunset(pos, now);
            var ev = rise;
            if (rise != null && set != null) {
                if (now.lessThan(rise)) {
                    frac = 0.0;
                } else if (now.lessThan(set)) {
                    ev = set;
                    var day = set.subtract(rise).value().toFloat();
                    frac = (day > 0) ? now.subtract(rise).value().toFloat() / day : 0.5;
                } else {
                    ev = Weather.getSunrise(pos, now.add(new Time.Duration(Gregorian.SECONDS_PER_DAY)));
                    frac = 1.0;
                }
            }
            if (ev != null) {
                var gi = Gregorian.info(ev, Time.FORMAT_SHORT);
                sunStr = gi.hour.format("%02d") + ":" + gi.min.format("%02d");
            }
        }
        drawSunPath(dc, frac);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(SUN_BOX_X, SUN_BOX_Y, SUN_BOX_W, SUN_BOX_H);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        // sun icon: half dome on a horizon line
        var ix = SUN_BOX_X + 10;
        var iy = SUN_BOX_Y + 12;
        dc.drawArc(ix, iy, 8, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(ix - 10, iy + 1, ix + 10, iy + 1);
        dc.setPenWidth(1);
        dc.drawText(SUN_BOX_X + 24, SUN_BOX_Y - 2, fBold, sunStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawBolt(dc as Dc) as Void {
        dc.setPenWidth(1);
        var n = BOLT.size();
        for (var i = 0; i < n; i++) {
            var a = BOLT[i];
            var b = BOLT[(i + 1) % n];
            dc.drawLine(a[0], a[1], b[0], b[1]);
        }
    }
}

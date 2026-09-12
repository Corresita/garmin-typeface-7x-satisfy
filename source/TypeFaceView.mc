import Toybox.Application;
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
using Toybox.Complications;

class TypeFaceView extends WatchUi.WatchFace {

    // ---- layout constants (280x280) ----
    const LABEL   = "SATISFY";   // right-column label
    const CX      = 140;
    const CY      = 140;
    const LABEL_X = 23;          // left column (data rows)
    const COL2_X  = 191;         // right value column
    const SAT_X   = 191;         // right label
    const BATT_Y  = 21;
    const BATT_X  = 130;         // battery digits
    const DATE_X  = 35;
    const DATE_Y  = 51;
    const TIME_Y  = 61;
    const TIME_X  = 20;
    const SAT_Y   = 98;
    const BAND_Y  = 201;         // dotted band top
    // hill line across the band; a marker dot slides along it from sunrise (x = MARK_X0)
    // to sunset (x = MARK_X1)
    const MARK_X0 = 70;
    const MARK_X1 = 210;
    const SUN_BOX_X = 97;        // white box behind the sun time
    const SUN_BOX_Y = 205;
    const SUN_BOX_W = 85;
    const SUN_BOX_H = 22;
    const SHOW_RED_TICKS = false; // three red ticks at the right end of the scale

    // top scale: a row of hollow segments along the arc, filled from the left
    // by battery level (each segment = 20%)
    const SEG_COUNT = 5;
    const SEG_LEN   = 13.7;      // degrees per segment
    const SEG_END   = 13.7;
    const SEG_GAP   = 2.0;       // degrees between segments
    const SEG_R_OUT = 133;
    const SEG_R_IN  = 130;

    var ROW_Y as Array<Number> = [121, 140, 159, 178];
    // outlined lightning bolt, absolute coordinates from the mockup
    var BOLT as Array<[Numeric, Numeric]> = [[128, 26], [120, 26], [120, 32], [122, 32], [121, 39], [128, 31], [125, 31]];
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

        // RUN: today's running distance, see todayRunMeters()
        var runStr = "--";
        var runM = todayRunMeters();
        if (runM != null) {
            runStr = (runM / 1000.0).format("%.1f") + "KM";
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

    // value of a native complication, or null if unsupported / not available
    function complication(type as Complications.Type) as Complications.Value? {
        if (!(Toybox has :Complications)) {
            return null;
        }
        try {
            return Complications.getComplication(new Complications.Id(type)).value;
        } catch (e) {
            return null;
        }
    }

    // live HR if a sensor is running, otherwise the newest history sample,
    // but only if that sample is recent (the watch may be off the wrist)
    const HR_MAX_AGE = 300;   // seconds

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
            var when = s.when;
            if (when != null && Time.now().subtract(when).value() <= HR_MAX_AGE) {
                return s.heartRate;
            }
        }
        return null;
    }

    // Garmin only exposes this week's running distance to watch faces, not today's.
    // Today's = weekly now - weekly at the start of today; the baseline is stored
    // when the day changes (or when the weekly total resets on Monday).
    function todayRunMeters() as Float? {
        var wr = complication(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE);
        if (!(wr instanceof Lang.Number || wr instanceof Lang.Float)) {
            return null;
        }
        var weekly = (wr as Numeric).toFloat();
        var today = Time.today().value();          // local midnight, epoch seconds
        var day = Application.Storage.getValue("runBaseDay");
        var base = Application.Storage.getValue("runBaseMeters");
        var baseM = (base instanceof Lang.Float) ? base : ((base instanceof Lang.Number) ? base.toFloat() : null);
        if (!(day instanceof Lang.Number) || day != today || baseM == null || baseM > weekly) {
            baseM = weekly;
            Application.Storage.setValue("runBaseDay", today);
            Application.Storage.setValue("runBaseMeters", weekly);
        }
        return weekly - baseM;
    }

    // Garmin's closest thing to COROS "recovery": Body Battery (0-100).
    // The complication holds the watch's current value; sensor history is the fallback.
    function bodyBattery() as Number? {
        var bb = complication(Complications.COMPLICATION_TYPE_BODY_BATTERY);
        if (bb instanceof Lang.Number) {
            return bb;
        }
        if (bb instanceof Lang.Float) {
            return bb.toNumber();
        }
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
        var total = (SEG_COUNT - 2) * SEG_LEN + 2 * SEG_END + (SEG_COUNT - 1) * SEG_GAP;
        var a1 = 90.0 + total / 2;            // angle of the left end
        var rMid = (SEG_R_OUT + SEG_R_IN) / 2;
        for (var i = 0; i < SEG_COUNT; i++) {
            var len = (i == 0 || i == SEG_COUNT - 1) ? SEG_END : SEG_LEN;
            if (i > 0) { a1 -= SEG_GAP; }
            var a0 = a1 - len;
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
            a1 = a0;
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
        var a = (x - 142) / 53.0;
        var b = (x - 298) / 43.0;
        var y = 268.5 - 34.0 * Math.pow(2.718281828, -(a * a))
                      - 17.5 * Math.pow(2.718281828, -(b * b));
        return y.toNumber();
    }

    // sun row: next sun event (sunrise before dawn, sunset during the day) and the path marker
    function drawSun(dc as Dc, cc as Weather.CurrentConditions?) as Void {
        var sunStr = "--:--";
        var isRise = true;   // rays are drawn for a sunrise, not for a sunset
        var now = Time.now();
        var g = Gregorian.info(now, Time.FORMAT_SHORT);
        // fallback marker position from the clock: 06:00 = left end, 18:00 = right end
        var frac = ((g.hour * 60 + g.min) - 360) / 720.0;
        if (frac < 0.0) { frac = 0.0; }
        if (frac > 1.0) { frac = 1.0; }

        // 1) sunrise / sunset computed by the watch itself (seconds since local midnight)
        var riseS = complication(Complications.COMPLICATION_TYPE_SUNRISE);
        var setS = complication(Complications.COMPLICATION_TYPE_SUNSET);
        // 2) otherwise from the weather observation point or the watch's last GPS fix
        var pos = (cc != null) ? cc.observationLocationPosition : null;
        if (pos == null) {
            var ai = Activity.getActivityInfo();
            if (ai != null) {
                pos = ai.currentLocation;
            }
        }
        if (riseS instanceof Lang.Number && setS instanceof Lang.Number) {
            var nowS = g.hour * 3600 + g.min * 60 + g.sec;
            var evS = riseS;
            if (nowS < riseS) {
                frac = 0.0;
            } else if (nowS < setS) {
                evS = setS;
                isRise = false;
                frac = (setS > riseS) ? (nowS - riseS).toFloat() / (setS - riseS) : 0.5;
            } else {
                frac = 1.0;
            }
            sunStr = (evS / 3600).format("%02d") + ":" + ((evS % 3600) / 60).format("%02d");
        } else if (pos != null && (Weather has :getSunrise) && (Weather has :getSunset)) {
            var rise = Weather.getSunrise(pos, now);
            var set = Weather.getSunset(pos, now);
            var ev = rise;
            if (rise != null && set != null) {
                if (now.lessThan(rise)) {
                    frac = 0.0;
                } else if (now.lessThan(set)) {
                    ev = set;
                    isRise = false;
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
        // sun icon: dome on the horizon, short ticks at its equator, a gapped horizon line
        // below with the sun's underside showing through the gap; rays only for a sunrise
        var ix = SUN_BOX_X + 13;
        var iy = SUN_BOX_Y + 12;
        dc.drawArc(ix, iy, 6, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(ix - 9, iy, ix - 6, iy);
        dc.drawLine(ix + 6, iy, ix + 9, iy);
        dc.drawLine(ix - 8, iy + 3, ix - 3, iy + 3);
        dc.drawLine(ix + 3, iy + 3, ix + 8, iy + 3);
        dc.drawArc(ix, iy + 3, 3, Graphics.ARC_COUNTER_CLOCKWISE, 180, 360);
        if (isRise) {
            dc.drawLine(ix - 6, iy - 7, ix - 4, iy - 5);
            dc.drawLine(ix, iy - 10, ix, iy - 7);
            dc.drawLine(ix + 6, iy - 8, ix + 5, iy - 5);
        }
        dc.setPenWidth(1);
        dc.drawText(SUN_BOX_X + 25, SUN_BOX_Y + 1, fBold, sunStr, Graphics.TEXT_JUSTIFY_LEFT);
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

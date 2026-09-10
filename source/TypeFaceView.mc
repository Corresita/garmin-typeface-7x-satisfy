import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.ActivityMonitor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;
using Toybox.Weather;

class TypeFaceView extends WatchUi.WatchFace {

    // ---- layout constants (280x280) ----
    const LABEL   = "TYPEFACE";  // change to whatever you like
    const CX      = 140;
    const CY      = 140;
    const LABEL_X = 40;          // left column (labels / date / time)
    const COL2_X  = 176;         // right value column
    const BATT_Y  = 22;
    const DATE_Y  = 42;
    const TIME_Y  = 62;
    const SAT_Y   = 86;
    const BAND_Y  = 208;         // dotted band top

    var ROW_Y = [124, 145, 166, 187];
    var WEEK_CN = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
    // irregular top dashes: [startDeg, lenDeg], a couple doubled
    var DASHES = [[48, 5], [60, 14], [80, 9], [95, 16], [117, 11], [132, 6]];

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

        // ---- weather ----
        var cc = null;
        if (Toybox has :Weather) {
            cc = Weather.getCurrentConditions();
        }

        // ---- bottom: dotted band, hill silhouette, sunrise ----
        dc.drawBitmap(0, BAND_Y, bandBmp);
        drawHill(dc);
        drawSunrise(dc, cc);

        // ---- top irregular dashes ----
        dc.setPenWidth(3);
        for (var i = 0; i < DASHES.size(); i++) {
            var a0 = DASHES[i][0];
            var ln = DASHES[i][1];
            dc.drawArc(CX, CY, 132, Graphics.ARC_COUNTER_CLOCKWISE, a0, a0 + ln);
            if (i == 1 || i == 3) {
                dc.drawArc(CX, CY, 126, Graphics.ARC_COUNTER_CLOCKWISE, a0 + 2, a0 + ln - 2);
            }
        }
        dc.setPenWidth(1);

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
        var tempStr = "--";
        var rainStr = "--";
        var humStr = "--";
        if (cc != null) {
            if (cc.temperature != null) {
                var t = cc.temperature;
                var unit = "°C";
                if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
                    t = t * 9.0 / 5.0 + 32;
                    unit = "°F";
                }
                tempStr = t.format("%d") + unit;
            }
            if (cc.precipitationChance != null) {
                rainStr = cc.precipitationChance.format("%d") + "%";
            }
            if (cc.relativeHumidity != null) {
                humStr = cc.relativeHumidity.format("%d") + "%";
            }
        }

        var actStr = "--";
        var info = ActivityMonitor.getInfo();
        if (info.activeMinutesDay != null) {
            actStr = info.activeMinutesDay.total.format("%d") + "MIN";
        }

        var labels = ["TEMPERATURE", "RAIN CHANCE", "HUMIDITY", "ACTIVE"];
        var values = [tempStr, rainStr, humStr, actStr];
        for (var i = 0; i < 4; i++) {
            dc.drawText(LABEL_X, ROW_Y[i], fText, labels[i], Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(COL2_X, ROW_Y[i], fText, values[i], Graphics.TEXT_JUSTIFY_LEFT);
        }
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

    function drawSunrise(dc as Dc, cc) as Void {
        var srStr = "--:--";
        if (cc != null && cc.observationLocationPosition != null
            && (Weather has :getSunrise)) {
            var sr = Weather.getSunrise(cc.observationLocationPosition, Time.now());
            if (sr != null) {
                var gi = Gregorian.info(sr, Time.FORMAT_SHORT);
                srStr = gi.hour.format("%02d") + ":" + gi.min.format("%02d");
            }
        }
        var scy = BAND_Y + 12;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(CX - 52, scy - 14, 104, 27);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        // rising-sun icon: half circle + horizon line
        dc.drawArc(CX - 38, scy + 6, 8, Graphics.ARC_COUNTER_CLOCKWISE, 0, 180);
        dc.drawLine(CX - 48, scy + 7, CX - 28, scy + 7);
        dc.setPenWidth(1);
        dc.drawText(CX - 24, scy - 15, fText, srStr, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function drawBolt(dc as Dc, x as Number, y as Number) as Void {
        dc.fillPolygon([
            [x, y - 12], [x - 7, y + 2], [x - 2, y + 2],
            [x - 4, y + 12], [x + 4, y - 2], [x - 1, y - 2]
        ]);
    }
}

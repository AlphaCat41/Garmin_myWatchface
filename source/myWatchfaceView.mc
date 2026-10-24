import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Math;
import Toybox.Time;
import Toybox.Timer;
import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;

class myWatchfaceView extends WatchUi.WatchFace {
    private var _progress as Float = 1.0;
    private var _timer as Timer.Timer or Null = null;
    private var _startMs as Number = 0;
    private var _animMs as Number = 800;
    private var _hrHistory as Array<Number> = [];
    private var _maxHistorySize as Number = 25;
    private var _lastHrCheck as Number = 0;

    private var _iconStress as BitmapResource or Null = null;
    private var _iconBody as BitmapResource or Null = null;
    private var _iconHeart as BitmapResource or Null = null;

    private const ARC_GAP = 4;   // ช่องว่างปลายครึ่งวงกลมด้านบน/ล่าง (องศา)

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
        _iconStress = WatchUi.loadResource(Rez.Drawables.IconStress) as BitmapResource;
        _iconBody   = WatchUi.loadResource(Rez.Drawables.IconBodyBattery) as BitmapResource;
        _iconHeart  = WatchUi.loadResource(Rez.Drawables.IconHeart) as BitmapResource;
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);

        var r = (w / 2) - 8;

        var stress = getStress();
        var bodyBatt = getBodyBattery();

        // Arc: Stress (ซ้าย) / Body Battery (ขวา)
        drawSideArc(dc, cx, cy, r, stress, true, 0xFF9900);
        drawSideArc(dc, cx, cy, r, bodyBatt, false, 0x00AAFF);

        // ตัวเลข + ไอคอน อยู่ข้างๆ arc (ตำแหน่งคงที่)
        var infoOffset = 32;
        drawSideInfo(dc, cx - r + infoOffset, cy, stress, 0xFF9900, _iconStress);
        drawSideInfo(dc, cx + r - infoOffset, cy, bodyBatt, 0x00AAFF, _iconBody);

        drawBatteryTop(dc, cx, h);
        drawTime(dc, cx, cy);
        drawNotification(dc, cx, cy, h);
        drawDate(dc, cx, cy, h);
        drawStats(dc, cx, cy, w, h);
        drawHeartRateGraph(dc, cx, cy, w, h);
    }

    function onHide() as Void {
        stopAnim();
    }

    function onExitSleep() as Void {
        startAnim();
    }

    function onEnterSleep() as Void {
        stopAnim();
        _progress = 1.0;
        WatchUi.requestUpdate();
    }

    function startAnim() as Void {
        stopAnim();
        _progress = 0.0;
        _startMs = System.getTimer();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 40, true);
    }

    function stopAnim() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        var t = (System.getTimer() - _startMs).toFloat() / _animMs;
        if (t >= 1.0) {
            t = 1.0;
            stopAnim();
        }
        _progress = 1.0 - Math.pow(1.0 - t, 3);
        WatchUi.requestUpdate();
    }

    // ---------------- helper วาด bitmap ตรงกึ่งกลาง ----------------
    function drawIcon(dc as Dc, bmp as BitmapResource or Null, x as Number, y as Number) as Void {
        if (bmp == null) { return; }
        dc.drawBitmap(x - bmp.getWidth() / 2, y - bmp.getHeight() / 2, bmp);
    }

    // ---------------- เวลา ----------------
    function drawTime(dc as Dc, cx as Number, cy as Number) as Void {
        var clock = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [
            clock.hour.format("%02d"),
            clock.min.format("%02d")
        ]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------------- แจ้งเตือน (เหนือเวลา ใต้กราฟ HR) ----------------
    function drawNotification(dc as Dc, cx as Number, cy as Number, h as Number) as Void {
        var count = System.getDeviceSettings().notificationCount;
        if (count == null || count <= 0) {
            return;
        }

        // ตำแหน่งแนวตั้ง = กึ่งกลางระหว่างขอบล่างกราฟ HR กับขอบบนตัวเลขเวลา
        var graphBottom = cy - (h * 0.13);
        var timeTop = cy - dc.getFontHeight(Graphics.FONT_NUMBER_MEDIUM) / 2;
        var ny = ((graphBottom + timeTop) / 2).toNumber();

        var txt = count.toString();
        var tw = dc.getTextWidthInPixels(txt, Graphics.FONT_XTINY);

        var ew = 18;
        var eh = 12;
        var gap = 5;
        var total = ew + gap + tw;
        var ex = (cx - total / 2).toNumber();
        var ey = ny - eh / 2;

        // ซองจดหมาย
        dc.setPenWidth(2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(ex, ey, ew, eh);
        dc.drawLine(ex, ey, ex + ew / 2, ey + eh / 2 + 1);
        dc.drawLine(ex + ew, ey, ex + ew / 2, ey + eh / 2 + 1);

        // จำนวนข้อความ
        dc.drawText(ex + ew + gap, ny, Graphics.FONT_XTINY, txt,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------------- วันที่ ----------------
    function drawDate(dc as Dc, cx as Number, cy as Number, h as Number) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var days = ["Sunday", "Monday", "Tuesday", "Wednesday",
                    "Thursday", "Friday", "Saturday"];
        var months = ["January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"];

        var dateStr = Lang.format("$1$, $2$ $3$", [
            days[now.day_of_week - 1],
            now.day,
            months[now.month - 1]
        ]);

        dc.setColor(0x898989, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (h * 0.15), Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------------- Steps / Cal / Distance ----------------
    function drawStats(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        var info = ActivityMonitor.getInfo();

        var stepsTxt = "--";
        var calTxt = "--";
        var distTxt = "--";

        if (info != null) {
            if (info.steps != null) {
                stepsTxt = info.steps.toString();
            }
            if (info.calories != null) {
                calTxt = info.calories.toString();
            }
            if (info.distance != null) {
                distTxt = (info.distance / 100000.0).format("%.1f");
            }
        }

        var valY = (cy + h * 0.255).toNumber();
        var lblY = valY + dc.getFontHeight(Graphics.FONT_XTINY) - 4;
        var dx = (w * 0.25).toNumber();

        drawStatItem(dc, cx - dx, valY, lblY, stepsTxt, "steps");
        drawStatItem(dc, cx,      valY, lblY, calTxt,   "kcal");
        drawStatItem(dc, cx + dx, valY, lblY, distTxt,  "km");
    }

    function drawStatItem(dc as Dc, x as Number, valY as Number, lblY as Number,
                          value as String, label as String) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valY, Graphics.FONT_XTINY, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(0x898989, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, lblY, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------------- แบตเตอรี่ (บนสุด) ----------------
    function drawBatteryTop(dc as Dc, cx as Number, h as Number) as Void {
        var batt = System.getSystemStats().battery;
        var color = batt > 20 ? 0x00FF88 : Graphics.COLOR_RED;
        var txt = batt.toNumber().toString() + "%";

        var iconW = 22;
        var iconH = 11;
        var nub = 2;
        var gap = 4;
        var tw = dc.getTextWidthInPixels(txt, Graphics.FONT_XTINY);
        var total = iconW + nub + gap + tw;

        var sx = (cx - total / 2).toNumber();
        var yc = (h * 0.09).toNumber();
        var iy = yc - iconH / 2;

        dc.setPenWidth(1);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(sx, iy, iconW, iconH, 2);
        dc.fillRectangle(sx + iconW, iy + iconH / 4, nub, iconH / 2);
        var fillW = ((iconW - 4) * batt / 100.0).toNumber();
        if (fillW > 0) {
            dc.fillRectangle(sx + 2, iy + 2, fillW, iconH - 4);
        }

        dc.drawText(sx + iconW + nub + gap, yc, Graphics.FONT_XTINY, txt,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---------------- Arc ครึ่งวงกลม ซ้าย/ขวา ----------------
    function drawSideArc(dc as Dc, cx as Number, cy as Number, r as Number,
                         value as Number or Null, isLeft as Boolean, color as Number) as Void {
        var pct = (value == null) ? 0.0 : value.toFloat();
        if (pct > 100) { pct = 100.0; }
        if (pct < 0) { pct = 0.0; }
        pct = pct * _progress;

        var sweep = (180 - 2 * ARC_GAP) * pct / 100.0;

        dc.setPenWidth(8);

        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        if (isLeft) {
            dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, 90 + ARC_GAP, 270 - ARC_GAP);
        } else {
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90 - ARC_GAP, -90 + ARC_GAP);
        }

        var tipDeg;
        if (isLeft) {
            tipDeg = 270 - ARC_GAP - sweep;
        } else {
            tipDeg = -90 + ARC_GAP + sweep;
        }

        if (sweep > 0.5) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (isLeft) {
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 270 - ARC_GAP, tipDeg);
            } else {
                dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, -90 + ARC_GAP, tipDeg);
            }
        }

        var rad = tipDeg * Math.PI / 180.0;
        var tipX = cx + r * Math.cos(rad);
        var tipY = cy - r * Math.sin(rad);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, tipY, 4);
    }

    // ---------------- ไอคอน + ตัวเลข ข้างๆ arc ----------------
    function drawSideInfo(dc as Dc, x as Number, y as Number,
                          value as Number or Null, color as Number,
                          icon as BitmapResource or Null) as Void {
        drawIcon(dc, icon, x, y - 14);

        var txt = (value == null) ? "--" : value.toString();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 12, Graphics.FONT_XTINY, txt,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getStress() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getStressHistory)) {
            var it = SensorHistory.getStressHistory({:period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST});
            var s = (it != null) ? it.next() : null;
            if (s != null && s.data != null) {
                return s.data.toNumber();
            }
        }
        return null;
    }

    function getBodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var it = SensorHistory.getBodyBatteryHistory({:period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST});
            var s = (it != null) ? it.next() : null;
            if (s != null && s.data != null) {
                return s.data.toNumber();
            }
        }
        return null;
    }

    // ---------------- HR ----------------
    function updateHeartRateData() as Void {
        var now = System.getTimer();
        if (now - _lastHrCheck > 3000) {
            _lastHrCheck = now;
            var currentHr = 0;

            var activityInfo = Activity.getActivityInfo();
            if (activityInfo != null && activityInfo.currentHeartRate != null) {
                currentHr = activityInfo.currentHeartRate;
            } else {
                currentHr = 72; // ค่าสำรองสำหรับ Simulator
            }

            _hrHistory.add(currentHr);
            if (_hrHistory.size() > _maxHistorySize) {
                _hrHistory = _hrHistory.slice(1, null);
            }
        }
    }

    function drawHeartRateGraph(dc as Dc, cx as Number, cy as Number, w as Number, h as Number) as Void {
        updateHeartRateData();

        var graphWidth = w * 0.4;
        var graphHeight = h * 0.1;
        var gx = cx - (graphWidth / 2);
        var gy = cy - (h * 0.28);

        var minHr = 200;
        var maxHr = 40;

        if (_hrHistory.size() > 0) {
            for (var i = 0; i < _hrHistory.size(); i++) {
                var hr = _hrHistory[i];
                if (hr < minHr) { minHr = hr; }
                if (hr > maxHr) { maxHr = hr; }
            }
        }

        if (maxHr - minHr < 10) {
            maxHr += 5;
            minHr = (minHr - 5 > 0) ? minHr - 5 : 40;
        }

        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(gx, gy, graphWidth, graphHeight);

        dc.setPenWidth(1);
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(gx, gy, gx + graphWidth, gy);
        dc.drawLine(gx, gy + (graphHeight / 2), gx + graphWidth, gy + (graphHeight / 2));
        dc.drawLine(gx, gy + graphHeight, gx + graphWidth, gy + graphHeight);

        dc.setColor(0x898989, Graphics.COLOR_TRANSPARENT);
        dc.drawText(gx - 5, gy - 7, Graphics.FONT_XTINY, maxHr.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(gx - 5, gy + graphHeight - 10, Graphics.FONT_XTINY, minHr.toString(), Graphics.TEXT_JUSTIFY_RIGHT);

        if (_hrHistory.size() > 1) {
            var stepX = graphWidth / (_maxHistorySize - 1);

            dc.setPenWidth(2);
            dc.setColor(0xFF0055, Graphics.COLOR_TRANSPARENT);

            for (var i = 0; i < _hrHistory.size() - 1; i++) {
                var val1 = _hrHistory[i];
                var val2 = _hrHistory[i + 1];

                var x1 = gx + (i * stepX);
                var y1 = gy + graphHeight - ((val1 - minHr).toFloat() / (maxHr - minHr) * graphHeight);

                var x2 = gx + ((i + 1) * stepX);
                var y2 = gy + graphHeight - ((val2 - minHr).toFloat() / (maxHr - minHr) * graphHeight);

                dc.drawLine(x1, y1, x2, y2);
            }

            var lastIdx = _hrHistory.size() - 1;
            var currentVal = _hrHistory[lastIdx];
            var lastX = gx + (lastIdx * stepX);
            var lastY = gy + graphHeight - ((currentVal - minHr).toFloat() / (maxHr - minHr) * graphHeight);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(lastX, lastY, 3);

            // ไอคอนหัวใจ (bitmap) + ตัวเลข HR
            var hrTxt = currentVal.toString();
            var tw = dc.getTextWidthInPixels(hrTxt, Graphics.FONT_XTINY);
            var iconW = (_iconHeart != null) ? _iconHeart.getWidth() : 16;
            var gap = 5;
            var total = iconW + gap + tw;
            var sx = (cx - total / 2).toNumber();
            var ty = (gy - 20).toNumber();

            drawIcon(dc, _iconHeart, sx + iconW / 2, ty);

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx + iconW + gap, ty, Graphics.FONT_XTINY, hrTxt,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
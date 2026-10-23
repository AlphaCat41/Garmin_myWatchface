import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Math;
import Toybox.Time;
import Toybox.Timer;

class myWatchfaceView extends WatchUi.WatchFace {
    private var _progress as Float = 1.0;
    private var _timer as Timer.Timer or Null = null;
    private var _startMs as Number = 0;
    private var _animMs as Number = 800;   // ระยะเวลาแอนิเมชัน (มิลลิวินาที)

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
    
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        // พื้นหลัง
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setAntiAlias(true); // ทำให้เส้นโค้งเนียน

        drawBattery(dc, cx, cy, (w / 2) - 8); //(w / 2) - (ความหนาเส้น / 2)
        drawTime(dc, cx, cy);
        drawDate(dc, cx, cy, h);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
        stopAnim();
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        startAnim();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        stopAnim();
        _progress = 1.0;           // โหมดประหยัดพลังงานแสดงค่าเต็มทันที
        WatchUi.requestUpdate();
    }

    function startAnim() as Void {
        stopAnim();
        _progress = 0.0;
        _startMs = System.getTimer();
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 40, true);   // ประมาณ 25 เฟรมต่อวินาที
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
        _progress = 1.0 - Math.pow(1.0 - t, 3);    // ease-out เริ่มเร็วแล้วค่อยๆ ช้าลง
        WatchUi.requestUpdate();
    }

    // เวลา
    function drawTime(dc as Dc, cx as Number, cy as Number) as Void {
        var clock = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [
            clock.hour.format("%02d"),
            clock.min.format("%02d")
        ]);

        // ตัวจริง
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, Graphics.FONT_NUMBER_MEDIUM, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // วันที่
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

    function drawBattery(dc as Dc, cx as Number, cy as Number, r as Number) as Void {
        var batt = System.getSystemStats().battery;   // ค่าจริง 0-100
        var shown = batt * _progress;                 // ค่าที่กำลังแสดงตามแอนิเมชัน
        var endAngle = 90 - (shown * 3.6);
        var color = batt > 20 ? 0x00FF88 : Graphics.COLOR_RED;

        dc.setPenWidth(8);

        // ราง
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, -270);

        // ระดับแบตเตอรี่
        if (shown > 0.5) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endAngle);
        }

        // ปลายวงโค้ง
        var rad = endAngle * Math.PI / 180.0;
        var tipX = cx + r * Math.cos(rad);
        var tipY = cy - r * Math.sin(rad);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, tipY, 5);

        // ข้อความ % วิ่งตามปลายวงโค้ง ตัวเลขนับขึ้นไปด้วย
        var textR = r - 26;
        var textX = cx + textR * Math.cos(rad);
        var textY = cy - textR * Math.sin(rad);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, textY, Graphics.FONT_XTINY,
            shown.toNumber().toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

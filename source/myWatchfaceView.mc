import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Math;
import Toybox.Time;

class myWatchfaceView extends WatchUi.WatchFace {

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
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
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
        dc.drawText(cx, cy + (h * 0.2), Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawBattery(dc as Dc, cx as Number, cy as Number, r as Number) as Void {
        var batt = System.getSystemStats().battery; // 0-100
        var endAngle = 90 - (batt * 3.6);
        var color = batt > 20 ? 0x00FF88 : Graphics.COLOR_RED;

        dc.setPenWidth(8);

        // ราง
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, -270);

        // ระดับแบตเตอรี่
        if (batt > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endAngle);
        }

        // ตำแหน่งปลายวงโค้ง
        var rad = endAngle * Math.PI / 180.0;
        var tipX = cx + r * Math.cos(rad);
        var tipY = cy - r * Math.sin(rad);

        // จุดวงกลมที่ปลาย
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, tipY, 5);

        // ข้อความ % วางถอยเข้าด้านในตามแนวมุมเดียวกัน
        var textR = r - 26;
        var textX = cx + textR * Math.cos(rad);
        var textY = cy - textR * Math.sin(rad);

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(textX, textY, Graphics.FONT_XTINY,
            batt.toNumber().toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

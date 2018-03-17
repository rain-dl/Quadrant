using Toybox.System as Sys;
using Toybox.Graphics as Gfx;
using Toybox.Application as App;
using Toybox.Lang;

module Battery{

    function drawIcon(dc,battery,battery_low,cx,cy,color,display_percentage){
        var battery = Sys.getSystemStats().battery;
        var width=35;
        var height=19;
        var xStart= cx-width/2;
        var yStart= cy-height/2;

        dc.setPenWidth(1);
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawRectangle(xStart, yStart, width, height);
        dc.fillRectangle(xStart + width - 1, yStart + 6, 3, height - 12);


        if(battery<=battery_low){
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        }

        if(display_percentage){
            dc.drawText(xStart+width/2 , yStart, Gfx.FONT_XTINY, Lang.format("$1$%", [battery.format("%d")]), Gfx.TEXT_JUSTIFY_CENTER);
        }else{
            dc.fillRectangle(xStart + 1, yStart + 1, (width-2) * battery / 100, height - 2);
        }
    }

    function drawArc(dc,battery,battery_low,cx,cy,color,arc_width){
        dc.setPenWidth(arc_width);
        dc.setColor(color,Gfx.COLOR_TRANSPARENT);

        if(battery<=battery_low){
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        }
        var angle_battery = battery * (360 - 58) / 100;
        if(angle_battery>0){
            dc.drawArc(cx,cy,dc.getHeight()/2-1,Gfx.ARC_CLOCKWISE, 90 - 29, (360 - angle_battery.toLong() + 90 - 29) % 360);
        }
    }

    function drawRectangle(dc, battery, battery_low, x, y, width, height, color){
        dc.setPenWidth(1);
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);

        if(battery<=battery_low){
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        }

        dc.drawRectangle(x, y, width, height);
        var fillWidth = battery * (width - 2) / 100;
        dc.fillRectangle(x + width - fillWidth - 1, y + 1, fillWidth, height - 2);
    }
}
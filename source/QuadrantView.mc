using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Timer as Timer;
using Toybox.Time;
using Toybox.Activity as Act;
using Toybox.Math;

class QuadrantView extends Ui.WatchFace {
    private var _width;
    private var _height;
    private var cx;
    private var cy;
    private var timeFont;
    private var timeFontWidth;
    private var timeFontHeight;
    private var _currentTimeColor = 0;
    private var _hour = -1;
    private var _minute = -1;
    private var _second = -1;
    private var _timeZoneOffset = 0;
    private var hourLabel;
    private var colon1Label;
    private var minuteLabel;
    private var colon2Label;
    private var secondLabel;

    private var areaNameLabels = new [4];
    private var areaValueLabels = new [4];

    private var _lastLocation = null;
    
    private var _backgroundColor;
    private var _time1DisplayName;
    private var _time1TimeZone;
    private var _time1DST;
    private var _time2DisplayName;
    private var _time2TimeZone;
    private var _time2DST;
    private var _dateFormat;
    private var _areaInfoType = new [4];
    private var _timeColor;

    private var _redrawAll;
    private var _hidden = true;

    function initialize() {
        Ui.WatchFace.initialize();
    }

    function DebugOutputDateTime(msg, time, isUtc) {
        var t;
        if (isUtc) {
            t = Sys.Time.Gregorian.utcInfo(time, Time.FORMAT_SHORT);
        } else {
            t = Sys.Time.Gregorian.info(time, Time.FORMAT_SHORT);
        }
        Sys.println(Lang.format("$7$: $1$-$2$-$3$ $4$:$5$:$6$", [t.year.format("%02d"), t.month.format("%02d"), t.day.format("%02d"),
            t.hour.format("%02d"), t.min.format("%02d"), t.sec.format("%02d"), msg]));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        _redrawAll = true;
        _hidden = false;
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
        _hidden = true;
    }

//    // The user has just l_redrawAllheir watch. Timers and animations may be started here.
//    function onExitSleep() {
//        Sys.println("onExitSleep");
//        Ui.requestUpdate();
//    }

//    // Terminate any active timers and prepare for slow updates.
//    function onEnterSleep() {
//        Sys.println("onEnterSleep");
//        Ui.requestUpdate();
//    }

    function loadSettings() {
        _backgroundColor = Utils.getColor(App.getApp().getProperty("BackgroundColor"), Gfx.COLOR_BLACK);
        _time1DisplayName = App.getApp().getProperty("Time1DisplayName");
        _time1TimeZone = App.getApp().getProperty("Time1TimeZone");
        _time1DST = App.getApp().getProperty("Time1DST");
        _time2DisplayName = App.getApp().getProperty("Time2DisplayName");
        _time2TimeZone = App.getApp().getProperty("Time2TimeZone");
        _time2DST = App.getApp().getProperty("Time2DST");
        _dateFormat = App.getApp().getProperty("DateFormat");
        _timeColor = App.getApp().getProperty("TimeColor");
        for (var i = 0; i < 4; i++) {
            _areaInfoType[i] = App.getApp().getProperty("Area" + (i + 1).toString() + "Info");
        }
    }

    // Load your resources here
    function onLayout(dc) {
        timeFont = WatchUi.loadResource(Rez.Fonts.id_font_futura_large);
        var dimensions = dc.getTextDimensions("0", timeFont);
        timeFontWidth = dimensions[0];
        timeFontHeight = dimensions[1];

        setLayout(Rez.Layouts.WatchFace(dc));

        hourLabel = View.findDrawableById("HourLabel");
        colon1Label = View.findDrawableById("Colon1Label");
        minuteLabel = View.findDrawableById("MinuteLabel");
        colon2Label = View.findDrawableById("Colon2Label");
        secondLabel = View.findDrawableById("SecondLabel");

        for (var i = 0; i < 4; i++) {
            areaNameLabels[i] = View.findDrawableById("Area" + (i + 1).toString() + "NameLabel");
            areaValueLabels[i] = View.findDrawableById("Area" + (i + 1).toString() + "ValueLabel");
        }

        loadSettings();
    }

    function updateTime(dc, clockTime, isPartialUpdate) {
        _timeZoneOffset = clockTime.timeZoneOffset;

        var h = clockTime.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            if (h > 12) {
                h = h - 12;
            }
        }

        var x, y;

        if (h != _hour) {
            _hour = h;
            hourLabel.setText(_hour.format("%02d"));
        }

        if (clockTime.min != _minute) {
            _minute = clockTime.min;
            minuteLabel.setText(_minute.format("%02d"));
        }

        if (clockTime.sec != _second) {
            _second = clockTime.sec;
            secondLabel.setText(_second.format("%02d"));
            if (isPartialUpdate) {
                dc.setClip(secondLabel.locX, secondLabel.locY, secondLabel.width + 1, secondLabel.height + 1);
                drawBackground(dc);
            }
            secondLabel.draw(dc);
        }

        if (!isPartialUpdate) {
            hourLabel.draw(dc);
            colon1Label.draw(dc);
            minuteLabel.draw(dc);
            colon2Label.draw(dc);
        }
        secondLabel.draw(dc);
    }

    function ConvertToTimeZone(time, timeZone, dst) {
        var utcTimeValue = time.value();
        //Sys.println(Lang.format("UtcTimeValue: $1$  TimeZone: $2$  DST: $3$", [utcTimeValue, timeZone, dst]));
        var adjust = (Time.Gregorian.SECONDS_PER_HOUR * (timeZone + dst)).toLong();
        //Sys.println(Lang.format("Adjust: $1$  Seconds per Hour: $2$", [adjust, Time.Gregorian.SECONDS_PER_HOUR]));
        utcTimeValue += adjust;
        //Sys.println(Lang.format("UtcTimeValue: $1$  TimeZone: $2$  DST: $3$", [utcTimeValue, timeZone, dst]));
        return new Time.Moment(utcTimeValue);
    }

    function TimeToString(time, utc, round) {
        if (time == null) {
            return "--:--";
        }

        var ti;
        if (utc) {
            if (round) {
                ti = Sys.Time.Gregorian.utcInfo(time, Time.FORMAT_SHORT);
            } else {
                ti = Sys.Time.Gregorian.utcInfo(new Time.Moment(time.value() + 30), Time.FORMAT_SHORT);
            }
        } else {
            if (round) {
                ti = Sys.Time.Gregorian.info(time, Time.FORMAT_SHORT);
            } else {
                ti = Sys.Time.Gregorian.info(new Time.Moment(time.value() + 30), Time.FORMAT_SHORT);
            }
        }
        var hour = ti.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            var ampm;
            if (hour > 11) {
                ampm = "p";
            } else {
                ampm = "a";
            }
            if (hour > 12) {
                hour -= 12;
            }
            return Lang.format("$1$:$2$$3$", [hour, ti.min.format("%02d"), ampm]);
        } else {
            return Lang.format("$1$:$2$", [hour.format("%02d"), ti.min.format("%02d")]);
        }
    }

    function UpdateAreaWithTime(dc, areaIndex, timeIndex) {
        var name;
        var timeZone;
        var dst;
        if (timeIndex == 0) {
            name = _time1DisplayName;
            timeZone = _time1TimeZone;
            dst = _time1DST;
        } else {
            name = _time2DisplayName;
            timeZone = _time2TimeZone;
            dst = _time2DST;
        }

        areaNameLabels[areaIndex].setText(name);

        var now = Time.now();
        //DebugOutputDateTime("Local", now, false);
        var t = ConvertToTimeZone(now, timeZone, dst);
        //DebugOutputDateTime(name, t, true);
        var timeString = TimeToString(t, true, false);
        areaValueLabels[areaIndex].setText(timeString);

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithDate(dc, areaIndex) {
        var today = Time.today();
        var date = Sys.Time.Gregorian.info(today, Time.FORMAT_LONG);

        var dateString;
        switch (_dateFormat) {
        case 1:
            dateString = Lang.format("$1$ $2$ $3$", [date.day_of_week.substring(0,3), date.day, date.month.substring(0,3)]);
            break;
        case 2:
            dateString = Lang.format("$1$ $2$", [date.day, date.month.substring(0,3)]);
            break;
        default:
            dateString = Lang.format("$1$ $2$", [date.day_of_week.substring(0,3), date.day]);
            break;
        }

        areaNameLabels[areaIndex].setText("Date");
        areaValueLabels[areaIndex].setText(dateString);

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithBattery(dc, areaIndex) {
        var battery = (Sys.getSystemStats().battery + 0.5).toNumber();
        areaNameLabels[areaIndex].setText("Battery");
        areaValueLabels[areaIndex].setText(battery.format("%d") + "%");

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithCalories(dc, areaIndex) {
        areaNameLabels[areaIndex].setText("Calories");
        areaValueLabels[areaIndex].setText(ActivityMonitor.getInfo().calories.toString());

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithSteps(dc, areaIndex) {
        areaNameLabels[areaIndex].setText("Steps");
        areaValueLabels[areaIndex].setText(ActivityMonitor.getInfo().steps.toString());

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithDistance(dc, areaIndex) {
        areaNameLabels[areaIndex].setText("Distance");
        areaValueLabels[areaIndex].setText((ActivityMonitor.getInfo().distance / 100).toString());

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithHeartRate(dc, areaIndex) {
        var curHeartRate = 0;
        var maxHeartRate = 0;
        if(ActivityMonitor has :HeartRateIterator) {
            var hrIter = ActivityMonitor.getHeartRateHistory(null, true);
            if(hrIter != null){
                var hr = hrIter.next();
                curHeartRate = (hr.heartRate != ActivityMonitor.INVALID_HR_SAMPLE && hr.heartRate > 0) ? hr.heartRate : 0;
                maxHeartRate = hrIter.getMax();
            }
        }
        areaNameLabels[areaIndex].setText("Heart");
        areaValueLabels[areaIndex].setText(Lang.format("$1$ / $2$", [curHeartRate, maxHeartRate]));

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithSunSetRise(dc, areaIndex) {
        var actInfo = Act.getActivityInfo();
        if(actInfo != null && actInfo.currentLocation != null) {
            _lastLocation = actInfo.currentLocation.toRadians();
            //_lastLocation = [39.857 * Math.PI / 180, 116.6 * Math.PI / 180];
            Sys.println(_lastLocation);
        }
        
        if(_lastLocation != null) {
            var day = Time.today().value() + _timeZoneOffset;
            var now = new Time.Moment(Time.now().value());

            var sunset_moment, sunrise_moment;

            sunset_moment = SunCalc.calculate(day, _lastLocation[0], _lastLocation[1], SUNSET);
            DebugOutputDateTime("sunset_moment", sunset_moment, false);
            if (now.greaterThan(sunset_moment)) {
                sunrise_moment = SunCalc.calculate(day + Time.Gregorian.SECONDS_PER_DAY, _lastLocation[0], _lastLocation[1], SUNRISE);
                DebugOutputDateTime("sunrise_moment", sunrise_moment, false);
                areaNameLabels[areaIndex].setText("Sunrise");
                areaValueLabels[areaIndex].setText(TimeToString(sunrise_moment, false, true));
            } else {
                sunrise_moment = SunCalc.calculate(day, _lastLocation[0], _lastLocation[1], SUNRISE);
                if (now.lessThan(sunrise_moment)) {
                    areaNameLabels[areaIndex].setText("Sunrise");
                    areaValueLabels[areaIndex].setText(TimeToString(sunrise_moment, false, true));
                } else {
                    areaNameLabels[areaIndex].setText("Sunset");
                    areaValueLabels[areaIndex].setText(TimeToString(sunset_moment, false, true));
                }
            }
        } else {
            areaNameLabels[areaIndex].setText("Sunrise");
            areaValueLabels[areaIndex].setText(TimeToString(null, false, true));
        }

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaWithAltimeter(dc, areaIndex) {
        var altitude = 0;
        var actInfo = Act.getActivityInfo();
        if (actInfo != null && actInfo.altitude != null) {
            altitude = actInfo.altitude;
        }
        areaNameLabels[areaIndex].setText("Altitude");
        if (System.getDeviceSettings().elevationUnits == Sys.UNIT_STATUTE) {
            altitude = altitude * 3.38;
            areaValueLabels[areaIndex].setText(altitude.toLong().toString() + "ft");
        } else {
            areaValueLabels[areaIndex].setText(altitude.toLong().toString() + "m");
        }

        areaNameLabels[areaIndex].draw(dc);
        areaValueLabels[areaIndex].draw(dc);
    }

    function UpdateAreaValue(dc, areaIndex) {
        var infoType = _areaInfoType[areaIndex];
        switch (infoType) {
        case 0: // Time 1
        case 1: // Time 2
            UpdateAreaWithTime(dc, areaIndex, infoType);
            break;
        case 2: // Date
            UpdateAreaWithDate(dc, areaIndex);
            break;
        case 3: // Battery
            UpdateAreaWithBattery(dc, areaIndex);
            break;
        case 4: // Calories
            UpdateAreaWithCalories(dc, areaIndex);
            break;
        case 5: // Steps
            UpdateAreaWithSteps(dc, areaIndex);
            break;
        case 6: // Distance
            UpdateAreaWithDistance(dc, areaIndex);
            break;
        case 7: // HeartRate
            UpdateAreaWithHeartRate(dc, areaIndex);
            break;
        case 8: // Sunset / Sunrise
            UpdateAreaWithSunSetRise(dc, areaIndex);
            break;
        case 9: // Altimeter
            UpdateAreaWithAltimeter(dc, areaIndex);
            break;
        }
    }

    function updateTimeColor() {
        if (_currentTimeColor != _timeColor) {
            _currentTimeColor = _timeColor;
            var color = Utils.getColor(_timeColor, 0xFF2A1A);
            hourLabel.setColor(color);
            colon1Label.setColor(color);
            minuteLabel.setColor(color);
            colon2Label.setColor(color);
            secondLabel.setColor(color);
        }
    }

    function drawBackground(dc) {
        // Set the background color then call to clear the screen
        dc.setColor(Gfx.COLOR_TRANSPARENT, _backgroundColor);
        dc.clear();
    }

    function drawGrayLines(dc) {
        dc.setColor(0x686868, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);

        var w = dc.getWidth();
        var h = dc.getHeight();

        var x1, x2, y;

        // Line 1
        x1 = 0 * w / 240;
        x2 = 113 * w / 240;
        y = 86 * h / 240;
        dc.drawLine(x1, y, x2, y);

        // Line 2
        x1 = 126 * w / 240;
        x2 = 239 * w / 240;
        y = 86 * h / 240;
        dc.drawLine(x1, y, x2, y);

        // Line 3
        x1 = 0 * w / 240;
        x2 = 113 * w / 240;
        y = 158 * h / 240;
        dc.drawLine(x1, y, x2, y);

        // Line 4
        x1 = 126 * w / 240;
        x2 = 239 * w / 240;
        y = 158 * h / 240;
        dc.drawLine(x1, y, x2, y);
    }

    function drawMarkLines(dc, lines) {
        var span = 0;
        var color = Graphics.COLOR_WHITE;
        dc.setPenWidth(1);
        for (var i = 0; i < lines; i++) {
            switch (i % 4) {
            case 0:
                color = Graphics.COLOR_WHITE;
                break;
            case 1:
                color = Graphics.COLOR_GREEN;
                break;
            case 2:
                color = Graphics.COLOR_BLUE;
                break;
            case 3:
                color = Graphics.COLOR_RED;
                break;
            }

            dc.setColor(color, Graphics.COLOR_BLACK);
            dc.drawLine(0 + i, 0 + i, 239 - i, 0 + i);
            dc.drawLine(0 + i, 239 - i, 239 - i, 239 - i);
            dc.drawLine(0 + i, 0 + i, 0 + i, 239 - i);
            dc.drawLine(239 - i, 0 + i, 239 - i, 239 - i);
        }
    }

    function drawBattery(dc) {
        var battery = (Sys.getSystemStats().battery + 0.5).toNumber();
        Battery.drawRectangle(dc, battery, 15, 182, 136, 42, 6, 0x4D93BD);
        //Battery.drawArc(dc, battery, 15, 119, 119, Gfx.COLOR_ORANGE, 10);
    }

    // Update the view
    function onUpdate(dc) {
        if (_hidden) {
            return;
        }

        var clockTime = Sys.getClockTime();
        var isPartialUpdate = !(_redrawAll || clockTime.sec == 0);

        if (!isPartialUpdate) {
            dc.clearClip();
            drawBackground(dc);
        }

        if (!isPartialUpdate) {
            //drawMarkLines(dc, 120);
            drawGrayLines(dc);
            drawBattery(dc);

            updateTimeColor();

            UpdateAreaValue(dc, 0);
            UpdateAreaValue(dc, 1);
            UpdateAreaValue(dc, 2);
            UpdateAreaValue(dc, 3);
        }

        updateTime(dc, clockTime, isPartialUpdate);

        if (_redrawAll) { _redrawAll = false; }
    }

    function onPartialUpdate(dc) {
        if (!_hidden) {
            var clockTime = Sys.getClockTime();
            updateTime(dc, clockTime, true);
        }
    }
}

# AlarmSearch

Theos tweak for the iOS Clock app (`com.apple.mobiletimer`) that adds a native search bar to `MTAAlarmTableViewController` and filters alarms by their label/title.

## Build

```sh
make package
```

Install the package on the device, then restart the Clock app.

The tweak was written against the iOS 16.6.1 decompilation clues:

- `MTAlarmDataSource` exposes `numberOfAlarms` and `alarmAtRow:`.
- `MTAlarm` exposes `title` and `displayTitle`.
- The target controller is `MTAAlarmTableViewController` inside the Clock app process.

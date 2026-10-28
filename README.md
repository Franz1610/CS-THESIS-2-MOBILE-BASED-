# Handicraft Business Management

A Flutter app for tracking a small handicraft business. It keeps records in a
local SQLite database on the device and includes:

- A dashboard with daily and monthly sales totals and permit renewal reminders.
- Sales history with product, quantity, unit price, date, and notes.
- Inventory for the ten products in `assets/labels.txt`; confirmed camera
  detections increase the matching product stock quantity.
- Recording a sale deducts available stock; deleting a sale restores its stock.
- Inventory quantities can be manually corrected.
- Business profile and permit/registration records with issue and renewal dates.
- Live product detection using `assets/best.tflite`.

## Run

Install Flutter, connect an Android device or start an Android emulator, then
run:

```sh
flutter pub get
flutter run
```

The detection screen needs camera permission. Detection results are shown on
screen. Tap **Add to inventory** and confirm to add the detected quantity for
each matching product to stock. Detection results are not automatically saved
as sales. Record transactions from the Sales tab; only products with stock can
be sold, and the requested quantity cannot exceed stock. Deleting a sale puts
its quantity back into inventory. Use the Inventory tab's edit action to
correct a count. Sales amounts use the business's chosen currency unit but
are not currency-converted.

SQLite data stays on the current device. It is not encrypted or synchronized
with other devices, and this version shows permit reminders in the dashboard
without sending background notifications. Back up the device to protect its
records.

iOS runs require a Mac with Xcode; this Windows project environment can build
and run the Android version.

## Test

```sh
flutter analyze
flutter test
```

# Item Counter

An item counter.  I use it to (1) count my daily pill intake and (2) get a daily average of the # of pills taken.

<div>
<img src="images/MainSheet.png" width="15%" />
<img src="images/AddPillsBottomSheet.png" width="15%" />
<img src="images/SettingsSheet.png" width="15%" />
<img src="images/TransactionViewerSheet.png" width="15%" />
</div>

---

Phase 1, where I built it for my own personal use

If you're interested in using the app, you'll probably want to do the following:
* Build a debug version (to an emulator is fine, although you'll probably want to deploy a debug version to the device that you'll use the app on, if only to create the directory structure)
* Take a copy of the DB file from /data/data/com.example.item_counter_standalone_app
* Add your preferred time zone(s) (and aliases to those time zones) to the time_zone_aliases table
* Add whatever it is you want to count to the pills table.  (Note that the pill_types table and the type_id and the grams_protein_digestion_capacity columns of the pills table aren't currently being used in the app, although you _will_ have to add at least one entry to pill_types and use that value for every type_id field.  You could probably also remove the "not null" constraint on the type_id column.)
* Copy the DB back to your phone
* Create a release .apk file and deploy it to your phone
  * That is, from the project root:
  * `flutter build apk --release`
  *  `adb install [relative path of the .apk file]`
    * eg. `adb install build/app/outputs/flutter-apk/app-release.apk`

---

Phase 2: Making it more accessible to others
* TBC! We'll write this up once we've made the project a bit less 'specific to my own uses.'

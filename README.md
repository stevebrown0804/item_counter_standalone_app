# Item Counter

An item counter.  I use it to (1) count my daily pill intake and (2) get a daily average of the # of pills taken.

<img width="126" height="280" alt="Screenshot (Dec 13, 2025 6 17 05 PM)" src="https://github.com/user-attachments/assets/ffbf15ce-5883-4a63-9767-5f9749e867b8" />
<img width="126" height="280" alt="Screenshot (Dec 13, 2025 7 28 02 PM)" src="https://github.com/user-attachments/assets/b69390de-4b65-4a61-b3c7-e8976d60cf69" />  
<img width="126" height="280" alt="Screenshot (Dec 13, 2025 7 22 14 PM)" src="https://github.com/user-attachments/assets/77bdebbe-305e-4e42-a6ea-268aa9e6dcec" />
<img width="126" height="280" alt="Screenshot (Dec 13, 2025 7 26 07 PM" src="https://github.com/user-attachments/assets/47061c24-1fa0-4a01-9e4e-8f2feb0b88e6" />

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

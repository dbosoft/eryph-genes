# @dbosoft/windevdrive-default

## 1.2.0

### Minor Changes

- 50897f7: new variable devdrive_disk for the dedicated eryph drive (devdrive_name is still accepted); if that drive is missing or not empty, the dev drive falls back to devdrive_location with a warning

## 1.1.0

### Minor Changes

- be95bee: configure: dev drive on an existing volume (devdrive_location, as VHDX or by shrinking the volume) besides a dedicated eryph drive; re-runs keep an existing dev drive, format errors fail the fodder.

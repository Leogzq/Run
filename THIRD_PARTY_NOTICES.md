# Open-source components

DeviceBridge.swift, DeveloperImageStore.swift, SelectedCoordinate.swift and scripts/fetch-idevice.sh are from raph559/WaypointApp, under AGPL-3.0.
https://github.com/raph559/WaypointApp

The iOS reconstruction is distributed under AGPL-3.0, with complete source in this repository and LICENSE.
The integration and application UI were modified on 2026-11-17.

The pinned idevice_ffi binary and header are obtained from StikDebug commit c5b23e228249e384cf3e034fd379bf8b9abb76e2. idevice is by jkcoxson under LGPL-2.1. Source and build instructions:
https://github.com/jkcoxson/idevice
https://github.com/StephenDev0/StikDebug/tree/c5b23e228249e384cf3e034fd379bf8b9abb76e2

To relink, replace Vendor/idevice/libidevice_ffi.a with a compatible library, then build with build-unsigned.sh.

# Third-Party Notices

FreshFlag is an independent project derived from and informed by open-source software. This file records material third-party sources and external services used by the project.

## StayFresh

- Project: StayFresh by Dhiraj706Sardar
- Repository: `https://github.com/Dhiraj706Sardar/stayfresh`
- Role: original Flutter/Firebase scaffolding imported into FreshFlag
- Imported upstream commit: `7431e9323ec448da843a4871ec94a0604557a224`
- License: MIT

The original provenance is also recorded in `UPSTREAM.md`. Required upstream copyright/license notices must be preserved with redistributed source as applicable.

## Open Food Facts

- Service: Open Food Facts
- Role: packaged-food barcode/product metadata lookup
- FreshFlag queries only the limited fields required for product recognition.
- Open Food Facts data/media have their own licensing and attribution terms; FreshFlag does not claim ownership of third-party product data or images.

## Firebase / Flutter packages

FreshFlag uses packages from the Flutter/Dart and Firebase ecosystems, including Firebase Authentication, Cloud Firestore, Firebase Cloud Messaging, `mobile_scanner`, `provider`, `shared_preferences`, and `http`. Their respective licenses remain applicable. The resolved dependency graph is recorded in `pubspec.lock`.

## Reference-only projects

The following projects informed architecture or UX research but their GPL/AGPL source is not intentionally copied into FreshFlag:

- Grocy SwiftUI — GPL-3.0 — reference only.
- KitchenOwl — AGPL-3.0 — reference only.

Grocy itself is MIT-licensed and was used as a conceptual inventory reference.

## Adding third-party code

Before copying or adapting material into FreshFlag:

1. verify its license is compatible with the project's intended distribution;
2. preserve required notices;
3. record the source and purpose here;
4. do not copy GPL/AGPL source unless the project licensing decision is explicitly changed.

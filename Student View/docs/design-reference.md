# Student View implementation reference

Reference artboards: 390 × 844. Core font: Inter. Main colours: `#112850`, `#E9781E`, `#FFFFFF`. Secondary text `#607289`; input fill `#F4F6F9`; borders `#E2E8F0`; success `#10B981`.

| Screen | Source | Main implementation |
| --- | --- | --- |
| Home | Figma 14:11 | `lib/ui/catalogue.dart` |
| Category list | Figma 14:74 | `lib/ui/catalogue.dart` |
| Book details | Figma 14:140; PDF alternate book | `lib/ui/catalogue.dart` |
| Login | Figma 14:195 | `lib/ui/auth.dart` |
| Book reservation | Figma 14:248 | `lib/ui/reservations.dart` |
| Approval | Figma 14:304, 14:1161 | `lib/ui/common.dart` |
| E-books / reader | Figma 14:345, 14:411, 83:438 | `lib/ui/ebooks.dart` |
| Study spaces / rooms / learning form | Figma 14:718, 14:777, 14:970, 14:876 | `lib/ui/reservations.dart` |
| Discussion form | PDF; shared Figma field styles | `lib/ui/reservations.dart` |
| Profile | Figma 14:1188 | `lib/ui/personal.dart` |
| Activity / extensions / notices / downloads | Supplied PDF | `lib/ui/personal.dart`, `lib/ui/ebooks.dart` |
| Splash | Original image embedded in PDF | `lib/main.dart` |

## Original artwork in `assets/figma/`

| File | Design placement | Rendered geometry |
| --- | --- | --- |
| aa226.png | Computer Science category | 164 × 110 crop at reference width |
| 6350b.png | Management category | 164 × 110 cover |
| c406c.png | Law category | 164 × 110 cover |
| 8dbb5.png | Cookery category | 164 × 110 cover |
| 4412b.png | Data Science category | 164 × 110 cover |
| 19b07.png | Engineering category | 164 × 110 cover |
| 964c1.png | Algorithms list / reservation | 64 × 84 / 40 × 56 |
| 88bd2.png | Algorithms details | 180 × 240 |
| 6fea3.png | Digital Circuits | 64 × 84 / 180 × 240 |
| 9df7b.png | Architecting Computing Systems | 64 × 84 |
| fc70d.png, 99570.png | Related suggestions | 40 × 56 |
| 5b55c.png, b252e.png, 76838.png, 8af99.png | E-book list | 48 × 64 |
| 5b55c.png | Hadoop reader header | 80 × 110 |
| bb015.png | Learning space banner | 342 × 140; original Figma vertical crop |
| 27c37.png | Discussion space banner | 342 × 140; original Figma vertical crop |
| b4bff.png, 7d7f8.png | Learning / discussion room rows | 64 × 64 |
| d3851.png | Campus login logo | 120 × 120 contained |
| 9fe95.png | Sample profile photo | 110 × 110 circle |
| splash.png | Splash background artwork | Original embedded PDF image |

SVG files preserve the original downloaded vector assets, using the appropriate button/icon slots. They are bundled locally; the app does not depend on temporary Figma URLs. Inter is bundled under the SIL Open Font License in `assets/fonts/OFL.txt`.

## Intentional functional adaptations

- Native Android uses system status bars and safe areas. Browser/design previews show the reference status bar.
- Layouts scroll and adapt to smaller phones rather than clipping form fields under navigation.
- Dates reflect the current date, and room forms include a booking date to prevent ambiguous reservations.
- Unavailable physical books cannot submit reservations; duplicate requests are rejected.
- Demo login guidance is visible, sample PDFs are identified, and confirmation copy does not claim unconfigured SMS/email delivery.
- The download screen starts empty until a real download is initiated. Browser download confirmation says “Download Started” because browser APIs cannot confirm the final file save.
- The category initially shows the reference's three main books and suggestions; “View all” exposes the remaining sample catalogue.
- The admin interface follows the same styling; no admin Figma artboard was supplied.

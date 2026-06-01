# Comprehensive screenshot suite — visual index

The `Comprehensive Screenshots` workflow generates ~1180 attempted scenarios across the staff-event notification, shield-tab, mod-note-panel, bell-stacking, and smart-search code paths. The latest successful run produced **893 PNGs** (the rest are failure-debug shots from tests that timed out at the framework level on edge cases).

To keep the repo navigable, the 893 PNGs are arranged into **26 contact sheets** below — each sheet contains ~35 thumbnails labeled with the source filename. Click an image to view at full size on GitHub.

For the full-resolution individual PNGs (1396 × 1396), download the artifact from the workflow run:
```
gh run download <RUN_ID> --repo Shalom-Karr/JtechTools --dir tmp/screenshot_review
```
The most recent run on `feature/staff-streams-and-smart-search` was [26741508946](https://github.com/Shalom-Karr/JtechTools/actions/runs/26741508946).

## Section legend

| Filename prefix | What it covers |
| --- | --- |
| **A1xxx** | Bell-row variants — every kind × length × read/unread × role |
| **B2xx** | Shield-tab states (empty, single, mixed, 10-item, scrollable) |
| **C3xx** | Mod-note panel — placement × replies × viewers × role |
| **D4xx** | Bell stacking (3/5/10 + all-kinds clustered) |
| **E5xx** | Smart-search dropdown + indexed results page |
| **F6xx** | Edge cases — unicode, wrap, empty state |
| **G7xx** | Bell rows × time-ago × ordinal |
| **H8xx** | Shield-tab density 1 → 100 notes |
| **I9xx** | Panel × topic-title-length × ordinal |
| **K1xx** | Smart-search results for every tech dictionary head-word |
| **L2xx** | Edge cases — long usernames, RTL, CJK, markdown-like, emoji-spam |
| **M3xx** | Fast-path bell rows × actor × ordinal |
| **N4xx** | Shield-tab events × kind × title-variant |
| **O5xx** | Mod-note panel × note-body × ordinal |
| **P6xx** | Broadest bell-row matrix — kind × title × role × ordinal |

## Contact sheets (26 total — every successful PNG)

![sheet 00](screenshots/comprehensive_grid/sheet_00.png)
![sheet 01](screenshots/comprehensive_grid/sheet_01.png)
![sheet 02](screenshots/comprehensive_grid/sheet_02.png)
![sheet 03](screenshots/comprehensive_grid/sheet_03.png)
![sheet 04](screenshots/comprehensive_grid/sheet_04.png)
![sheet 05](screenshots/comprehensive_grid/sheet_05.png)
![sheet 06](screenshots/comprehensive_grid/sheet_06.png)
![sheet 07](screenshots/comprehensive_grid/sheet_07.png)
![sheet 08](screenshots/comprehensive_grid/sheet_08.png)
![sheet 09](screenshots/comprehensive_grid/sheet_09.png)
![sheet 10](screenshots/comprehensive_grid/sheet_10.png)
![sheet 11](screenshots/comprehensive_grid/sheet_11.png)
![sheet 12](screenshots/comprehensive_grid/sheet_12.png)
![sheet 13](screenshots/comprehensive_grid/sheet_13.png)
![sheet 14](screenshots/comprehensive_grid/sheet_14.png)
![sheet 15](screenshots/comprehensive_grid/sheet_15.png)
![sheet 16](screenshots/comprehensive_grid/sheet_16.png)
![sheet 17](screenshots/comprehensive_grid/sheet_17.png)
![sheet 18](screenshots/comprehensive_grid/sheet_18.png)
![sheet 19](screenshots/comprehensive_grid/sheet_19.png)
![sheet 20](screenshots/comprehensive_grid/sheet_20.png)
![sheet 21](screenshots/comprehensive_grid/sheet_21.png)
![sheet 22](screenshots/comprehensive_grid/sheet_22.png)
![sheet 23](screenshots/comprehensive_grid/sheet_23.png)
![sheet 24](screenshots/comprehensive_grid/sheet_24.png)
![sheet 25](screenshots/comprehensive_grid/sheet_25.png)

## Review-queue click-through

For visual confirmation that clicking a review-queue notification lands on `/review/:id` and marks the row read, see [`review_queue_notifications.md`](review_queue_notifications.md). The `Feature Screenshots` workflow now also runs `spec/system/review_queue_click_through_spec.rb` which produces three additional PNGs per kind (bell-dropdown / landed-on-review-page / bell-after-marked-read), uploaded as part of the `feature-screenshots` artifact.

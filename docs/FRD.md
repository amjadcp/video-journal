# Functional Requirements Document (FRD)

## Project: Video/Photo Journal Android Application

**Platform:** Android
**Framework:** Flutter
**Document Version:** 1.2
**Status:** Business-Ready FRD

---

# 1. Document Control

| Item             | Details                                                    |
| ---------------- | ---------------------------------------------------------- |
| Product Name     | Video/Photo Journal App                                    |
| Document Type    | Functional Requirements Document                           |
| Target Platform  | Android                                                    |
| Technology Stack | Flutter, Firebase, Google Drive API, Local Database        |
| Version          | 1.2                                                        |
| Prepared For     | Product Planning and Development                           |
| Scope            | Offline-first visual journaling with optional cloud backup |

---

# 2. Purpose

This document defines the functional and non-functional requirements for an offline-first Android application that enables users to capture photos and videos, edit them in a WhatsApp-like experience, organize them into folders, tag them, and optionally back them up to Google Drive.

The application is designed for private personal journaling, local-first operation, and optional cloud synchronization.

---

# 3. Business Objectives

The product should achieve the following outcomes:

* Allow immediate app usage without mandatory account creation.
* Provide a simple, familiar media capture and editing experience.
* Help users organize visual memories into structured journals and folders.
* Support secure optional cloud backup to Google Drive.
* Preserve offline usability for all core app functions except sync-related operations.
* Reduce the risk of data loss through backup, restore, and duplicate prevention.

---

# 4. Product Principles

1. **Offline-first** — the app must work fully without internet for all core functions.
2. **User-controlled cloud sync** — backup is optional and entirely user-managed.
3. **Low-friction capture** — camera flow should feel fast and familiar, similar to WhatsApp.
4. **Simple editing** — editing should be minimal, intuitive, and touch-friendly.
5. **Safe organization** — tags, folders, and move actions should never silently alter user content.
6. **No duplicate backup records** — sync and restore must avoid duplication.
7. **Privacy-aware design** — local storage is the default behavior.

---

# 5. Scope

## 5.1 In Scope

* Anonymous app usage without sign-up
* Local media storage
* Photo and video capture
* WhatsApp-like editing flow
* Save to home list or folders
* Automatic tags for home list and folders
* Manual tag add, update, and delete
* Folder creation and organization
* Move media between list and folders without auto-tagging
* Google authentication through Firebase
* Google Drive folder selection for backup root
* Manual and Wi-Fi-based auto backup
* Backup status tracking
* Pull from Drive without duplication
* Cloud deletion preference setting
* Local database backup to cloud
* Restore from backup only

## 5.2 Out of Scope

* Social sharing
* Multi-user collaboration
* Advanced professional video editing
* Cloud recovery of data never backed up
* Desktop and iOS support
* Public sharing to Drive or external users
* Full arbitrary-folder-level Drive restriction beyond platform limits

---

# 6. Stakeholders

| Stakeholder         | Interest                                             |
| ------------------- | ---------------------------------------------------- |
| End User            | Capture, organize, and back up personal visuals      |
| Product Owner       | Define roadmap, scope, and monetization strategy     |
| Development Team    | Build Flutter mobile app and sync workflows          |
| QA Team             | Validate offline, sync, tagging, and backup logic    |
| Security/Compliance | Ensure safe token handling and cloud access controls |

---

# 7. User Personas

## 7.1 Anonymous User

A user who wants to start journaling immediately without registration.

Capabilities:

* Capture photos/videos
* Edit media
* Save locally
* Create folders
* Add/update/delete tags
* Search and view assets offline

## 7.2 Authenticated User

A user who connects Google Drive for backup and device sync.

Capabilities:

* All anonymous features
* Select Drive root folder
* Backup media and local database
* View sync status
* Pull assets from Drive
* Control cloud deletion behavior

---

# 8. Assumptions

* Google authentication is implemented using Firebase Authentication.
* Drive synchronization uses Google Drive API.
* The app stores media and metadata locally by default.
* Network access is only required for authentication and backup-related tasks.
* The app will not attempt to restore unsupported non-backup data.
* Drive access can be logically limited to the user-selected folder structure managed by the app, subject to Google platform constraints.

---

# 9. High-Level User Journey

1. User opens the app.
2. User begins using it immediately without sign-up.
3. User taps the record button.
4. Camera opens with photo/video mode selection.
5. User captures media.
6. Editor opens in a WhatsApp-like flow.
7. User edits and saves media to home list or folder.
8. System assigns auto-tags.
9. User adds, updates, or deletes custom tags.
10. User optionally connects Google account.
11. User selects a Drive folder as the backup root.
12. App syncs assets and local database to Drive manually or over Wi-Fi.
13. User views sync status and pulls data back if needed.

---

# 10. Functional Requirements

## 10.1 Access and Initialization

### FR-001 No Mandatory Registration

The app shall allow users to start using it without creating an account.

**Acceptance Criteria**

* App launches directly into the home experience.
* Local storage is initialized automatically.
* Core functionality works without sign-in.

### FR-002 Local-First Initialization

The app shall create and maintain a local database on first launch.

**Acceptance Criteria**

* Database is available before any user action.
* No internet is required for initialization.

---

## 10.2 Home Screen

### FR-003 Home Screen Layout

The home screen shall present the user’s media journal and essential actions.

**Must include**

* Record button
* Recent visuals
* Folder list
* Tags/search entry points
* Backup status indicator

**Acceptance Criteria**

* Visuals are shown in reverse chronological order.
* Users can open media from the home list.
* Folders are easily accessible.

---

## 10.3 Camera Experience

### FR-004 WhatsApp-Like Camera Flow

The camera experience shall be fast, minimal, and familiar in behavior, similar to WhatsApp.

**Functional Expectations**

* One-tap access from the home screen
* Photo and video capture modes
* Clean capture interface
* Quick review after capture

**Acceptance Criteria**

* Camera opens immediately on tap.
* User can switch between photo and video modes.
* Capture does not require navigating multiple screens.

---

## 10.4 Media Editing

### FR-005 WhatsApp-Like Editing Flow

Captured media shall be opened in a lightweight editor similar to WhatsApp’s editing experience.

**Photo Editing Tools**

* Crop
* Rotate
* Draw
* Add text
* Add stickers/emoji
* Basic filters

**Video Editing Tools**

* Trim
* Add text
* Draw overlay
* Add stickers/emoji

**Acceptance Criteria**

* Editing screen appears immediately after capture.
* User can save or discard edits.
* Editing should remain simple and touch-friendly.

---

## 10.5 Saving and Organization

### FR-006 Save to Home List

When a visual is saved to the home list, the system shall automatically apply a date tag in the format `yy-mm-dd-hh-mm`.

**Acceptance Criteria**

* Tag is generated automatically.
* User may add additional tags.
* The date tag is stored with the visual metadata.

### FR-007 Save to Folder

When a visual is saved to a folder, the system shall automatically apply the folder sequence tag.

**Initial Sequence Rule**

* First item in a folder: `#1`
* Next items: `#2`, `#3`, and so on

**Acceptance Criteria**

* Each folder has its own independent sequence.
* Sequence does not affect other folders.

### FR-008 Folder Tag Format

The application shall use a consistent folder tagging format.

**Recommended Format for v1**

* `#1`, `#2`, `#3`

**Future Enhancement**

* Optional display format such as `Day1`, `Day2`, `Day3`

### FR-009 Move Without Auto-Tagging

The app shall allow visuals to be moved between the home list and folders without generating a new automatic tag during transfer.

**Acceptance Criteria**

* Existing tags remain unchanged.
* No new auto-tag is applied during move.
* User-initiated location change does not alter sequence history.

---

## 10.6 Tag Management

### FR-010 Add Tags

The user shall be able to add multiple tags to a visual.

**Acceptance Criteria**

* A visual can contain multiple tags.
* Tags may be added while saving or later from details view.

### FR-011 Update Tags

The user shall be able to update existing tags attached to a visual.

**Acceptance Criteria**

* Tag label can be edited.
* Updated tag is reflected in all relevant views.
* Visual location does not change when a tag is edited.

### FR-012 Delete Tags

The user shall be able to delete tags from a visual.

**Acceptance Criteria**

* Removing a tag affects only the selected visual unless global tag deletion is implemented later.
* Deleting a tag does not delete the visual.

### FR-013 Search by Tag

The user shall be able to search media by tag.

**Acceptance Criteria**

* Search works offline.
* Search returns matching visuals quickly.

---

## 10.7 Folder Management

### FR-014 Create Folders

The user shall be able to create folders to organize media.

**Acceptance Criteria**

* Folder name is required.
* Folder is created locally immediately.
* Folder supports backup mapping later.

### FR-015 View Folder Contents

The app shall allow users to open and browse media inside each folder.

**Acceptance Criteria**

* Folder views show only relevant content.
* Folder item count is visible if feasible.

---

## 10.8 Local Storage

### FR-016 Local Asset Storage

The app shall store all media files and metadata locally by default.

**Acceptance Criteria**

* Media is available offline.
* Local database contains references and status values.
* The app remains usable without network access.

---

## 10.9 Google Authentication and Drive Setup

### FR-017 Google Sign-In

The app shall support Google authentication through Firebase Authentication.

**Acceptance Criteria**

* User can sign in with Google.
* User can sign out.
* Authentication state persists across sessions.

### FR-018 Drive Root Folder Selection

After sign-in, the user shall be prompted to choose a Google Drive folder that serves as the root backup folder.

**Acceptance Criteria**

* User selects a single Drive folder.
* App stores the selected Drive folder ID.
* App-created folders are created under this root structure.

### FR-019 Restricted Drive Usage

The app shall, where technically feasible, limit its Drive operations to the selected folder and app-managed files.

**Note**
Google Drive access is constrained by platform and API rules. The app should enforce logical scoping even if full folder-only permission restriction is not available.

---

## 10.10 Backup

### FR-020 Manual Backup

The user shall be able to trigger backup manually.

**Acceptance Criteria**

* Backup can be started from settings or backup screen.
* Only changed or unsynced data is uploaded.

### FR-021 Auto Backup Over Wi-Fi

The user shall be able to enable automatic backup when connected to Wi-Fi.

**Acceptance Criteria**

* Backup runs only when Wi-Fi is available.
* Google Drive must be connected.
* Auto backup runs in the background when allowed.

### FR-022 Backup Status Display

The app shall display the sync status of each asset.

**Allowed Status Values**

* Not backed up
* Pending
* Syncing
* Synced
* Failed

### FR-023 Backup Summary

The app shall provide overall backup metrics.

**Metrics**

* Total assets
* Synced assets
* Pending assets
* Failed assets
* Last backup time

### FR-024 Incremental Sync

The app shall upload only changed or missing items during sync.

**Acceptance Criteria**

* Existing unchanged files are not re-uploaded.
* Sync operations are efficient and idempotent.

---

## 10.11 Drive Pull and Duplicate Prevention

### FR-025 Pull Assets from Drive

The user shall be able to download backed-up assets from Drive.

**Acceptance Criteria**

* Local database is checked first.
* Missing files only are downloaded.
* Existing files are not duplicated.

### FR-026 Duplicate Prevention Logic

The app shall prevent duplicate records using identifiers such as:

* Drive file ID
* Local asset UUID
* Asset hash

**Acceptance Criteria**

* Pulling the same item twice does not create duplicates.
* Restore maintains data integrity.

---

## 10.12 Cloud Deletion Behavior

### FR-027 Delete Cloud Copy Option

The settings screen shall allow the user to choose whether deleting a local asset should also delete the backed-up cloud copy.

**Acceptance Criteria**

* User can enable or disable this option.
* When enabled, cloud copy is removed on local delete.
* When disabled, cloud copy is retained.

---

## 10.13 Local Database Backup

### FR-028 Backup Local Database

The app shall also back up the local database to the cloud.

**Database Content to Include**

* Media metadata
* Folder mappings
* Tags
* Sync state
* User settings related to backup and Drive

**Acceptance Criteria**

* Database backup is synchronized with media backup.
* The backed-up database can support restore operations.

---

## 10.14 Restore Behavior

### FR-029 Restore Only Backed-Up Data

The app shall restore only data present in the backup.

**Acceptance Criteria**

* No attempt is made to restore never-backed-up data.
* Restore does not create duplicates.
* Metadata and folder structure are restored as available in backup.

---

## 10.15 Offline Operation

### FR-030 Offline Availability

The app shall work fully offline for all core features except Google authentication and cloud sync.

**Available Offline**

* Capture
* Edit
* Save
* Tagging
* Tag update/delete
* Folder management
* Search
* Move items
* View media

**Requires Internet**

* Google sign-in
* Backup
* Restore
* Drive pull

---

# 11. Non-Functional Requirements

## 11.1 Performance

* Camera should open quickly after tap.
* Local list and search should feel immediate.
* Backup should be incremental and efficient.

## 11.2 Reliability

* No media should be lost during save or sync.
* Failed syncs should be retryable.
* Duplicate records must be prevented.

## 11.3 Security

* Tokens should be stored securely.
* Local database should be protected.
* Firebase should store only required auth and sync preference data.

## 11.4 Usability

* Camera and editor should remain simple and familiar.
* Main interactions should be reachable with minimal taps.
* Backup status and sync behavior should be easy to understand.

## 11.5 Scalability

* The app should support a large number of visuals, folders, and tags.
* Sync should continue to function efficiently as the media library grows.

---

# 12. Data Model Overview

## 12.1 Visual Asset

| Field          | Type      | Description              |
| -------------- | --------- | ------------------------ |
| id             | UUID      | Unique visual identifier |
| asset_type     | Enum      | Photo or Video           |
| local_path     | String    | Local file path          |
| thumbnail_path | String    | Preview file path        |
| folder_id      | UUID/Null | Associated folder        |
| auto_tag       | String    | System-generated tag     |
| custom_tags    | Array     | User-added tags          |
| created_at     | Timestamp | Creation time            |
| updated_at     | Timestamp | Last update time         |
| sync_status    | Enum      | Backup status            |
| drive_file_id  | String    | Drive reference          |
| asset_hash     | String    | Duplicate check value    |

## 12.2 Folder

| Field            | Type      | Description          |
| ---------------- | --------- | -------------------- |
| id               | UUID      | Unique folder ID     |
| name             | String    | Folder name          |
| sequence_counter | Integer   | Next auto-tag number |
| created_at       | Timestamp | Creation time        |
| updated_at       | Timestamp | Last update time     |

## 12.3 Tag

| Field           | Type      | Description      |
| --------------- | --------- | ---------------- |
| id              | UUID      | Unique tag ID    |
| name            | String    | Tag label        |
| visual_asset_id | UUID      | Related visual   |
| created_at      | Timestamp | Creation time    |
| updated_at      | Timestamp | Last update time |

## 12.4 User Settings

| Field                             | Type    | Description               |
| --------------------------------- | ------- | ------------------------- |
| auto_backup_enabled               | Boolean | Wi-Fi backup enabled      |
| wifi_only_backup                  | Boolean | Restrict backup to Wi-Fi  |
| delete_cloud_copy_on_local_delete | Boolean | Cloud deletion preference |
| drive_connected                   | Boolean | Drive auth state          |
| drive_root_folder_id              | String  | Selected Drive folder     |
| auth_status                       | Enum    | Signed in / signed out    |

---

# 13. Acceptance Summary

A release will be considered acceptable when the following are true:

* Users can start using the app without an account.
* Camera, editing, and backup feel simple and familiar, similar to WhatsApp.
* Photos and videos can be saved to the home list or folders.
* Tags can be added, updated, and deleted.
* Auto-tagging works correctly for home list and folder saves.
* Users can move items without unwanted re-tagging.
* Google Drive sync works with manual and Wi-Fi-based backup.
* Backup status is visible.
* Duplicate files are not created during pull or restore.
* Local database backup is included in cloud sync.
* The app works offline for all non-cloud functions.

---

# 14. Risks and Constraints

## 14.1 Google Drive Permission Constraint

Google Drive may not support true one-folder-only authorization in the exact way the business may prefer. The product should implement logical folder scoping and manage only app-owned data within the selected folder.

## 14.2 Background Sync Constraints

Android background behavior may vary by device and battery optimization settings.

## 14.3 Media Editing Scope

WhatsApp-like editing should remain lightweight in the first release. Advanced editing is out of scope.

---

# 15. Release Recommendation

## MVP Release

The first release should include:

* Anonymous use
* Local storage
* Capture
* WhatsApp-like editing
* Home list and folder saving
* Tag add/update/delete
* Google sign-in
* Drive root folder selection
* Manual backup
* Wi-Fi auto backup
* Backup status
* Duplicate-safe pull
* Database backup

## Phase 2 Enhancements

* Optional `Day1/Day2` display format
* Advanced filters
* Better backup analytics
* Recycle bin
* Multi-device conflict handling improvements
* Custom folder cover images

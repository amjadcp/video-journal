# Technical Design Document

## Video/Photo Journal Android Application

**Version:** 1.0
**Platform:** Android
**Framework:** Flutter
**Architecture:** Clean Architecture + Offline First
**Reference:** FRD Version 1.2

---

# 1. Technical Overview

## Purpose

This document defines the technical architecture, implementation standards, development guidelines, third-party integrations, folder structure, coding standards, UI standards, and operational conventions for the Video/Photo Journal Android application.

The application is designed as an offline-first visual journaling platform that allows users to:

* Capture photos and videos
* Edit media
* Organize content using folders and tags
* Backup to Google Drive
* Restore backups
* Operate without internet connectivity except for authentication and synchronization

---

# 2. Architecture Principles

## Core Principles

### Offline First

Local device storage is always the source of truth.

All features except:

* Authentication
* Backup
* Restore
* Sync

must work without internet access.

---

### Local Before Cloud

User actions should:

1. Save locally first
2. Update UI immediately
3. Queue cloud sync operations

Never block user actions while waiting for cloud responses.

---

### Clean Architecture

The project shall use:

* Presentation Layer
* Domain Layer
* Data Layer

Business logic must never exist inside UI widgets.

---

### Feature-Based Structure

Each feature owns:

* UI
* State Management
* Domain Models
* Repository Contracts
* Data Sources

---

# 3. Technology Stack

## Mobile Framework

| Tool    | Purpose              |
| ------- | -------------------- |
| Flutter | Mobile Application   |
| Dart    | Programming Language |

---

## State Management

| Tool          | Purpose                          |
| ------------- | -------------------------------- |
| Riverpod      | State Management                 |
| Flutter Hooks | Optional UI state simplification |

---

## Local Storage

| Tool          | Purpose             |
| ------------- | ------------------- |
| Drift         | Local Database      |
| SQLite        | Database Engine     |
| Path Provider | Local Storage Paths |

---

## Camera & Media

| Tool          | Purpose             |
| ------------- | ------------------- |
| Camera        | Photo/Video Capture |
| Image         | Image Processing    |
| FFmpeg Kit    | Video Trimming      |
| Photo Manager | Media Management    |

---

## Authentication

| Tool                    | Purpose        |
| ----------------------- | -------------- |
| Firebase Authentication | Google Sign-In |

---

## Cloud Sync

| Tool             | Purpose             |
| ---------------- | ------------------- |
| Google Drive API | Backup Storage      |
| Google Sign-In   | Drive Authorization |

---

## Background Processing

| Tool        | Purpose                |
| ----------- | ---------------------- |
| WorkManager | Background Backup Jobs |

---

## Security

| Tool                   | Purpose         |
| ---------------------- | --------------- |
| Flutter Secure Storage | Token Storage   |
| Cryptography Package   | Hash Generation |

---

## Analytics (Optional Future)

| Tool                 | Purpose          |
| -------------------- | ---------------- |
| Firebase Analytics   | Usage Analytics  |
| Firebase Crashlytics | Crash Monitoring |

---

# 4. Third-Party Services

## Required

### Firebase

Services:

* Authentication

Stored Data:

* User ID
* Authentication State
* Drive Connection Status
* Backup Settings

Firebase must NOT store:

* Media Files
* Journal Entries
* Photos
* Videos

---

### Google Drive

Stores:

* Photos
* Videos
* Database Backups
* Metadata Backups

---

# 5. High-Level Architecture

User
↓
Flutter App
↓
Presentation Layer
↓
Riverpod Providers
↓
Domain Layer
↓
Repositories
↓
Data Layer
├── Local Database
├── Local File Storage
└── Google Drive Sync

---

# 6. Folder Structure

lib/

├── app/
│ ├── routes/
│ ├── theme/
│ ├── constants/
│ └── dependency_injection/
│
├── core/
│ ├── errors/
│ ├── network/
│ ├── storage/
│ ├── logging/
│ ├── extensions/
│ ├── utilities/
│ └── widgets/
│
├── features/
│
│ ├── authentication/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── camera/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── media_editor/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── journal/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── folders/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── tags/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── backup/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ ├── sync/
│ │ ├── data/
│ │ ├── domain/
│ │ └── presentation/
│
│ └── settings/
│ ├── data/
│ ├── domain/
│ └── presentation/
│
├── shared/
│ ├── widgets/
│ ├── models/
│ ├── enums/
│ └── services/
│
└── main.dart

---

# 7. Local Storage Structure

Application Storage

media/
├── photos/
├── videos/

thumbnails/
├── photos/
├── videos/

database/
├── journal.db

temp/

exports/

---

# 8. Database Design

## Visual Asset

Fields

* id
* asset_type
* local_path
* thumbnail_path
* auto_tag
* created_at
* updated_at
* sync_status
* drive_file_id
* asset_hash

---

## Folder

Fields

* id
* name
* sequence_counter
* created_at
* updated_at

---

## Tag

Fields

* id
* visual_asset_id
* name
* created_at
* updated_at

---

## User Settings

Fields

* auto_backup_enabled
* wifi_only_backup
* delete_cloud_copy
* drive_root_folder_id
* last_backup_time

---

# 9. Synchronization Design

## Sync Strategy

Use:

Local Database = Source of Truth

Workflow:

User Action
↓
Save Locally
↓
Update UI
↓
Queue Sync Job
↓
Background Upload

---

## Duplicate Prevention

Each asset shall have:

* UUID
* SHA256 Hash
* Drive File ID

Before download:

1. Check UUID
2. Check Drive File ID
3. Check Hash

Only download missing assets.

---

# 10. Coding Standards

## Naming

### Classes

PascalCase

Example:

JournalRepository

FolderSyncService

---

### Variables

camelCase

Example:

folderCounter

backupStatus

---

### Constants

lowerCamelCase

Example:

defaultFolderName

maxUploadRetries

---

### Files

snake_case

Examples:

folder_repository.dart

backup_service.dart

---

## Widget Rules

Avoid widgets larger than 300 lines.

Extract:

* Components
* Dialogs
* Forms

into separate files.

---

## Business Logic Rules

Never place business logic inside:

* Widget build methods
* Screens
* Dialogs

Business logic belongs in:

* Use Cases
* Services
* Repositories

---

## State Management Rules

Use Riverpod exclusively.

Avoid:

* Global variables
* Singleton state containers

---

# 11. Git Workflow

## Branch Naming

feature/camera-module

feature/google-drive-sync

fix/backup-status

refactor/folder-service

---

## Commit Format

Format:

type(scope): message

Examples:

feat(camera): add photo capture flow

feat(sync): implement incremental upload

fix(tags): prevent duplicate tag creation

refactor(database): optimize asset queries

docs(frd): update backup workflow

test(sync): add duplicate prevention tests

---

## Allowed Types

* feat
* fix
* refactor
* docs
* test
* chore

---

## Commit Tone

Good:

feat(tags): add tag rename functionality

Bad:

fixed stuff

updated code

changes

Commit messages must clearly explain intent.

---

# 12. UI Design System

## Design Philosophy

Minimal + Emotional + Slightly Gamified

The application should feel:

* Personal
* Calm
* Modern
* Reflective

Not:

* Corporate
* Enterprise
* Social Media

---

## Visual Style

Inspired by:

* WhatsApp simplicity
* Google Photos cleanliness
* Modern journaling applications

---

## Color System

Support:

* Light Theme
* Dark Theme

Theme switching:

* System Default
* Light
* Dark

---

## Design Language

Use:

* Rounded corners
* Soft shadows
* Clean typography
* Large touch targets

Avoid:

* Heavy gradients
* Neon colors
* Complex illustrations

---

## Gamification

Subtle only.

Examples:

Folder Progress

Day 12 of 30

Journey Progress

52 Memories Saved

Backup Completion

100% Synced

Never introduce:

* Leaderboards
* Competitive elements
* Social scores

---

# 13. User Messaging Standards

Tone:

* Friendly
* Clear
* Calm
* Non-technical

Avoid:

* Error codes
* Developer language

---

# 14. Confirmation Dialogs

## Delete Visual

Title

Delete Memory?

Message

This memory will be removed from your device.

Buttons

Cancel

Delete

---

## Delete Visual + Cloud

Title

Delete Memory Everywhere?

Message

This memory will be removed from your device and Google Drive backup.

Buttons

Cancel

Delete

---

## Sign Out

Title

Sign Out?

Message

Your local memories will remain on this device.

Buttons

Cancel

Sign Out

---

## Disconnect Drive

Title

Disconnect Google Drive?

Message

Your backups will remain in Drive, but syncing will stop.

Buttons

Cancel

Disconnect

---

# 15. Success Messages

Backup Complete

Your memories are safely backed up.

Folder Created

Folder created successfully.

Tag Updated

Tag updated.

Memory Saved

Memory saved successfully.

Drive Connected

Google Drive connected successfully.

---

# 16. Error Messages

Camera Error

Unable to open the camera. Please try again.

Backup Error

Backup could not be completed. We'll try again later.

Drive Error

Unable to connect to Google Drive.

Storage Error

Not enough storage space available.

Sync Error

Some items could not be synced.

---

# 17. Logging Standards

Use structured logging.

Log:

* Authentication
* Backup
* Sync
* Restore
* Database Errors

Never log:

* User media paths
* Authentication tokens
* Personal content

---

# 18. Testing Requirements

Minimum Coverage

* Domain Layer: 80%
* Repository Layer: 80%
* Critical Sync Logic: 90%

Must Test

* Auto Tag Generation
* Folder Sequencing
* Duplicate Prevention
* Restore Flow
* Backup Flow
* Tag CRUD

---

# 19. Future Expansion Considerations

Architecture should support:

* iOS Application
* Web Viewer
* Encrypted Backup
* Timeline View
* AI Search
* Memory Highlights

without major restructuring.

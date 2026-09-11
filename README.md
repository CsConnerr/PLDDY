# PLDDY

Plan your day with less guesswork.

## Description

PLDDY is a Flutter daily planning app built for people who know what they need to do but struggle with deciding when to do it.

Add fixed commitments such as class, work, appointments, and errands. PLDDY then looks at the real open time in your day and suggests practical times for studying, homework, and workouts.

The redesigned planner can also build several flexible activities into one day while respecting existing commitments, activity duration, transition time, and the current time.

## Current features

1. Daily and monthly calendar views with task indicators.
2. Task categories, durations, editing, deletion, and completion tracking.
3. Smart time suggestions that avoid conflicts and past times.
4. Transition room around existing commitments.
5. Full day planning for study, homework, and workouts.
6. Daily summaries showing planned time and remaining open time.
7. Local task persistence with compatibility for older saved PLDDY tasks.

## Project structure

The main application interface is in `lib/main.dart`.

The scheduling engine is in `lib/planner.dart`.

The task model and saved data compatibility logic are in `lib/task.dart`.

Planner and model tests are in the `test` folder.

## Android

The original Android release is available on Google Play under the package `com.connerr.plddy`.

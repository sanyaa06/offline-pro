# Offline Ride Tracker

A Flutter-based ride tracking system that continues estimating cab movement even when internet connectivity is lost.

## Problem
Ride-tracking apps often stop updating when the user loses network access. This project solves that by switching from real-time GPS tracking to predictive offline tracking.

## Features
- Real-time GPS tracking in online mode
- Predictive movement when offline
- Uses last known speed, direction, and time elapsed
- Confidence level: High / Medium / Low
- Route deviation detection
- Manual testing mode for offline simulation

## Tech Stack
- Flutter
- Dart
- GPS/location services
- Maps integration

## How It Works
Online GPS → Save last known location, speed, direction → Network drops → Predict next location → Show confidence level

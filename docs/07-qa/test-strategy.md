# Test Strategy

## Core

- Device, network, Firebase emulator, native runtime 없이 실행되어야 한다.
- 빠르고 deterministic해야 한다.

## Architecture

- core import boundary를 확인한다.
- platform SDK import는 adapter 계층으로 제한한다.

## Godot

- import pass를 먼저 수행한다.
- compile check는 Godot 로그의 `SCRIPT ERROR` / `ERROR:`를 실패로 처리한다.
- smoke scene은 최소한 main scene 설정과 runtime bootstrap을 확인한다.

## Release

- Google Play, App Store, AppsInToss, Firebase blocker를 분리해 inventory한다.


# Advanced Path Tracing for Cyberpunk 2077

[![GitHub Release](https://img.shields.io/github/v/tag/codecrafting-io/AdvancedPathTracingCP2077?label=version)](https://github.com/codecrafting-io/AdvancedPathTracingCP2077/releases)
[![Issues](https://img.shields.io/github/issues/codecrafting-io/AdvancedPathTracingCP2077)](https://github.com/codecrafting-io/AdvancedPathTracingCP2077/issues)

This repository is for the development of the [Cyber Engine Tweaks](https://wiki.redmodding.org/cyber-engine-tweaks) based mod for the game [Cyberpunk 2077](https://www.cyberpunk.net/). This mod enables key advanced controls for Path Tracing, all now available through a native UI thanks to [Native Settings](https://www.nexusmods.com/cyberpunk2077/mods/3518).

**NOTE:** This is a **Work In Progress** mod, so things may improve in the future.

![Advanced Path Tracing Menu](/menu.png?raw=true)

## Features

- Control Path Tracing with the following modes:
  - **ReGIR DI/GI**: Reservoir-based Grid Importance Sampling, is a world space light sampling on top of ReSTIR. Often looks and performs better, but can be noisier
  - **ReSTIR DI/GI**: Reservoir SpatioTemporal Importance samples for Global Illumination, is a screen space light sampling used to illuminate secondary surfaces. This is the vanilla mode
  - **ReSTIR DI**: This is the older PT from update 2.0, used for DI only. Allows control of rays per pixel and bounces per ray. Allows control of rays per pixel and bounces per ray
- Control Path Tracing internal settings to set the following levels of quality:
  - **Vanilla**: Default game quality
  - **Performance**: Faster but noisier
  - **Balanced**: Improve on Vanilla quality and increase performance by until 1%
  - **Quality**: Heavy but less noise and higher quality
  - **Psycho**: Flatline your GPU 💀
- Path Tracing Optimizations: Enables the following optimizations:
  - Adds missing PT Reflections through Screen Space Reflections
  - Reduce noise on some scenarios. Some scenes may appear a little darker
  - Use PDF (Probability Density Function) for minor performance boost
  - Minor reflections improvement on transparent surfaces
  - Minor GI/DI light behavior optimizations
- Control number of rays per pixel and rays per bounce when using **ReSTIR DI** mode
- Enable V self reflection.
- Enable DLSS ray reconstruction particles in raytracing. By default, the game separates particles for RR, so enable this if it's not raining or it's indoors
- Disable NRD Denoiser helper for Ray Reconstruction. Path Tracing has two main denoisers, RR and NRD, so using RR should disable NRD, but sometimes it enables, this helps to keep NRD disabled over time
- Auto Refresh game when loading and exiting the menu. The game has a tendency to not have "full performance" when loading or exiting menus, this helps to mitigate the problem by pausing the game for a few seconds. This is disabled by default

**NOTE:** ReGIR DI/GI has implementation issues, such as sometimes not activating correctly (mostly "fixed" now), noise breakup when using ray reconstruction (especially at balanced quality or below) in some scenarios. Also, performance can take up to 30s to stabilize if you do not reload the save or restart the game, especially after disabling. Using Auto Refresh Game or entering and exiting Photo Mode may also help.

**NOTE:** This mod is designed for Path Tracing (PT), not normal Ray Tracing (RT), so quality levels, optimizations are mostly for PT not RT.

## Requirements

- [Cyber Engine Tweaks (>= v1.30.1)](https://www.nexusmods.com/cyberpunk2077/mods/107)
- [Native Settings UI (>= 1.96)](https://www.nexusmods.com/cyberpunk2077/mods/3518)

## Compatibility

This mod is currently not compatible with [Ultra Plus Control (sammilucia)](https://www.nexusmods.com/cyberpunk2077/mods/10490) due to some overlapping settings and differences in behavior. If you want to use the ULTRA+ fixes and VRAM settings, I suggest you import those settings into an ini file and load them separately from the RT/PT settings.

Advanced Path Tracing does not use the same settings and values as ULTRA+ Control for RT/PT, but most of the behavior can be replicated. To do this, use the `ptQuality.lua` file to apply the same values in ULTRA+ Control.

## Installation

Extract the zip and paste the `bin` folder to `<path to cyberpunk 2077>`. Note that the end result should be:

`<path to cyberpunk 2077>\bin\x64\plugins\cyber_engine_tweaks\mods\AdvancedPathTracing`

Remember to install the requirements.

## Settings

The mod save your preferences in the `settings.json` file.

| name | type | default | description |
| ---- | ---- | ------- | ----------- |
| degug | boolean | false | Enables extra messages on the CET console |
| enableNRDControl | boolean | true | Controls NRD denoiser disable helper state |
| rayNumber | int | 2 | Number of rays per pixel when using ReSTIR DI mode |
| rayBounce | int | 2 | Number of bounces per ray when using ReSTIR DI mode |
| fastTimeout | float | 1.0 | Shortest timeout of a series internal timers |
| slowTimeout | float | 30.0 | Timeout used in enableNRDControl |
| refreshGame | int | false | Wheter or not Auto Refresh Game |
| refreshTimeout | float | 5.0 | The Auto Refresh Timeout |
| selfReflection | boolean | false | Whether or not to enable V's self-reflection. Head won't appear due to game limitation. |
| enableDLSSDParticles | boolean | true | Whether or not enable DLSS Ray Reconstruction particles |
| ptModeIndex | int | 2 | Path Tracing mode. Defaults to ReSTIR DI/GI |
| ptQualityIndex | int | 3 | Path Tracing mode. Defaults to balanced |
| ptOptimizations | boolean | true | Whether or not to enable PT Optimizations |

## Credits

- [Ultra Plus Control (sammilucia)](https://www.nexusmods.com/cyberpunk2077/mods/10490)
- [Weathermancer (RMK)](https://www.nexusmods.com/cyberpunk2077/mods/9805)
- [betterHeadlights (keanuWheeze)](https://www.nexusmods.com/cyberpunk2077/mods/5013)
- [Lua Kit for CET (Pavel Siberx)](https://github.com/psiberx/cp2077-cet-kit)

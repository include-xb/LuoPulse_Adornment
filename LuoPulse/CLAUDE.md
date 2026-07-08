# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

~~**Priority**: When the existing code conflicts with the game design document（《洛之动脉_缤纷繁饰_260613.pdf》）, the design document takes precedence.~~

## Project Overview

**LuoPulse（洛之动脉）** — a Godot 4.7 rhythm game (Forward+ renderer), targeting **mobile (横屏, 16+)**. A non-commercial, Chinese Vocaloid fan-made 4K fixed-track falling-note rhythm game.

Two game lines:

- **Sympathy（共鸣主线）**: Fixed song list, chapter/level-gated. Story-driven progression. ~15-20 songs across 5 chapters.
- **Side Line（断章主线）**: Album-based, free selection. Unlocked when 共鸣 progress ≥ 60%. Supports custom song import.

Core experience: **Music + Atmosphere Evolution (color/saturation tied to progress) + Story Collection (diary fragments)**.

Theme: Telling stories of Chinese Vocaloid culture — producers and their creative backgrounds are equally important as the virtual singers themselves.

## Running / Testing

- **Editor**: Open `project.godot` in Godot 4.7. Main scene configured via `run/main_scene`.
- **Run**: F6 (main scene) or F5 (current scene) in Godot editor.
- **Godot MCP**: Included via `addons/godot_mcp/`. The `MCPRuntime` autoload bridges runtime to the MCP server for `take_screenshot`, `send_input`, `query_runtime_node`.
- No CLI build/lint — all development inside Godot editor.

## Architecture

### Autoloads (Singletons)

| Autoload       | Script                                    | Purpose                                                                                                                        |
| -------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `Global`       | `Script/GameManager/Global.gd`            | Shared game state: user prefs, song lists, judging constants, game mode, combo/accuracy. Holds `NOTICE_BOX` for notifications. |
| `SceneManager` | `Script/GameManager/SceneManager.gd`      | Scene transitions with fade-to-black/fade-from-black tween (0.25s each). Always use `SceneManager.change_scene(path)`.         |
| `MCPRuntime`   | `addons/godot_mcp/runtime/mcp_runtime.gd` | Godot MCP runtime helper.                                                                                                      |

### Scene Flow

```
Launch ──→ MainMenu ──→ Sympathy (song select) ──→ Gameplay ──→ FinishMenu
                ├──→ Side Line (断章, unlocked at ≥60% 共鸣)
                ├──→ Notebook (资料卡 + 故事碎片)
                └──→ Settings (设置)
                      ├──→ About (关于 + 开发者页面)                         │
                      └──→ Credits (感谢名单, 共鸣100%后解锁)
```

> **Current code vs design doc**: MainMenu currently uses `Album` naming for 断章. Settings button currently goes to Notebook, and About button goes to SettingMenu. These need rework to match the design.

### Data Storage

Currently implemented via `OS.get_user_data_dir()`.

```
OS.get_user_data_dir()/
    ├── CustomizedPlaylist/
    │   ├── xxx.lpz
    │   ├── yyy.lpz
    │   └── zzz.lpz
    ├── user.json        # User data
    └── config.json      # Game config
```

**user.json** (auto-created with defaults if missing):

```json
{
    "username": "小白",
    "main_line_unlocked": 13,        // count of unlocked 共鸣 songs
    "crystal": 250,                  // crystal currency
    "story_fragments_unlocked": [1, 3, 5]  // discovered fragment IDs
}
```

**config.json** (auto-created with defaults if missing):

```json
{
    "version": "0.0.0.1",
    "volume_song": 90,
    "volume_note": 70,
    "volume_ui": 60,
    "offset": 0,          // milliseconds, chart offset
    "speed": 10           // note scroll speed (1-20)
}
```

### Judging System

Per design doc — **4 timing windows** based on ms offset from ideal hit time:

| Range  | Judgment            | Single Accuracy (a) | Display Color |
| ------ | ------------------- | ------------------- | ------------- |
| ±60ms  | **Harmonious（和一）**  | 1.0                 | —             |
| ±120ms | **Sympathetic（共鸣）** | 0.7                 | —             |
| ±180ms | **Aware（觉醒）**       | 0.5                 | —             |
| ±240ms | **Lost（丢失）**        | 0.0                 | —             |

> **Current code conflict**: `Global.gd` only defines 3 boundaries (`SYMPATHY_TIME=60`, `SYNCED_TIME=120`, `CONNECTED_TIME=180`). Missing the 240ms Lost boundary and `END_JUDGE_TIME` should be ±240ms, not ±180ms.

**Accuracy formula** (per design doc):

```gdscript
# Initialize at game start
var acc: float = 1.0

# Update on each judgment (n = note index, 1-based)
acc = (acc * n + a) / (n + 1)
```

**Visual feedback**: Early hit → light blue ▲ above judgment line. Late hit → light red ▼ below.

### Rating System

| Grade      | acc Range    | Color                     |
| ---------- | ------------ | ------------------------- |
| ∞ Infinity | ≥ 0.95       | Gold (current saturation) |
| A          | [0.85, 0.95) | Orange                    |
| B          | [0.70, 0.85) | Yellow                    |
| C          | [0.50, 0.70) | Gray-blue                 |
| D          | < 0.50       | Gray                      |

### Note Types

| Name         | Code Name | Color   | Behavior                                                                                                               |
| ------------ | --------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| 蓝键 (Tap)     | `tap`     | #66CCFF | Requires precise tap                                                                                                   |
| 黄键 (Drag)    | `drag`    | #FFFF00 | Touch triggers hit                                                                                                     |
| 红键 (Release) | `release` | #FF0000 | Do NOT touch — touching = Lost                                                                                         |
| 心键 (Heart)   | `heart`   | #701010 | Like tap, but triggers special hit effect + ECG animation across background. Scrambles column mapping of next 4 notes. |
| 长键 (Hold)    | `hold`    | #90B070 | Head judgment like tap, must hold until end. No tail judgment.                                                         |

### Core Gameplay Pipeline

1. **Audio Sync** (design doc): Use `AudioStreamPlayer.get_playback_position()` as the **master clock**. Do NOT accumulate `_process(delta)` for timing — causes drift. Check note times against playback position each frame in `_process`. Offset compensation via `config.offset` parameter.

2. **Pause**: On pause (tap small cover art top-left), record `playback_position`. Resume from recorded position.

3. **NoteLoader** (`Script/Core/NoteLoader.gd`): Factory instantiating note scenes from `res://Scene/Core/NoteTemplate/` based on chart `type` string.

4. **InputProcesser** (`Script/Core/InputProcesser.gd`): **Design doc specifies touch-only input.** The current keyboard-based code (D/F/J/K) is a desktop placeholder. Track states: `is_pressed`, `is_held`, `is_released`, `is_clicked`.

5. **Note templates** (`Script/Core/NoteTemplate/`): Each extends `Sprite2D`. Note falls via `position.y += speed * delta`, enters judge area, calls `judge()` on hit, `explode()` for destruction.

### Track Design

- **Default**: 3D slanted rails (梯形 on screen), camera俯视角 adjustable.
- **Optional**: Straight rails (设置中选择), 4 tracks centered, total width = 2/5 ~ 1/2 of screen.
- Track贴图: pencil-sketch style matching the art direction.

### Color / Saturation Progression System

The entire game's color saturation is tied to 共鸣 progress. This is the core visual identity:

| Phase | Progress   | Saturation  | Fragments        | Psychological State          |
| ----- | ---------- | ----------- | ---------------- | ---------------------------- |
| 压抑    | 0% – 10%   | 0.80 – 0.85 | ~~1-2: 伊甸园, 萧墙~~ | Trapped, no escape           |
| 喘息    | 10% – 30%  | 0.85 – 0.70 | ~~3-4: 裂隙, 公交车~~ | Small freedoms               |
| 平静    | 30% – 55%  | 0.70 – 0.50 | ~~5-6: 面馆, 凝固~~  | Brief peace → trauma trigger |
| 崩溃    | 55% – 70%  | 0.50 – 0.70 | ~~7: 灼烧~~        | Pain, escape, burning        |
| 反思    | 70% – 85%  | 0.70 – 0.85 | ~~8: 阴虫~~        | Anger, accusation            |
| 蜕变    | 85% – 100% | 0.85 – 1.00 | ~~9-10: 蝶, 光与影~~ | Emergence, release, rebirth  |

**Key insight**: The saturation curve is U-shaped, not linear. Colors start muted → fade to grayscale at ~55% → recover to full color at 100%. The narrative's darkest moment (碎片 7) occurs while colors are recovering — this intentional mismatch is part of the artistic expression.

### Shader System

All `canvas_item` type:

| Shader                         | Purpose                                                                                                                                                                                              |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Shader/gray_scale.gdshader`   | Single `gray_scale` uniform (0–1), converts to grayscale by mixing luma with original. Used across all UI backgrounds.                                                                               |
| `Shader/dark_manager.gdshader` | Colored-pencil art style: Sobel 3×3 edge detection, paper color blending, FBM noise texture, edge fade vignette, saturation/brightness controls, plus `gray_scale`. Applied to gameplay backgrounds. |
| `Shader/paper.gdshader`        | Paper texture overlay from `paper_texture` uniform.                                                                                                                                                  |

**Dynamic shader params during gameplay**: 

```gdscript
# Per-frame update in Gameplay
shader.set_shader_param("saturation", song_progress)
shader.set_shader_param("line_strength", 1.0 - song_progress)
```

**Gameplay background progression** (per-song, not global):

- The per-song saturation change is **linear** with song progress: from 0.8 at start to nearly full color at end. No mid-song dip — unlike the global U-shaped curve.
- Start (0%): 0.8 saturation, light shader, slightly muted colors.
- End (100%): Nearly restored original colors, light paper texture remains.

For 共鸣 songs: play PV (`video.ogv` from .lpz) as background when available.

### .lpz Song Package Format

A `.lpz` file is a ZIP archive:

| File        | Required | Description                               |
| ----------- | -------- | ----------------------------------------- |
| `chart.lp`  | Yes      | JSON chart data                           |
| `audio.ogg` | Yes      | Song audio (.ogg format)                  |
| `cover.png` | Yes      | Album art (.png format)                   |
| `video.ogv` | No       | Background PV video. If absent, no error. |

**chart.lp structure**:

```json
{
    "General": {
        "Title": "title",
        "Producer": "...",
        "Vocalist": "...",
        "Creator": "...",
        //"Difficulty": "EZ",      // EZ / NM / HD
        "Version": "1.0",
        "BPM": 80
    },
    "HitObjects": [
        { "type": "tap", "time": 1000, "column": 1 },
        { "type": "drag", "time": 1000, "column": 2 },
        { "type": "release", "time": 1000, "column": 3 },
        { "type": "hold", "time": 1000, "column": 4, "duration": 1500 },
        { "type": "heart", "time": 1500, "column": 2, "map": [4, 2, 3, 1] }
    ]
}
```

> **Current code conflict**: Existing code reads `audio.wav` and `cover.png`. Design specifies `audio.ogg` and `cover.png`. Update Sympathy.gd audio reader from wav to ogg.

### Economic System

**Crystal（水晶）** — virtual currency:

> **⚠ 平衡性待调整**: 以下获取与消耗数值为策划案初版数据，需在实际测试后根据游戏节奏和玩家体验重新平衡。

- **Earning**: Based on acc after completing a song (formula per design doc page 20-21):
  - [0.00, 0.75): 10 crystals
  - [0.75, 0.91): `20 * acc - 4`
  - [0.91, 0.95): `40 * acc - 22`
  - [0.95, 1.00): `60 * acc - 41`
  - 1.00: 20 crystals
- **Daily login bonus**: 5 crystals (shown as popup on MainMenu)
- **Spending**: 15 per song unlock (共鸣), 6 for username change
- **Display**: Shown on MainMenu, song select, and results screens

### Story Fragments System

The "soul" of LuoPulse — a personal narrative about school bullying, broken family, and finding light in the cracks. Told through first-person diary entries.

**10 core fragments** (sequentially unlocked by 共鸣 progress):

| ID  | Title   | Progress Threshold | Source      |
| --- | ------- | ------------------ | ----------- |
| 1   | ~~伊甸园~~ | ~5%                | ~~《祸起萧墙》~~  |
| 2   | ~~萧墙~~  | ~10%               | ~~《祸起萧墙》~~  |
| 3   | ~~裂隙~~  | ~20%               | ~~《祸起萧墙》~~  |
| 4   | ~~公交车~~ | ~30%               | ~~《祸起萧墙》~~  |
| 5   | ~~面馆~~  | ~45%               | ~~《祸起萧墙》~~  |
| 6   | ~~凝固~~  | ~55%               | ~~《祸起萧墙》~~  |
| 7   | ~~灼烧~~  | ~70%               | ~~《祸起萧墙》~~  |
| 8   | ~~阴虫~~  | ~85%               | ~~《诗集·阴虫》~~ |
| 9   | ~~蝶~~   | ~95%               | ~~《诗集·蝶》~~  |
| 10  | ~~光与影~~ | 100%               | ~~终章~~      |

> The Title and the Source need further design. Now they are uncertain.

**Fragment JSON structure** (stored in `res://Data/story_fragments.json`):

```json
{
    "fragment_id": 1,
    "title": "伊甸园",
    "date": "23/2/22",
    "day_of_week": "周一",
    "weather": "阴",
    "content": "我的压力不来自于学习...",
    "trigger_progress": 0.05,
    "trigger_type": "progress"
}
```

**Trigger mechanism**:

- Progress-based: after completing a 共鸣 song, if progress crosses a fragment's threshold, unlock it.
- **Sequential only**: fragments unlock in ID order, even if multiple thresholds are crossed.
- Notification: slip-paper popup on FinishMenu: "发现了新的故事碎片 —— 「碎片标题」"
- Fallback: red dot on Notebook button in MainMenu if unread.

### Notebook Scene

Two tabs: **资料卡 (Cards)** + **故事碎片 (Fragments)**.

- Left sidebar: vertical index list. Unlocked items show titles; locked items show "???", grayed out, unclickable.
- Right panel: selected item content.
- Card data from `res://Data/song_cards.json`; fragment data from `res://Data/story_fragments.json`.
- Paper texture background with fold marks for fragments.
- When all fragments collected: blue-white butterfly knot mark on notebook cover.

### 共鸣 Song Chapters (Planned)

| Chapter     | Songs                      | Mood                                                          |
| ----------- | -------------------------- | ------------------------------------------------------------- |
| Ⅰ. 序曲 (2-3) | 心印, 镜的绮想, T.A.O.           | Gentle, bright — first impression before darkness             |
| Ⅱ. 暗涌 (3-4) | code:T Y712, 注入式, 黑鸟       | Turning dark, loneliness, hidden pain                         |
| Ⅲ. 挣扎 (3-4) | 那些我恐惧至极的事, 不老不死, 四重罪孽, 葬歌  | Most intense — resistance, self-doubt, inner struggle         |
| Ⅳ. 反思 (3-4) | 塔与少女的无题诗, 白鸟过河滩, 走马灯, 九重现实 | Slower, contemplative — reflection, understanding, acceptance |
| Ⅴ. 破晓 (2-3) | 昨日之声, 蝴蝶, 光与影的对白           | Release, hope, rebirth — world recovers color                 |

### Settings Page (Planned)

Categories per design doc:

- **Audio**: song volume, hit SFX volume, UI SFX volume, chart offset (±5ms), audio delay calibration (±1ms)
- **Game**: scroll speed (1-20 slider)
- **Appearance**: language (中文/English/日本語), UI saturation baseline (0.5-0.6)
- **Data**: reset 共鸣 progress (2nd confirm, keep crystals), reset all data (2nd confirm, requires typing username), export/import config

All settings save immediately to `config.json`.

### UI Design Principles

- **Text style**: Replace icon buttons with symbolic characters (`< 返回`, `@ 开始`, `& 关于`).
- **Click feedback**: Flash/blink effect on all UI.
- **Color saturation**: UI baseline 0.5-0.6 for harmony with color-changing system.
- **External text**: ALL UI strings in external JSON files keyed by dictionary for i18n.
- **Slip-paper popup**: Horizontally centered, slides in from top of screen. Styled as a small paper note being passed to the player. Used for fragment discovery notifications or other notifications in the game.
- **Touch**: Minimum touch area 48×48px. Each gameplay track touch area covers full track width. Touch latency ≤ 10ms.

### Miscellaneous Design Details

- **Pause**: Tap small cover art (top-left during gameplay) → pause menu with offset adjustment, speed adjustment, continue, retry, exit. Menu animation uses custom rate curve for smoothness.
- **Results screen**: Animated counters (0.3s interval), crystal count ticks up with glow, background uses曲绘 at completion shader state. "继续" button → Notebook资料卡, then back to song select.
- **Credits**: Scroll-up movie-style credits. Unlocked at 100% 共鸣 progress (hidden入口 on Launch page, or via About page). Ends with: "献给所有在黑暗中寻找光明的人."
- **彩蛋 (Easter eggs)**: Non-story — specific P主 B站 ID as username changes avatar; tap小白头像 100× on developer page for hidden photo. Story — see fragments system above.
- **Performance**: Target ≥ 100 FPS on mobile. Shader effects have fallback on low-end devices (reduce noise layers, lower paper texture resolution).

## Coding Conventions

From `README.md` — follow these strictly:

- **File naming**: Top-level folders PascalCase. Globally-loaded files and scenes PascalCase. All other files snake_case.
- **Node naming**: Root node name = scene file name. All nodes PascalCase. No default names.
- **Variables**: snake_case, typed with initial value: `var i: int = 0`
- **Booleans**: `is_` prefix: `var is_pressed: bool = false`
- **Constants**: `UPPER_SNAKE_CASE`
- **Functions**: snake_case, must declare return type. 2 blank lines between functions.
- **Scene references**: Group `@onready` vars at top. Prefer `@export var node_ref: NodeType = null` with inspector drag-and-drop.
- **Arrays/Dicts**: Spaces inside brackets: `[ 1, 2, 3 ]`, `{ "a": 1 }`. Multi-line gets trailing commas.
- **Long function calls**: Break parameters to separate lines, 4-space indent.
- **Blocks**: Every block (if/for/while/func) ends with `pass`.
- **Class names**: PascalCase via `class_name`.

## Key Known Conflicts: Code vs Design Doc

| Issue                  | Current Code                                     | Design Doc                                  | Action                            |
| ---------------------- | ------------------------------------------------ | ------------------------------------------- | --------------------------------- |
| Judging boundaries     | 3 levels, max ±180ms                             | 4 levels, max ±240ms                        | Update `Global.gd` constants      |
| Judging constant names | `SYMPATHY_TIME`, `SYNCED_TIME`, `CONNECTED_TIME` | Harmonious/Sympathetic/Aware/Lost           | Rename for clarity                |
| Lost boundary          | Uses `START_JUDGE_TIME=-180`                     | ±240ms                                      | Change to `-240`/`240`            |
| 断章 naming              | `Album` everywhere                               | `Side Line` / `断章`                          | Rename scenes, scripts, variables |
| Audio file in .lpz     | `audio.wav`                                      | `audio.ogg`                                 | Update `Sympathy.gd` readers      |
| Cover file in .lpz     | Already `cover.png`                              | `cover.png`                                 | No change needed                  |
| Audio clock            | `Time.get_ticks_msec()` based                    | `AudioStreamPlayer.get_playback_position()` | Rework `Gameplay.gd` timing       |
| Autoload name          | `Global.tscn`                                    | `GameData.tscn`                             | Rename when convenient            |
| Main menu buttons      | Wrong routing                                    | 共鸣/断章/笔记/设置                                 | Rework `MainMenu.gd`              |
| Input method           | Keyboard D/F/J/K                                 | Touch only                                  | Rewrite `InputProcesser.gd`       |

## Key Script Paths

| Purpose              | Path                                 |
| -------------------- | ------------------------------------ |
| Global state         | `Script/GameManager/Global.gd`       |
| Scene transitions    | `Script/GameManager/SceneManager.gd` |
| Note factory         | `Script/Core/NoteLoader.gd`          |
| Input handling       | `Script/Core/InputProcesser.gd`      |
| Gameplay loop        | `Script/Core/Gameplay.gd`            |
| Note base (Tap)      | `Script/Core/NoteTemplate/Tap.gd`    |
| Time tracker         | `Script/GameManager/TimeManager.gd`  |
| Launch / init        | `Script/Ui/Widget/Launch.gd`         |
| Sympathy song select | `Script/Ui/SongSelect/Sympathy.gd`   |
| Main menu            | `Script/Ui/Menu/MainMenu.gd`         |
| Notebook             | `Script/Ui/Menu/Notebook.gd`         |
| Finish/results       | `Script/Ui/Menu/FinishMenu.gd`       |
| Settings             | `Script/Ui/Menu/SettingMenu.gd`      |
| About                | `Script/Ui/Menu/AboutMenu.gd`        |
| Chart editor         | `Script/Creator/Editor.gd`           |
| Gray scale shader    | `Shader/gray_scale.gdshader`         |
| Pencil art shader    | `Shader/dark_manager.gdshader`       |
| Paper texture shader | `Shader/paper.gdshader`              |

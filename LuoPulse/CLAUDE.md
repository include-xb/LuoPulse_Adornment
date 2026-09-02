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

| Autoload     | Script                                    | Purpose                                                                                                                        |
| ------------ | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `Global`     | `Script/GameManager/Global.gd`            | Shared game state: user prefs, song lists, judging constants, game mode, combo/accuracy. Holds `NOTICE_BOX` for notifications. 通过 `Scene/GameManager/Global.tscn` 挂载为 autoload。 |
| `McpRuntime` | `addons/godot_mcp/runtime/mcp_runtime.gd` | Godot MCP runtime helper (project.godot 中的 autoload 名为 `McpRuntime`).                                                      |

> **SceneManager 不是 autoload**: `Script/GameManager/SceneManager.gd` / `Scene/GameManager/SceneManager.tscn` 是 **main_scene**(`run/main_scene`)。它管理场景转场(淡入淡出 0.25s),所有 UI 场景作为其子节点存在,通过 `$"..".start_scene_by_path(path)` / `$"..".back_to_previous_scene()` 切换(不再调用 `SceneManager.change_scene`)。启动时自动 `start_scene_by_path("res://Scene/Ui/Launch.tscn")`。

### Scene Flow

```
Launch ──→ MainMenu ──→ Sympathy (song select) ──→ Gameplay ──→ FinishMenu
				├──→ Album (断章, 当前代码命名, UI 显示「断章」)
				├──→ Notebook (资料卡 + 故事碎片)
				└──→ SettingsMenu (设置)
					  └──→ AboutMenu (关于;入口按钮「! 关于」已在 SettingsMenu 场景中, 尚未接线)
```

> **Current code**: MainMenu 四个按钮路由已正确 —— 共鸣→`Sympathy.tscn`、断章→`Album.tscn`、笔记→`Notebook.tscn`、设置→`SettingsMenu.tscn`。`AboutMenu.tscn` 场景存在,`! 关于` 按钮已放在 SettingsMenu 场景中,但尚未连接 `pressed` 信号(AboutMenu 脚本已实现返回/感谢逻辑)。Credits/感谢名单场景 `ThanksMenu.tscn` 尚不存在。

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
	"is_first_open": true,
	"main_line_unlocked": 1,         // count of unlocked 共鸣 songs
	"crystal": 100,                  // crystal currency
	"story_fragments_unlocked": []   // discovered fragment IDs
}
```

**config.json** (auto-created with defaults if missing):

```json
{
	"version": "0.0.0.1",
	"volume_song": 90,
	"volume_note": 70,
	"volume_ui": 60,
	"volume_bg": 60,
	"offset": 0,          // milliseconds, chart offset
	"speed": 10,          // note_flow_speed, 滑块范围 -20 ~ 20 (映射实际下落速度约 1 ~ 20)
	"if_play_start_animation": true
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

> **Code status**: `Global.gd` 已实现 4 档边界 —— `HARMONIOUS_TIME=60`, `SYMPATHETIC_TIME=120`, `AWARE_TIME=180`, `LOST_TIME=240`;判定窗 `START_JUDGE_TIME=-240` / `END_JUDGE_TIME=240`,与上表一致。

**Accuracy formula** (代码实现, `NoteBase._update_accuracy`):

```gdscript
# 游戏开始时 (Global.gd)
Global.accuracy     = 0.0
Global.total_judged = 0

# 每次判定后 (NoteBase._update_accuracy)
Global.total_judged += 1
var n: int = Global.total_judged
Global.accuracy = (Global.accuracy * float(n - 1) + a) / float(n)   # 等价于纯平均 (a₁+…+a_N)/N
```

> 即所有已判定音符准度的算术平均 (lost 记 `a=0` 自然拉低)。全 Perfect → 1.0。注:设计文档公式 (初始 acc=1.0, `(acc*n+a)/(n+1)`) 会使满分永远不可达 (恒为 N/(N+1)), 已弃用, 以代码为准。

**Visual feedback**: 早击/晚击用 `▲ EARLY` / `▼ LATE` 文字(早击在判定线上方上浮, 晚击在下方下沉), 颜色取判定等级色 (`JUDGMENT_COLORS`: 和一绿/共鸣蓝/觉醒金/丢失灰)。`EARLY_COLOR`/`LATE_COLOR` 常量已定义但未使用。

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

4. **InputProcesser** (`Script/Core/InputProcesser.gd`): 每根轨道 (Column 节点) 挂载一个实例, 处理该轨道的触屏/按键判定。触屏输入已在 `Gameplay._input` 实现 (根据屏幕 X 映射到轨道列, 支持多点触控); 键盘 D/F/J/K 保留为桌面调试输入。轨道按下/松开触发 `press_judge` / hold 释放逻辑, 附带轨道高亮 shader 反馈。

5. **Note templates** (`Script/Core/NoteTemplate/`, 场景在 `Scene/Core/NoteTemplate/`): 音符为 3D 轨道内的 `MeshInstance3D` (`NoteBase`), 通过 `position.z = note_speed * (master_time - time) / 1000` 定位下落 (到达判定线时 z=0)。进入判定窗时注册到 `Global.judging_area`, 命中调用 `judge()`, 未中 `_lose()`, `explode()` 播放粒子后销毁。

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

> **Code status**: 读取逻辑在 `Global._read_lpz` / `_read_audio_from_lpz`(读 `audio.ogg`, `AudioStreamOggVorbis.load_from_buffer`), 封面读 `cover.png`, 视频读 `video.ogv`。与上表一致。

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

## Key Known Conflicts: Code vs Design Doc (以代码为准)

> 多数冲突已在代码中解决。下表记录各项**现状** —— 已实现行标 ✅,仍与设计文档有差异的行注明"以代码为准保留"。

| Issue               | 现状 (以代码为准)                                                    |
| ------------------- | --------------------------------------------------------------------- |
| Judging boundaries  | ✅ 已实现 4 档, max ±240ms                                           |
| Judging constant names | ✅ `HARMONIOUS_TIME` / `SYMPATHETIC_TIME` / `AWARE_TIME` / `LOST_TIME` |
| Lost boundary       | ✅ `START_JUDGE_TIME` / `END_JUDGE_TIME` = ±240                        |
| 断章命名             | 代码保留 `Album` (场景/脚本/变量); UI 显示「断章」                        |
| Audio in .lpz       | ✅ 已读 `audio.ogg` (`AudioStreamOggVorbis.load_from_buffer`)           |
| Cover in .lpz       | ✅ `cover.png`                                                         |
| Audio clock         | ✅ 音频启动后以 `playback_position` 为主时钟 (非音频预载段用 tick)         |
| Autoload 名          | 保留 `Global.tscn` (未改 GameData)                                     |
| 主菜单按钮           | ✅ 路由正确 (共鸣→Sympathy / 断章→Album / 笔记→Notebook / 设置→SettingsMenu) |
| Input               | ✅ 触屏已实现, 键盘 D/F/J/K 保留为桌面调试                               |

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
| Settings             | `Script/Ui/Menu/SettingsMenu.gd`     |
| About                | `Script/Ui/Menu/AboutMenu.gd`        |
| Chart editor         | `Script/Creator/Editor.gd`           |
| Gray scale shader    | `Shader/gray_scale.gdshader`         |
| Pencil art shader    | `Shader/dark_manager.gdshader`       |
| Paper texture shader | `Shader/paper.gdshader`              |

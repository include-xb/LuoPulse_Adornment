![1714709371529](https://github.com/include-xb/LuoPulse_Adornment/blob/main/ReadmeAssets/1714709371529.jpg)

---

\| **简体中文** | **[English](README_en.md)** |

# Luo Pulse: Adornment 🩺

> 机械的心率带动血肉的共鸣        —— COPY《为了你唱下去》
> 
> 艺术家与 ta 们的爱万岁！              —— 雨狸《塔与少女的无题诗》

洛之动脉：缤纷繁饰（Luo Pulse: Adornment）是一款中文虚拟歌手同人、非商业音乐游戏。

## 游戏主题 🎞️

我们希望在一定程度上弥补中文V家在游戏方面的缺失，希望有更多人能够看到我们的游戏，了解中V文化。

同时，我们也希望了解虚拟歌手但不太了解P主的小伙伴们能够更加深入的了解中文V家。在我们看来，P主以及歌曲的创作背景，和虚拟歌手本身同等重要。

为此，洛之动脉将会更多的运用“叙述”的方法，讲述中文V家的故事。

## 收录曲目 🎹

- 注：以下是开发过程中使用的歌曲，游戏最终收录曲目会有较大变动。

| 歌曲名称                                                                                              | P主                                                                                  | 歌手                                                   | 发布时间（bilibili） | 是否获得授权（25.07.28） |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------- | -------------- | ---------------- |
| [最初日](https://www.bilibili.com/video/BV1RB4y1i7Qv/?vd_source=dfcfa9860eb55a98f868b5b13704612f)    | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2022-07-10     | ✔️               |
| [绝体绝命](https://www.bilibili.com/video/BV1HW411T741/?vd_source=dfcfa9860eb55a98f868b5b13704612f)   | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2018-04-04     | ✔️               |
| [为了你唱下去](https://www.bilibili.com/video/BV1ts411y7FY/?vd_source=dfcfa9860eb55a98f868b5b13704612f) | [COPY](https://space.bilibili.com/396194)                                           | [洛天依](https://space.bilibili.com/36081646)           | 2016-07-12     | ✔️               |
| [春风来](https://www.bilibili.com/video/BV1vx411h7dV/?vd_source=dfcfa9860eb55a98f868b5b13704612f)    | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2017-06-21     | ✔️               |
| [四重罪孽](https://www.bilibili.com/video/BV1us411X7hb/?vd_source=dfcfa9860eb55a98f868b5b13704612f)   | [DELA](https://space.bilibili.com/358606) & [雨狸](https://space.bilibili.com/605473) | [洛天依]() & [言和](https://space.bilibili.com/406948276) | 2016-03-26     | ✔️               |

## 游戏部分 🎮

洛之动脉的曲包格式如下：

```bash
title.lpz    # .zip
    ├────── chart.lp    # .json
    ├────── audio.ogg    # 后续可能更改音频文件类型
    ├────── cover.png
    └────── video.ogv    # 非必须
```

谱面文件格式如下：

```javascript
{
    "General": {
        "Title": "title",        // title, 不要求与曲包文件同名
        "Artist": "...",         // P主 (选歌界面显示在"作词/作曲/编曲"一栏)
        "Vocalist": "...",       // 歌手
        "Creator": "...",        // 谱师
        "Chapter": 1,            // 章节编号 1 ~ 5, 选歌界面显示为 "ChapterⅠ. 序曲" 等
        "BPM": 80,
        "Preview": 3000,        // 预览时从 3000ms 位置开始播放
        "PreviewEnd": 10000,    // 预览至 10000ms 位置结束 (缺省或 -1 表示播到曲尾)
        "Crystal": 40,           // 解锁该曲包需要的水晶数量 (缺省 10)
        "Difficulty": "EZ",        // 难度: EZ (简单), NM (普通), HD (困难), 暂未使用
        "Version": "1.0"        // 暂未使用
    },
    "HitObjects": [
        {
            "type": "tap",        // tap (蓝键)
            "time": 1000,        // 毫秒, 音符到达判定线的时间
            "column": 1            // 轨道编号 1 ~ 4
        },
        {
            "type": "drag",        // drag (黄键)
            "time": 1000,
            "column": 2
        },
        {
            "type": "release",     // release (红键: 按住本轨, 在判定线处松手)
            "time": 1000,
            "column": 3
        },
        {
            "type": "hold",        // hold (长条)
            "time": 1000,
            "column": 4,
            "duration": 1500     // 毫秒, 长条持续时间
        },
        {
            "type": "heart",       // heart (心键: 判定同 tap, 与 Effects 里的 heart 效果无关)
            "time": 1500,
            "column": 2
        }
    ],
    "Effects": [                // 可选, 缺省表示没有谱面效果
        {
            "type": "change",     // change: 轨道换位, duration 到期后复原
            "time": 3000,        // 毫秒, 效果开始时刻 (相对歌曲开头)
            "duration": 4000,    // 毫秒, 效果持续时间
            "changed": [ 2, 3, 4, 1 ]    // 1 ~ 轨道数的排列 (长度须等于轨道数): changed[槽位] = 轨道号 (从 1 开始)
        },
        {
            "type": "heart",      // heart: change 的超集, 另收紧判定窗口并淡入心电图与屏幕边缘血色光晕
            "time": 5000,
            "duration": 3000,
            "changed": [ 3, 4, 1, 2 ]    // 传 [ 1, 2, 3, 4 ] 即只收紧判定 + 视觉, 不换位
        }
    ]
}
```

谱面效果（`Effects` 段，与 `HitObjects` 并列）：

- `change`：把整根轨道沿 x 挪到别的槽位，`duration` 到期后复原。
- `heart`：`change` 的超集 —— 换位之外，还会收紧判定窗口，并淡入心电图与屏幕边缘的血色光晕；两者的反馈由玩家的命中 / 漏键驱动。

用户数据格式如下：

```javascript
{
	"username": "源来是小白",        // 用户名
	"is_first_open": true,          // 首次打开标记
	"main_line_unlocked": 1,        // 已经解锁的主线曲目数量
	"crystal": 25,                   // 水晶数量
	"story_fragments_unlocked": [    // 已经解锁的故事碎片 id
		"1",
		"3"
	],
	"avatar_index": 0                // 当前选用的头像序号
}
```

游戏配置数据格式如下：

```javascript
{
	"if_play_start_animation": true,    // 是否播放开始动画
	"is_auto_update_package": true,     // 启动时是否自动更新曲包
	"offset": 0,                        // 谱面偏移量 (毫秒, -200 ~ 200)
	"speed": 10,                        // 音符流速 (-20 ~ 20)
	"version": "0.0.0.1",               // 版本号
	"volume_bg": 60,                    // 背景音乐音量
	"volume_note": 70,                  // 音符打击音量
	"volume_song": 70,                  // 歌曲音量
	"volume_ui": 60                     // UI 音量
}
```

## 讨论 📅

填写此[问卷](https://www.wjx.top/vm/wpPPzRs.aspx)，添加至游戏感谢名单。

玩家 QQ 交流群：`638522101`

### 游戏曲目投稿 📄📌

请使用[洛之动脉谱面编辑器](https://github.com/Thirhythm/LPEditor)。创作完成后，你可以通过以下途径向我们投稿：

- 将曲包发送至邮箱 1330625393@qq.com

- 联系源来是小白，直接向我发送。后文提供了联系方式。

### 支持我们 💌

如果你喜欢我们的项目，请为我们点击`star`⭐

bilibili 关注开发者：

- [源来是小白](https://space.bilibili.com/1640232445) 
- [拾三律](https://space.bilibili.com/1913343200)

## 参与开发 🖥️

### 克隆仓库 🗂️

```bash
git clone https://github.com/include-xb/LuoPulse_Adornment.git
cd LuoPulse_Adornment
```

### 下载 Godot 引擎⚙️

注意引擎版本 4.7

[Godot 官网](https://godotengine.org/)

[Godot4.7 下载页面](https://godotengine.org/download/windows/)

### 更多问题

如果你对洛之动脉还有其他疑问，欢迎联系：[源来是小白](https://space.bilibili.com/1640232445)

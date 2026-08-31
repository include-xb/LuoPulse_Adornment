![1714709371529](https://github.com/include-xb/LuoPulse_from_git/blob/main/ReadmeAssets/1714709371529.jpg)

---

\| **简体中文** | **[English](README_en.md)** |

# Luo Pulse 🩺

> 机械的心率带动血肉的共鸣        —— COPY《为了你唱下去》
> 
> 艺术家与 ta 们的爱万岁！              —— 雨狸《塔与少女的无题诗》

洛之动脉（Luo Pulse）是一款中文虚拟歌手同人、非商业音乐游戏。



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
        "Producer": "...",
        "Vocalist": "...",
        "Creator": "...",
        "Difficulty": "EZ",        // 难度: EZ (简单), NM (普通), HD (困难)
        "Version": "1.0",        // 暂时可忽略
        "BPM": 80,
        "Preview": 3000        // 预览时从 3000ms 位置开始播放
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
            "type": "release",     // release (红键)
            "time": 1000,
            "column": 3
        },
        {
            "type": "hold",        // hold (长条)
            "time": 1000,
            "column": 4,
            "duration": 1500     // 毫秒, 长条持续时间
        }
    ]
}
```

谱面效果：

> 未实现

## 讨论 📅

填写此[问卷](https://www.wjx.top/vm/wpPPzRs.aspx)，添加至游戏感谢名单。

玩家 QQ 交流群：`638522101`

### 游戏曲目投稿 📄📌

> 暂未开放

### 支持我们 💌

如果你喜欢我们的项目，请为我们点击`star`

bilibili 关注开发者：

- [源来是小白](https://space.bilibili.com/1640232445) 
- [拾三律](https://space.bilibili.com/1913343200)

## 参与开发 🖥️

### 克隆仓库 🗂️

```bash
git clone https://github.com/include-xb/LuoPulse_from_git.git
cd LuoPulse_from_git
```

### 下载 Godot 引擎⚙️

注意引擎版本 4.7

[Godot 官网](https://godotengine.org/)

[Godot4.7 下载页面](https://godotengine.org/download/windows/)

### 更多问题

如果你对洛之动脉还有其他疑问，欢迎联系：[源来是小白](https://space.bilibili.com/1640232445)

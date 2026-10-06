![1714709371529](https://github.com/include-xb/LuoPulse_Adornment/blob/main/ReadmeAssets/1714709371529.jpg)

---

\| **[简体中文](README.md)** | **English** |

# Luo Pulse: Adornment 洛之动脉：缤纷繁饰 🩺

> 机械的心率带动血肉的共鸣        —— COPY《为了你唱下去》
> 
> Steel pulse ignites the beat. Flesh and blood answers the heat.
> 
> 艺术家与 ta 们的爱万岁!              —— 雨狸《塔与少女的无题诗》
> 
> Viva los artistas y su amor!

**Luo Pulse: Adornment** is a fan-made, non-commercial rhythm game of Chinese virtual singers.

## Theme 🎞️

We aim to fill the gap in the games themed around Chinese virtual singers. Furthermore, we hope more people could see our game and learn about the culture of Vocaloid China (VC).

Meanwhile, we also hope that friends who are familiar with virtual singers but not very familiar with Vocaloid Producers, can have a deeper understanding of VC. In our opinion, producers and the background of the song are of equal importance to virtual singers themselves.

For this reason, Luo Pulse will use more "narrative" methods to tell the stories of VC.

## Tracklist 🎹

*(This list of songs below are used during developing and testing. Final tracks subject to change)*

| Title                                                                                             | Producer                                                                            | Vocalist(s)                                          | Release date (bilibili) | Authorization Status (25.07.28) |
| ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------- | ----------------------- | ------------------------------- |
| [最初日](https://www.bilibili.com/video/BV1RB4y1i7Qv/?vd_source=dfcfa9860eb55a98f868b5b13704612f)    | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2022-07-10              | ✔️                              |
| [绝体绝命](https://www.bilibili.com/video/BV1HW411T741/?vd_source=dfcfa9860eb55a98f868b5b13704612f)   | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2018-04-04              | ✔️                              |
| [为了你唱下去](https://www.bilibili.com/video/BV1ts411y7FY/?vd_source=dfcfa9860eb55a98f868b5b13704612f) | [COPY](https://space.bilibili.com/396194)                                           | [洛天依](https://space.bilibili.com/36081646)           | 2016-07-12              | ✔️                              |
| [春风来](https://www.bilibili.com/video/BV1vx411h7dV/?vd_source=dfcfa9860eb55a98f868b5b13704612f)    | [阿良良木健](https://space.bilibili.com/112428)                                          | [洛天依](https://space.bilibili.com/36081646)           | 2017-06-21              | ✔️                              |
| [四重罪孽](https://www.bilibili.com/video/BV1us411X7hb/?vd_source=dfcfa9860eb55a98f868b5b13704612f)   | [DELA](https://space.bilibili.com/358606) & [雨狸](https://space.bilibili.com/605473) | [洛天依]() & [言和](https://space.bilibili.com/406948276) | 2016-03-26              | ✔️                              |

## Gameplay Section 🎮

The song package format for Luo Pulse is as follows:

```bash
title.lpz    # .zip
    ├────── chart.lp    # .json
    ├────── audio.ogg    # (format may change)
    ├────── cover.png
    └────── video.ogv    # not a must
```

The chart file format is structured as follows:

```javascript
{
    "General": {
        "Title": "title",        // the title need NOT match song package filename
        "Producer": "...",
        "Vocalist": "...",
        "Creator": "...",
        "Difficulty": "EZ",        // difficulty: EZ(easy), NM(normal), HD(hard)
        "Version": "1.0",        // currently unused
        "BPM": 80,
        "Preview": 3000,        // play at 3000ms when previewing
        "PreviewEnd": 10000,    // ended at 10000ms when previewing
        "Crystal": 40            // crystal number needed to unlock the song
    },
    "HitObjects": [
        {
            "type": "tap",        // tap (blue key)
            "time": 1000,        // time that note should spend arriving line (msec)
            "column": 1            // column 1 ~ 4
        },
        {
            "type": "drag",        // drag (yellow key)
            "time": 1000,
            "column": 2
        },
        {
            "type": "release",    // release (red key: hold the track, release at the judgment line)
            "time": 1000,
            "column": 3
        },
        {
            "type": "hold",        // hold (long press)
            "time": 1000,
            "column": 4,
            "duration": 1500    // duration of the hold (msec)
        }
    ]
}
```

Chart effects:

> Not implemented yet.

The user's data is structured as follows:

```javascript
{
    "crystal": 25,            // crystals
    "main_line_unlocked": 1,  // number of unlocked mainline songs
    "story_fragments_unlocked": [    // ids of unlocked fragments
        "1",
        "3"
    ],
    "username": "源来是小白"    // username
}
```

The game config file is structured as follows:

```javascript
{
    "if_play_start_animation": true,
    "offset": 0,                        // offset of the chart
    "speed": 15,                        // speed of note
    "version": "0.0.0.1",
    "volume_bg": 60,                    // volume of background music
    "volume_note": 55,                  // volume of the note that is hit
    "volume_song": 65,                  // volume of the song
    "volume_ui": 60                     // volume of UI
}
```

## Discussion 📅

[Complete questionnaire ](https://www.wjx.top/vm/wpPPzRs.aspx)to join credits.

Player QQ group:`638522101`

### Package submissions 📄📌

Please use [Editor of LuoPulse](https://github.com/Thirhythm/LPEditor). Once your chart is finished, you can submit it in the following ways: 

- Email the package to 1330625393@qq.com

- Contact 源来是小白, send to me directly. The way to contact me is below.

### Support 💌

If you like our project, give us a ⭐ on GitHub!

Follow developers on Bilibili:

- [源来是小白](https://space.bilibili.com/1640232445) 
- [拾三律](https://space.bilibili.com/1913343200)

## Development 🖥️

### Clone the repository 🗂️

```bash
git clone https://github.com/include-xb/LuoPulse_from_git.git
cd LuoPulse_from_git
```

### Download Godot Engine⚙️

Pay attention that the version of Godot is 4.7.

[Godot Official Website](https://godotengine.org/)

[Godot 4.7 Download Page](https://godotengine.org/download/windows/)

### Further inquiries

If you have any other questions about Luo Pulse, please feel free to contact: [源来是小白](https://space.bilibili.com/1640232445) 

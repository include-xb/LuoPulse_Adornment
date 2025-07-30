

# 洛之动脉 开发规范

## 结构

- 可参考已创建的文件结构.

```bash
LuoPulse/
	├── Asset/		# 静态资源
	│	├── Audio/	# 音频资源（.mp3格式）
	│	├── Font/	# 字体文件（.ttf格式）
	│	├── Icon/	# SVG图标资源
	│	└── Image/	# 图片素材（.jpg格式）
	│
	├── Scene/		# 游戏场景
	│   ├── Core/		# 核心游戏组件
	│   │   ├── EffectTemplate/	# 特效模板场景
	│   │   ├── NoteTemplate/	# 音符类型模板
	│   │   │   ├── Tap.tscn	# 点击音符
	│   │   │   ├── Drag.tscn	# 拖拽音符
	│   │   │   ├── Release.tscn 	# 释放音符
	│   │   │   ├── Hold.tscn		# 长按音符
	│   │   │   └── Heart.tscn		# 特殊心跳音符
	│   │   │
	│   │   ├── GameProgress.tscn	# 游戏进程控制
	│   │   ├── InputProgress.tscn	# 输入处理
	│   │   └── NoteLoader.tscn		# 音符加载器
	│   │
	│   ├── GameManager/	# 游戏管理系统
	│   │   ├── Global.tscn			# 全局管理器
	│   │   └── SceneManager.tscn	# 场景切换
	│   │
	│   └── UI/		# 用户界面
	│       ├── Menu/
	│       │   ├── MainMenu.tscn		# 游戏主页面
	│       │   ├── SettingMenu.tscn	# 设置菜单
	│       │   └── AboutMenu.tscn		# 关于页面
	│       │
	│       ├── SongSelect/     # 选曲界面
	│       │   ├── Album.tscn  # 专辑主线
	│       │   └── Sympathy.tscn # 共鸣主线
	│       │
	│       └── Launch.tscn     # 启动加载界面
	│	
	├── Script/		# 游戏脚本
	│   ├── Core/	# 核心游戏逻辑
	│   │   ├── NoteTemplate/  # 音符行为脚本
	│   │   │   ├── Tap.gd     # 点击逻辑
	│   │   │   ├── Drag.gd    # 拖拽逻辑
	│   │   │   ├── Release.gd # 释放逻辑
	│   │   │   ├── Hold.gd    # 长按逻辑
	│   │   │   └── Heart.gd   # 心跳逻辑
	│   │   │
	│   │   ├── GameProgress.gd  # 游戏进程控制
	│   │   ├── InputProgress.gd  # 输入处理
	│   │   └── NoteLoader.gd    # 音符加载
	│   │
	│   ├── GameManager/	# 管理类脚本
	│   │   ├── Global.gd	# 全局状态管理
	│   │   └── SceneManager.gd # 场景加载
	│   │
	│   └── UI/	# 界面逻辑
	│       ├── Menu/          
	│       │   ├── MainMenu.gd    # 游戏主页面
	│       │   ├── SettingMenu.gd # 设置
	│       │   └── AboutMenu.gd   # 关于页面
	│       │
	│       ├── SongSelect/     
	│       │   ├── Album.gd	# 专辑主线
	│       │   └── Sympathy.gd # 共鸣主线
	│       │
	│       └── Launch.gd		# 启动界面控制
	│
	├── Shader/		# 着色器文件
	│   └── （*.shader）	# 自定义着色器
	│
	└── Theme/		# 界面主题
		└── （*.tres）		# 主题资源文件
```


​    

## 文件

1. `res://`目录下文件夹使用大驼峰命名法.
2. 全局加载的文件使用大驼峰命名法. 场景文件使用大驼峰命名法. 其余所有文件采用蛇形命名法.

## 节点

1. 节点根节点名称与文件名相同.
1. 场景的所有节点使用大驼峰命名法.
2. 尽量规避默认名称 ( Node2D, AnimationPlayer2D... )

## 代码

1. 变量名采用蛇形命名法, 初始化时需指定类型, 并赋初始值. 

    ```javascript
    var i: int = 0
    var f: float = 0.0
    var s: String = ""
    var a: Array = [ ]
    var d: Dictionary = { }
    ```
    
    
    
2. 数组和字典带初始值初始化时, 中括号或大括号内添加空格.

    ``` javascript
    var my_array: Array = [ 1, 2, 3 ]
    var my_dict: Dictionary = { "a": 1, "b": 2, "c": 3 }
    ```
    
    
    
3. 数组或字典中存在多行元素时, 每行后添加逗号.

    ```javascript
    var my_array: Array = [
        1,
        2,
        3,
    ]
    var my_dict: Dictionary = {
        "a": 1,
        "b": 2,
        "c": 3,
    }
    ```

    

2. `bool`型的变量采用`is_...`命名. 

    ```javascript
    var is_killing: bool = false
    var is_killed: bool = false
    ```
    
    
    
3. 一切从场景引用的变量都在代码开头定义. 

    ```javascript
    @onready var display_info: AnimaitonPlayer = $"aisplay_info"
    ```

	
	
	- 为了使节点相对位置变动后不修改代码的引用, 可以使用如下方法: 
	
	    ```javascript
	    @export var display_info: AnimaitonPlayer = null
	    ```
	
	    然后再检查器中将`$AnimationPlayer`节点拖入.



4. 常量全部大写, 使用下划线分隔单词.

    ```javascript
    const GRAVITY = 9.8
    const MAX_SPEED = 200
    ```

    


5. 定义类名使用大驼峰.

    ```javascript
    class_name MyClass
    ```

    

6. 自定义的函数名使用蛇形命名法. 函数需指定返回值类型. 函数与其他代码之间空`2`行

    ```javascript
    func _ready() -> void:
    	pass
    
    
    func my_function(i: int) -> void:
    	print(i)
    	pass
    ```

    

6. 所有代码缩进使用`pass`包裹

    ```javascript
    for i in range(count):
    	print(i)
    	if i == 1:
    		print("i = 1")
    		pass
    	pass
    ```

    

7. 若函数中的参数过长, 则采用以下写法: 

	```javascript
	var tween = create_tween()
	tween.tween_property(
    	sprite, 
    	"position", 
    	Vector2(200, 200), 
    	1.0
	)
	```



待补充...

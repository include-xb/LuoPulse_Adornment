

# 洛之动脉 开发规范

## 结构

- 可参考已创建的文件结构.

    ```bash
    LuoPulse/
    	├─ Asset/
    	|	├─ Audio/
    	|	|	└─ *.mp3
    	|	├─ Font/
    	|	|	└─ *.ttf
    	|	├─ Icon/
    	|	|	└─ *.svg
    	|	└─ Image/
    	|		└─ *.jpg
    	├─ Scene/
    	|	├─ Core/
    	|	|	├─ EffectTemplate/
    	|	|	|	└─ *.tscn
    	|	|	├─ NoteTemplate/
    	|	|	|	├─ Tap.tscn
    	|	|	|	├─ Drag.tscn
    	|	|	|	├─ Release.tscn
    	|	|	|	├─ Hold.tscn
    	|	|	|	└─ Heart.tscn
    	|	|	├─ GameProgress.tscn
    	|	|	├─ InputProgress.tscn
    	|	|	├─ NoteLoader.tscn
    	|	|	└─ *.tscn
    	|	├─ GameManager/
    	|	|	├─ Global.tscn
    	|	|	├─ SceneManager.tscn
    	|	|	├─ TimeManager.tscn
    	|	|	└─ *.tscn
    	|	└─ Ui/
    	|		├─ Menu/
    	|		|	├─ AboutMenu.tscn
    	|		|	├─ MainMenu.tscn
    	|		|	├─ SettingMenu.tscn
    	|		|	└─ *.tscn
    	|		├─ SongSelect/
    	|		|	├─ Album.tscn
    	|		|	└─ Sympathy.tscn
    	|		├─ Launch.tscn
    	|		└─ *.tscn
    	├─ Script/
    	|	├─ Core/
    	|	|	├─ EffectTemplate/
    	|	|	|	└─ *.gd
    	|	|	├─ NoteTemplate/
    	|	|	|	├─ Tap.gd
    	|	|	|	├─ Drag.gd
    	|	|	|	├─ Release.gd
    	|	|	|	├─ Hold.gd
    	|	|	|	└─ Heart.gd
    	|	|	├─ GameProgress.gd
    	|	|	├─ InputProgress.gd
    	|	|	├─ NoteLoader.gd
    	|	|	└─ *.gd
    	|	├─ GameManager/
    	|	|	├─ Global.gd
    	|	|	├─ SceneManager.gd
    	|	|	├─ TimeManager.gd
    	|	|	└─ *.gd
    	|	└─ Ui/
    	|		├─ Menu/
    	|		|	├─ AboutMenu.gd
    	|		|	├─ MainMenu.gd
    	|		|	├─ SettingMenu.gd
    	|		|	└─ *.gd
    	|		├─ SongSelect/
    	|		|	├─ Album.gd
    	|		|	└─ Sympathy.gd
    	|		├─ Launch.gd
    	|		└─ *.gd
    	├─ Shader/
    	|	└─ *.shader
    	└─ Theme/
    		└─ *.tres
    ```
    
    

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

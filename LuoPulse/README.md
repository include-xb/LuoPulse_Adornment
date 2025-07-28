

# 洛之动脉 开发规范

## 项目结构

- 项目结构参考已创建的文件结构.

## 文件命名

- `res://`目录下文件夹首字母大写, 其子目录全小写.

- 全局加载的文件使用大驼峰命名法. 其余所有文件采用蛇形命名法.

## 代码

1. 变量名采用蛇形命名法, 初始化时需指定类型, 并赋初始值. 

    ```javascript
    var i: int = 0
    
    var f: float = 0.0
    
    var s: String = ""
    
    var a: Array = [ ]
    
    var d: Dictionary = { }
    ```

    

2. `bool`型的变量采用`is_...`命名. 

    ```javascript
    var is_killing: bool = false
    
    var is_killed: bool = false
    ```

    

3. 一切从场景引用的变量都在代码开头定义. 

    ```javascript
    @onready var animation_player: AnimationPlayer = $"AnimationPlayer"
    ```

    

4. 定义类名使用大驼峰.

    ```javascript
    class_name MyClass
    ```

    

5. 自定义的函数名使用小驼峰命名法. 函数需指定返回值类型. 函数与其他代码之间空`2`行

    ```javascript
    func _ready() -> void:
    	pass
    
    
    func myFunction(i: int) -> void:
    	print(i)
    	pass
    ```

    

6. 代码缩进使用`pass`包裹

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

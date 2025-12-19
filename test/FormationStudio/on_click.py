from formation import AppBuilder

def on_click(event):
    print("Button clicked!") #点击按钮后的操作


app = AppBuilder(path="hello.xml")  #加载界面文件
app.connect_callbacks(globals())    #绑定按钮事件到函数

app.mainloop()  #启动应用程序主循环
Output demo.gif

Set FontSize 16
Set Width 1000
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set Padding 16

# 真实运行回放：在技能根目录执行 `vhs assets/demo.tape` 录制。
# 内容 = 冒烟测试实跑（全 PASS 过程），不做摆拍。
Type 'Rscript scripts/smoke-cjk.R'
Enter
Wait @2s
Sleep 3s

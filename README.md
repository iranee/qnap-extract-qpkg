## qnap-extract-qpkg
这是一个用于解压缩QPKG文件安装包的工具
* 优化部分命令


## 旧版用法
extract_qpkg.sh package.qpkg [destdir]

* package.qpkg 为正常的qnap插件安装包
* destdir 为解压缩后存储的路径，空置则为同名package

## 新版命令用法
./extract_new_qdk.sh extract `foldername` `pkgname`
* extract（解压缩包命令），foldername（解包到的文件夹名称或路径），pkgname（qpkg文件名）
* 例如./extract_new_qdk.sh extract `alist` `alist_3.28.0_x86_64.qpkg`

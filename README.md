# METALを使用した描画プログラム

MACOS上でMETALフレームワークを使用して描画するテストです。

Objective-Cを使用していますが、アプリケーション本体はC++に繋いでいます。

## ビルド

C++20でコンパイルしています。
2004/4の時点ではCommandLineToolsのclang(15.0)ではビルドできません。
homebrewのLLVMを使用してください。

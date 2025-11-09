---
noteId: "8f0f9d82-d2b4-4b08-85a3-9a86175a5c71"
title: "GhostscriptでPDFサイズを圧縮する"
description: "Windows環境でGhostscriptを使ってPDFサイズを圧縮を試した内容"
date: 2018-05-06
tags: ["PDF", "Ghostscript", "Windows"]
---

## 圧縮
* diff-pdfの結果のPDFがでかい！
* サイズを小さくしたい

https://gist.github.com/firstdoit/6390547

Ghostscriptでできる？

```
gswin64c.exe  -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/printer -dNOPAUSE -dQUIET -dBATCH -sOutputFile=diff-output.pdf diff.pdf
```

* これでできた！
* 50.36MBが19.59MBになった

> This can reduce files to ~15% of their size (2.3M to 345K, in one case) with no obvious degradation of quality.

* と書かれているように、パッと見た目にも劣化はわからない


# fcitx5-table-hotkeys — fcitx5 码表输入法快捷键增强

为 fcitx5 的码表输入法(五笔等)增加搜狗五笔风格的快捷键: **调词序**、**一键删词**,并将原版**造词**快捷键改为 `Ctrl+Shift+Z`。

> 本目录包含对 fcitx5 与 libime 的**源码级修改**,不是纯外挂插件——我们修改了上游源码以暴露最小接口,再由一个独立 addon 模块消费这些接口。

---

## 一、为什么需要修改源码(修改原因)

fcitx5-table 原版只有两个词典操作快捷键:

| 原版快捷键 | 功能 | 交互方式 |
|---|---|---|
| `Ctrl+8` (ModifyDictionaryKey) | 造词 | 进入模式 → 左右选词组长度 → 空格确认 |
| `Ctrl+7` (ForgetWord) | 删词 | 进入模式 → 数字键选择候选删除 |

原版**缺少搜狗五笔用户习惯的「一键操作」**,尤其是:

1. **调词序**:原版完全没有"把某个候选词提升到最前"的功能。
2. **一键删词**:原版删词需要两步(Ctrl+7 进模式,再按数字),无法"Ctrl+Shift+数字"直接删除对应候选。
3. 造词/删词快捷键与用户习惯不符。

为了在 fcitx5 上实现这些功能,必须:

- **修改 libime 源码**(`tablecontext.cpp` 的 `shouldReplaceCandidate`):libime 默认在 `OrderPolicy::No` 下,对**词组候选**拒绝用 User flag 替换普通候选,导致"插入用户词 → 重新解码 → 排序"这一机制对词组完全失效。需要修复后才可能实现调词序。
- **修改 fcitx5-chinese-addons 源码**(`im/table/`):在 `TableState` 上暴露两个方法 `promoteCandidate(idx)` / `forgetCandidateByIndex(idx)`,并导出一个 `g_activeTableState` 全局指针和两个 C 符号,供外部插件调用。
- **新增独立 addon 模块**(`im/tablehotkey/`):纯外挂模块,监听按键,通过 `dlsym` 调用上面暴露的接口完成调词序/删词,不侵入 table 引擎内部逻辑。

---

## 二、应实现的功能(最终快捷键)

| 功能 | 快捷键 | 说明 |
|---|---|---|
| **调词序** | `Ctrl+1~9` | 把第 N 个候选词提升为用户词,再次输入时排到最前 |
| **一键删词** | `Ctrl+Shift+1~9` | 直接把第 N 个候选词从词典与历史中移除 |
| **造词** | `Ctrl+Shift+Z` | 进入原版 ModifyDictionary 模式:左右方向键选词组长度(默认 2 字)→ 空格/回车确认。交互与原版 `Ctrl+8` 完全一致 |

> 注:`Ctrl+8` 在终端模拟器(xterm / xfce4-terminal)里会被终端翻译成退格(0x7F),因此 `Ctrl+数字` 调词序在 **GUI 应用**中可用、在**终端类应用**中 `Ctrl+8` 不可用(其余数字键正常)。这是终端固有行为,与 fcitx5 无关。

---

## 三、目录结构

```
fcitx5-table-hotkeys/
├── README.md
├── fcitx5-table-hotkeys.patch   # fcitx5-chinese-addons 的全部改动(修改+新增)
├── libime-table-fix.patch       # libime 的 shouldReplaceCandidate 修复
├── config/
│   └── table.conf               # 用户配置(快捷键定义)
└── source/                      # 修改后的完整相关源码(便于直接查看/编译)
    ├── fcitx5-chinese-addons/
    │   ├── CMakeLists.txt
    │   └── im/
    │       ├── CMakeLists.txt
    │       ├── table/           # 修改:engine.cpp/state.cpp/state.h,新增:hotkey.cpp
    │       └── tablehotkey/     # 新增:独立插件模块
    └── libime/
        └── src/libime/table/
            └── tablecontext.cpp # 修改:shouldReplaceCandidate
```

---

## 四、修改清单

### libime(1 个文件)

`src/libime/table/tablecontext.cpp` — 重写 `shouldReplaceCandidate`:

```cpp
// 用户主动提升/造词的候选(User flag)应优先于普通候选:
//  - 新候选是 User → 替换(让提升生效)
//  - 旧候选是 User 而新候选不是 → 保留(避免被普通词覆盖)
if (newNode->flag() == PhraseFlag::User) {
    return true;
}
if (oldNode->flag() == PhraseFlag::User) {
    return false;
}
```

**为什么**:libime 默认逻辑对 `sentence.size() > 1`(词组)直接 `return false`,即 User flag 词组永远无法替换普通候选。这会让 `insert(code, word, PhraseFlag::User)` 后重新解码时,提升的词不生效。此修复是调词序/造词生效的前提。

### fcitx5-chinese-addons(修改 6 + 新增 4 个文件)

| 文件 | 变更 |
|---|---|
| `im/table/state.h` | 新增 `promoteCandidate(size_t)`, `forgetCandidateByIndex(size_t)` 声明;`forgetCandidateWord` 增加用户词可见性 |
| `im/table/state.cpp` | 实现上述两方法;修复 `forgetCandidateWord` 对词组候选编码为空的问题(fallback 到 `userInput()`) |
| `im/table/engine.cpp` | 在 `activate()` / `keyEvent()` 中把当前 `TableState*` 赋给全局 `g_activeTableState` |
| `im/table/hotkey.cpp` | **新增**:定义 `g_activeTableState` + 导出 `fcitx5_table_promote_candidate` / `fcitx5_table_forget_candidate` 两个 C 符号 |
| `im/table/CMakeLists.txt` | 将 `hotkey.cpp` 加入构建 |
| `im/tablehotkey/` | **新增**:独立插件(`tablehotkey.cpp` + `tablehotkey.conf` + `CMakeLists.txt`),监听按键 → `dlsym` 调钩子 |
| `im/CMakeLists.txt` | 增加 `add_subdirectory(tablehotkey)` |
| `CMakeLists.txt` | 裁剪构建范围(仅编译 table + tablehotkey,去掉 pinyin 等以精简依赖) |

---

## 五、如何构建与安装

### 前置依赖

```bash
sudo apt install gcc g++ cmake ninja-build libfcitx5core-dev libfcitx5config-dev \
     libimecore-dev libimetable-dev libimepinyin-dev libzstd-dev extra-cmake-modules \
     fcitx5-modules-dev gettext
```

### 1. 应用 patch(或直接使用 `source/` 下已改好的文件)

```bash
# libime
cd libime
git apply /path/to/libime-table-fix.patch
# 重新编译并替换 libIMETable.so

# fcitx5-chinese-addons
cd fcitx5-chinese-addons
git apply /path/to/fcitx5-table-hotkeys.patch
# 重新编译,替换 libtable.so,并安装 libtablehotkey.so + tablehotkey.conf
```

### 2. 安装配置

将 `config/table.conf` 复制到 `~/.config/fcitx5/conf/table.conf`:

```ini
[ModifyDictionaryKey]
0=Control+Shift+Z

[ForgetWord]
0=Control+0

[LookupPinyinKey]
0=Control+Alt+E
```

### 3. 重启

```bash
fcitx5 -r
```

---

## 六、回滚到原版

```bash
# 1. libIMETable.so
sudo cp /usr/lib/x86_64-linux-gnu/libIMETable.so.1.1.10.bak-20260813-133358 \
       /usr/lib/x86_64-linux-gnu/libIMETable.so.1.1.10

# 2. 原版 libtable.so
sudo cp /usr/lib/x86_64-linux-gnu/fcitx5/libtable.so.bak-20260813-075931 \
       /usr/lib/x86_64-linux-gnu/fcitx5/libtable.so

# 3. 删除插件
sudo rm /usr/lib/x86_64-linux-gnu/fcitx5/libtablehotkey.so \
       /usr/share/fcitx5/addon/tablehotkey.conf

# 4. 删除配置(恢复默认 Ctrl+8 / Ctrl+7)
rm ~/.config/fcitx5/conf/table.conf

fcitx5 -r
```

> 具体备份文件名以你实际安装时的备份为准。

---

## 七、技术细节

- **为什么用 `dlsym` 而不是直接链接**:fcitx5 以 `RTLD_LOCAL` 加载 addon,符号不在全局命名空间,且 libtable 无 SONAME。插件通过 `dladdr` 定位自身路径 → 拼接 `libtable.so` 绝对路径 → `dlopen` → `dlsym` 拿到两个钩子函数。
- **`Ctrl+数字` vs `Ctrl+Shift+数字` 的区分**:在部分环境(X11/某些键盘)下 `Shift` 修饰标志可能为 0,因此插件用 **keysym 本身**区分——`Ctrl+2` 的 keysym 是 `2`(0x32),`Ctrl+Shift+2` 的 keysym 是 `@`(0x40),天然不同。
- **调序后的即时刷新**:插入 User 词后,`TableContext::candidates()` 是 `update()` 的缓存,需 `clear()` + `type(oldCode)` 触发重新解码,再 `updateUI()` 才能立即看到排序变化。

---

## 八、已知限制

- `Ctrl+8` 在终端模拟器内不可用(终端固有行为,见上文)。
- 造词依赖原版 ModifyDictionary 模式,交互与反馈均来自原版实现。

/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * 表输入法快捷键增强模块(独立插件)。
 *  - Ctrl+1~9         : 调词序(把对应候选词提升词频,使其更靠前)
 *  - Ctrl+Shift+1~9   : 删词(把对应候选词从词典和历史中移除)
 * 造词使用原版 ModifyDictionary 模式(Ctrl+Shift+Z),不由本模块处理。
 * 所有热键逻辑都在本模块,通过 dlsym 调用 libtable 导出的钩子完成动作,
 * 内核(libtable)只暴露调序、删词两个最小钩子。
 */
#include <dlfcn.h>

#include <fcitx-utils/handlertable.h>
#include <fcitx-utils/key.h>
#include <fcitx-utils/keysym.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addoninstance.h>
#include <fcitx/addonmanager.h>
#include <fcitx/event.h>
#include <fcitx/inputcontext.h>
#include <fcitx/inputcontextmanager.h>
#include <fcitx/inputmethodentry.h>
#include <fcitx/instance.h>

namespace fcitx {

typedef bool (*PromoteFn)(int);
typedef bool (*ForgetFn)(int);

class TableHotkey : public AddonInstance {
public:
    TableHotkey(Instance *instance);
    ~TableHotkey() override;

private:
    Instance *instance_;
    std::vector<std::unique_ptr<HandlerTableEntry<EventHandler>>> conns_;
    PromoteFn promote_ = nullptr;
    ForgetFn forget_ = nullptr;

    bool resolve();
    void onKey(Event &event);
};

TableHotkey::TableHotkey(Instance *instance) : instance_(instance) {
    conns_.push_back(instance_->watchEvent(
        EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
        [this](Event &event) { onKey(event); }));
}

TableHotkey::~TableHotkey() = default;

namespace {
// dladdr 锚点:取本模块加载路径用
void tablehotkey_anchor() {}

// 返回纯数字键(无 Shift)的候选索引(0~8),非数字键返回 -1。
// Ctrl+1~9 的 keysym 是数字本身(0x31~0x39)。
int plainDigitIndex(KeySym sym) {
    switch (sym) {
    case FcitxKey_1:
        return 0;
    case FcitxKey_2:
        return 1;
    case FcitxKey_3:
        return 2;
    case FcitxKey_4:
        return 3;
    case FcitxKey_5:
        return 4;
    case FcitxKey_6:
        return 5;
    case FcitxKey_7:
        return 6;
    case FcitxKey_8:
        return 7;
    case FcitxKey_9:
        return 8;
    default:
        return -1;
    }
}

// 返回 Shift+数字 的符号键 keysym 对应的候选索引(0~8),非符号键返回 -1。
// Ctrl+Shift+1~9 的 keysym 是移位符号(!@#$%^&*()。
int shiftedDigitIndex(KeySym sym) {
    switch (sym) {
    case FcitxKey_exclam:
        return 0;
    case FcitxKey_at:
        return 1;
    case FcitxKey_numbersign:
        return 2;
    case FcitxKey_dollar:
        return 3;
    case FcitxKey_percent:
        return 4;
    case FcitxKey_asciicircum:
        return 5;
    case FcitxKey_ampersand:
        return 6;
    case FcitxKey_asterisk:
        return 7;
    case FcitxKey_parenleft:
        return 8;
    default:
        return -1;
    }
}
} // namespace

bool TableHotkey::resolve() {
    if (promote_ && forget_) {
        return true;
    }
    // fcitx5 以 RTLD_LOCAL 加载插件,符号不在全局命名空间;
    // 且库无 SONAME、不在搜索路径,需用绝对路径 dlopen。
    // 通过 dladdr 定位本模块所在目录,再拼接 libtable.so。
    Dl_info info;
    std::string path = "libtable.so";
    if (dladdr(reinterpret_cast<void *>(&tablehotkey_anchor), &info) &&
        info.dli_fname) {
        std::string fname(info.dli_fname);
        auto slash = fname.find_last_of('/');
        if (slash != std::string::npos) {
            path = fname.substr(0, slash + 1) + "libtable.so";
        }
    }
    void *handle = dlopen(path.c_str(), RTLD_NOW);
    if (handle) {
        promote_ = reinterpret_cast<PromoteFn>(
            dlsym(handle, "fcitx5_table_promote_candidate"));
        forget_ = reinterpret_cast<ForgetFn>(
            dlsym(handle, "fcitx5_table_forget_candidate"));
    }
    return promote_ != nullptr && forget_ != nullptr;
}

void TableHotkey::onKey(Event &event) {
    auto &keyEvent = static_cast<KeyEvent &>(event);
    if (keyEvent.isRelease()) {
        return;
    }
    auto *ic = keyEvent.inputContext();
    if (!ic) {
        return;
    }
    const auto *entry = instance_->inputMethodEntry(ic);
    if (!entry || entry->addon() != "table") {
        return;
    }

    const Key &key = keyEvent.key();
    bool ctrl = key.states().test(KeyState::Ctrl);
    bool alt = key.states().test(KeyState::Alt);

    fprintf(stderr, "[thk] key=%s sym=0x%x ctrl=%d alt=%d\n",
            key.toString().c_str(), (unsigned)key.sym(), ctrl, alt);

    if (!ctrl || alt) {
        return;
    }

    // 用 keysym 区分是否按了 Shift:
    //  - Ctrl+2 的 keysym 是 '2'(0x32)→ 调词序
    //  - Ctrl+Shift+2 的 keysym 是 '@'(0x40)→ 删词
    // shift 修饰标志在某些环境(X11/部分键盘)下可能为 0,不能依赖。
    int plainIdx = plainDigitIndex(key.sym());
    int shiftedIdx = shiftedDigitIndex(key.sym());
    if (plainIdx >= 0) {
        // Ctrl+数字 调词序。
        if (resolve() && promote_ && promote_(plainIdx)) {
            // 不 accept 按键,让 table 引擎 keyEvent 继续走完
            // (Ctrl+数字会被当成无效输入忽略),keyEvent 末尾的 updateUI
            // 会读取已被 clear+type 刷新的 candidates。
        }
        return;
    }
    if (shiftedIdx >= 0) {
        // Ctrl+Shift+数字 删词。
        if (resolve() && forget_ && forget_(shiftedIdx)) {
            keyEvent.accept();
        }
        return;
    }
}

class TableHotkeyFactory : public AddonFactory {
public:
    AddonInstance *create(AddonManager *manager) override {
        return new TableHotkey(manager->instance());
    }
};

FCITX_ADDON_FACTORY(TableHotkeyFactory)

} // namespace fcitx

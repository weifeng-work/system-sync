/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * 调序 / 删词 的“内核钩子”。
 * 这里只暴露 C 接口供外部插件模块(tablehotkey)调用,
 * 真正的动作在 TableState 中完成。内核改动保持最小。
 * 造词使用原版 ModifyDictionary 模式,不在此处处理。
 */
#include "state.h"

namespace fcitx {

// 当前聚焦 InputContext 对应的 TableState,由 TableEngine 在按键/激活时更新。
TableState *g_activeTableState = nullptr;

} // namespace fcitx

extern "C" {

// 调序:将第 idx 个候选词提升为用户词组(提升词频,使其更靠前)。
// 返回 true 表示成功。
__attribute__((visibility("default"))) bool
fcitx5_table_promote_candidate(int idx) {
    using namespace fcitx;
    if (!g_activeTableState || idx < 0) {
        return false;
    }
    return g_activeTableState->promoteCandidate(static_cast<size_t>(idx));
}

// 删词:将第 idx 个候选词从词典和历史中移除。
// 返回 true 表示成功。
__attribute__((visibility("default"))) bool
fcitx5_table_forget_candidate(int idx) {
    using namespace fcitx;
    if (!g_activeTableState || idx < 0) {
        return false;
    }
    return g_activeTableState->forgetCandidateByIndex(static_cast<size_t>(idx));
}

} // extern "C"

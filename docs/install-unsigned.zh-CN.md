# 安装未签名预览版

> **标识：未签名 / 未公证（Unsigned / Not notarized）。** GitHub 预发布 ZIP 仅供早期测试，不等于 Developer ID 签名并公证的正式安装包。

English guide: [install-unsigned.md](install-unsigned.md).

## 下载

1. 打开项目的 [GitHub Releases](https://github.com/hlpsxc/runly/releases) 页面。
2. 选择标题类似 `Runly vX.Y.Z-preview.N (unsigned preview)` 的 **pre-release**。
3. 同时下载：
   - `Runly-macOS-unsigned.zip`
   - `SHA256SUMS`

不要把 CI 工作流产物（现为 `Runly-macOS-debug-ci-only`）当作安装来源。那是 **Debug** 构建，可能嵌入构建机绝对路径。请只安装 GitHub **pre-release** 里的 **Release** ZIP。

## 校验

```bash
cd ~/Downloads
shasum -a 256 -c SHA256SUMS
```

应显示 `Runly-macOS-unsigned.zip: OK`。

## 安装

1. 解压 ZIP。
2. 将 `Runly.app` 拖入「应用程序」。
3. 从「应用程序」或 Spotlight 打开 Runly。

## Gatekeeper 提示

未签名应用首次打开可能被拦截。在你信任该 GitHub 来源时，支持的做法是：

1. 先尝试打开一次 `Runly.app`（可能出现拦截提示）。
2. 打开 **系统设置 → 隐私与安全性**。
3. 在近期拦截记录中找到 Runly，选择 **仍要打开**。
4. 如有二次确认，再确认一次。

**不要**默认关闭全局 Gatekeeper，也**不要**默认使用 `xattr -d com.apple.quarantine …` 去掉隔离属性。

## 升级 / 卸载

- **升级：** 退出 Runly，用新版本替换 `Runly.app` 后重新打开。任务与运行历史保存在用户 Application Support 的 SwiftData 中，替换应用包通常不会丢失。
- **卸载：** 退出后将 `Runly.app` 移到废纸篓。只有在你也要删除任务历史时，才清理 Application Support 数据。
- **旧任务时区：** 升级前创建、尚未写入时区字段的任务，继续按 Asia/Shanghai 解释，直到在编辑器中修改。

## 后续：签名分发

正式签名/公证渠道需要 Apple Developer Program、Developer ID、硬化运行时与公证流程。在此之前，所有预览版都必须醒目标注 **Unsigned / Not notarized**。

# 开发验收与发布核对

## 任务验收记录

按用户入口写一条能执行的验收条件。同一任务的代码测试、模拟器和真机分别记录，范围写到实际验证的平台、宿主或测试替身。共用组件的其他调用入口可以在同一任务追加检查。

将记录和日志放在本机 `build/delivery/verification/<任务>/`。以下内容可以保存为 `acceptance.json`，完成检查后填入实际证据。

```json
{
  "task": "取消添加账号后恢复已保存账号列表",
  "checks": [
    {
      "entry": "发现 → 插件设置 → 已保存账号 → 添加账号 → 取消",
      "scope": "冷启动的公共账号宿主，使用浏览器测试替身",
      "expected": "保留原账号，结束加载，添加入口可再次点击",
      "method": "test",
      "status": "pending"
    }
  ]
}
```

`method` 取 `test`、`simulator`、`device` 或 `review`。把 `status` 更新为 `passed` 或 `failed` 时加上 `evidence`，指向非空的日志、截图或验收说明。相对路径从记录所在目录解析。

```sh
python3 -B script/lint/check_task_acceptance.py build/delivery/verification/account/acceptance.json
python3 -B script/lint/check_task_acceptance.py build/delivery/verification/account/acceptance.json --complete
```

第一条允许记录待验与失败项。第二条要求所列检查全部通过。脚本核对记录和证据文件，测试退出码与实际设备行为由对应验证提供。

## 账号和下载回归

```sh
flutter pub get --enforce-lockfile
bash script/test/mobile_regressions.sh account
bash script/test/mobile_regressions.sh download
bash script/test/mobile_regressions.sh
```

账号组覆盖 API 和网页授权、保存与切换、会话恢复、取消与旧回调。下载组覆盖漫画批量入口、视频选集和入队、从列表重试、下载身份、短时故障和启动恢复。默认入口还执行原有的移动基础用例。现有 PR 工作流使用默认入口。浏览器和原生传输替身的覆盖记录在各测试中，真实站点登录、后台传输和弱网结果需要实际场景证据。

macOS 和 Linux x86_64 首次运行时，如缺少 ObjectBox 原生库，入口会准备与当前锁定依赖配套的版本并校验官方压缩包摘要。缓存留在本机 `build/mobile-regressions/`。ObjectBox 依赖升级时，同批核对准备脚本中的原生库版本和摘要。

## 双端发布核对

在仓库根目录冻结候选并保存构建前提交。取上一次正式 GitHub Release 的 JSON 及它的正式 ARM64 APK。历史核验可使用当时保存的 JSON。Android Build Tools 的 `aapt` 和 `apksigner` 可通过 `PATH` 或 `--android-build-tools` 指定，运行签名检查需要可用的 Java。

```sh
release_work=build/delivery/verification/mobile-release
mkdir -p "$release_work"
git rev-parse HEAD > "$release_work/source-commit.txt"
gh api repos/kl5212840-lang/Breeze-Mobile/releases/latest > "$release_work/previous-release.json"
```

按项目现有方式从该提交构建，IPA 使用 [打包脚本](../script/build/package_ipa.py)。以下命令中的安装包路径按实际产物填写。

```sh
python3 -B script/build/check_mobile_release.py \
  --source-ref "$(cat "$release_work/source-commit.txt")" \
  --previous-release "$release_work/previous-release.json" \
  --previous-apk "$release_work/previous-arm64-v8a.apk" \
  --ipa "$release_work/candidate.ipa" \
  --apk "$release_work/candidate-arm64-v8a.apk" \
  --android-build-tools "$HOME/Library/Android/sdk/build-tools/36.0.0" \
  --remote origin > "$release_work/preflight.json"
```

报告包含源码版本和 Git 树、双端包标识、版本、IPA 完整性与设备平台、APK 架构和签名、版本接续及文件摘要。使用上一版 APK 时，会校验其公开附件摘要和递增构建号。已有可信证书指纹时可用 `--previous-signer-sha256` 核对签名，上一版构建号须另行核对。传入 `--remote origin` 时，已有同名标签必须指向核对的提交。

按已确认的交付顺序执行。iCloud 上传后，在同一命令追加 `--icloud-ipa`、`--icloud-apk` 和 `--check-icloud-upload`，同时核对回读字节和 macOS 报告的上传状态。公开发布后追加 `--merged-ref`、`--published-release` 和 `--checksums`，核对合并树、远端标签与公开附件。公开附件名采用 `Breeze-iOS-v<版本>.ipa`、`Breeze-Android-v<版本>-arm64-v8a.apk`，校验清单为 `SHA256SUMS.txt`。

保留构建日志、各阶段报告和已约定的发布后动作。源码对应关系来自构建记录，脚本核对声明的 Git 树与包元数据。公开附件字段的摘要核对、公开下载回读和实机安装分别记录。

use std::fs::File;
use std::io::{BufWriter, Read, Write};
use std::path::{Component, Path, PathBuf};

use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use zip::{CompressionMethod, ZipWriter, write::FileOptions};

/// 流式创建应用数据备份 zip。
///
/// - `data_dir` 下的所有文件/目录会放到 zip 根目录；Dart 侧应在这里准备好
///   `config.json` 与 `objectbox.json`。
/// - 若 `download_dir` 不为空，则其下所有内容会以 `downloads/` 为前缀打包。
/// - 全部使用 Stored（不压缩）方式写入，避免对图片等已压缩数据做无效压缩。
#[frb]
pub async fn create_data_backup_zip(
    zip_path: String,
    data_dir: String,
    download_dir: Option<String>,
) -> Result<()> {
    rquickjs_playground::global_handle()
        .spawn_blocking(move || {
            let file = File::create(&zip_path).with_context(|| {
                rquickjs_playground::tr!("failed-to-create-backup-zip-file", arg0 = zip_path)
            })?;
            let writer = BufWriter::with_capacity(64 * 1024, file);
            let mut zip = ZipWriter::new(writer);

            let options = FileOptions::<()>::default()
                .compression_method(CompressionMethod::Stored)
                .unix_permissions(0o644);

            // 1. 写入数据文件（config.json / objectbox.json 等）
            add_directory_to_zip(&mut zip, &data_dir, "", &options).with_context(|| {
                rquickjs_playground::tr!("failed-to-add-data-directory-to-zip", arg0 = data_dir)
            })?;

            // 2. 可选：写入下载的漫画文件
            if let Some(dir) = download_dir {
                if !dir.is_empty() && Path::new(&dir).exists() {
                    add_directory_to_zip(&mut zip, &dir, "downloads", &options).with_context(
                        || {
                            rquickjs_playground::tr!(
                                "failed-to-add-download-directory-to-zip",
                                arg0 = dir
                            )
                        },
                    )?;
                }
            }

            let mut writer = zip
                .finish()
                .context(rquickjs_playground::tr!("failed-to-finish-zip-write"))?;
            // BufWriter's drop ignores its last write error (e.g. full disk).
            writer
                .flush()
                .context(rquickjs_playground::tr!("failed-to-finish-zip-write"))?;
            Ok::<(), anyhow::Error>(())
        })
        .await
        .context(rquickjs_playground::tr!("zip-backup-task-execution-failed"))?
}

/// 从数据备份 zip 中直接读取 config.json 内容。
#[frb]
pub async fn read_data_backup_config(zip_path: String) -> Result<String> {
    rquickjs_playground::global_handle()
        .spawn_blocking(move || {
            let file = File::open(&zip_path).with_context(|| {
                rquickjs_playground::tr!("failed-to-open-backup-zip", arg0 = zip_path)
            })?;
            let mut archive = zip::ZipArchive::new(file)
                .with_context(|| rquickjs_playground::tr!("failed-to-read-zip", arg0 = zip_path))?;

            let mut entry = archive
                .by_name("config.json")
                .with_context(|| rquickjs_playground::tr!("backup-package-missing-config-json"))?;

            let mut content = String::new();
            entry
                .read_to_string(&mut content)
                .with_context(|| rquickjs_playground::tr!("failed-to-read-config-json"))?;

            Ok::<String, anyhow::Error>(content)
        })
        .await
        .context(rquickjs_playground::tr!(
            "failed-to-execute-backup-config-read-task"
        ))?
}

/// 将数据备份 zip 解压到目标目录。
#[frb]
pub async fn extract_data_backup_zip(zip_path: String, extract_dir: String) -> Result<()> {
    rquickjs_playground::global_handle()
        .spawn_blocking(move || {
            std::fs::create_dir_all(&extract_dir).with_context(|| {
                rquickjs_playground::tr!(
                    "failed-to-create-extraction-directory",
                    arg0 = extract_dir
                )
            })?;

            let file = File::open(&zip_path).with_context(|| {
                rquickjs_playground::tr!("failed-to-open-backup-zip", arg0 = zip_path)
            })?;
            let mut archive = zip::ZipArchive::new(file)
                .with_context(|| rquickjs_playground::tr!("failed-to-read-zip", arg0 = zip_path))?;

            let extract_root = PathBuf::from(&extract_dir);
            let mut buffer = [0u8; 64 * 1024];

            for i in 0..archive.len() {
                let mut entry = archive.by_index(i).with_context(|| {
                    rquickjs_playground::tr!("failed-to-read-zip-entry", arg0 = i)
                })?;

                let entry_path = entry.name().to_string();

                // Backup entries are relative ZIP paths on every platform.
                // An absolute path makes PathBuf::join discard extract_root.
                let relative = Path::new(&entry_path);
                if entry_path.contains('\\')
                    || relative.is_absolute()
                    || relative.components().any(|part| {
                        matches!(
                            part,
                            Component::ParentDir | Component::RootDir | Component::Prefix(_)
                        )
                    })
                {
                    anyhow::bail!(rquickjs_playground::tr!(
                        "found-illegal-zip-entry-path",
                        arg0 = entry_path
                    ));
                }

                let target_path = extract_root.join(&entry_path);

                if entry.is_dir() {
                    std::fs::create_dir_all(&target_path).with_context(|| {
                        rquickjs_playground::tr!(
                            "failed-to-create-directory",
                            arg0 = target_path.display()
                        )
                    })?;
                    continue;
                }

                if let Some(parent) = target_path.parent() {
                    std::fs::create_dir_all(parent).with_context(|| {
                        rquickjs_playground::tr!(
                            "failed-to-create-parent-directory",
                            arg0 = parent.display()
                        )
                    })?;
                }

                let mut out_file = File::create(&target_path).with_context(|| {
                    rquickjs_playground::tr!("failed-to-create-file", arg0 = target_path.display())
                })?;

                loop {
                    let n = entry.read(&mut buffer).with_context(|| {
                        rquickjs_playground::tr!("failed-to-read-zip-entry-2", arg0 = entry_path)
                    })?;
                    if n == 0 {
                        break;
                    }
                    out_file.write_all(&buffer[..n]).with_context(|| {
                        rquickjs_playground::tr!(
                            "failed-to-write-file",
                            arg0 = target_path.display()
                        )
                    })?;
                }
            }

            Ok::<(), anyhow::Error>(())
        })
        .await
        .context(rquickjs_playground::tr!(
            "zip-extraction-task-execution-failed"
        ))?
}

/// 递归把 `src_dir` 下的文件/目录写入 zip；`zip_prefix` 控制 zip 内的前缀路径。
fn add_directory_to_zip<W: Write + std::io::Seek>(
    zip: &mut ZipWriter<W>,
    src_dir: &str,
    zip_prefix: &str,
    options: &FileOptions<()>,
) -> Result<()> {
    let src_path = Path::new(src_dir);
    if !src_path.exists() {
        return Ok(());
    }

    let entries = std::fs::read_dir(src_path)
        .with_context(|| rquickjs_playground::tr!("failed-to-read-directory", arg0 = src_dir))?;

    for entry in entries {
        let entry = entry.with_context(|| {
            rquickjs_playground::tr!("failed-to-read-directory-entry", arg0 = src_dir)
        })?;
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();

        let zip_name = if zip_prefix.is_empty() {
            name
        } else {
            format!("{}/{}", zip_prefix, name)
        };

        if path.is_dir() {
            zip.add_directory(&zip_name, *options).with_context(|| {
                rquickjs_playground::tr!("failed-to-add-directory-to-zip", arg0 = zip_name)
            })?;
            add_directory_to_zip(zip, path.to_str().unwrap_or(""), &zip_name, options)
                .with_context(|| {
                    rquickjs_playground::tr!(
                        "failed-to-recursively-add-directory",
                        arg0 = path.display()
                    )
                })?;
        } else {
            add_file_to_zip(zip, &path, &zip_name, options).with_context(|| {
                rquickjs_playground::tr!("failed-to-add-file-to-zip", arg0 = path.display())
            })?;
        }
    }

    Ok(())
}

fn add_file_to_zip<W: Write + std::io::Seek>(
    zip: &mut ZipWriter<W>,
    src_path: &Path,
    zip_name: &str,
    options: &FileOptions<()>,
) -> Result<()> {
    let mut src_file = File::open(src_path).with_context(|| {
        rquickjs_playground::tr!("failed-to-open-file-2", arg0 = src_path.display())
    })?;

    let len = src_file.metadata()?.len();
    zip.start_file(zip_name, file_options(*options, len))
        .with_context(|| rquickjs_playground::tr!("failed-to-create-zip-entry", arg0 = zip_name))?;

    let mut buffer = [0u8; 64 * 1024];
    loop {
        let n = src_file.read(&mut buffer).with_context(|| {
            rquickjs_playground::tr!("failed-to-read-file", arg0 = src_path.display())
        })?;
        if n == 0 {
            break;
        }
        zip.write_all(&buffer[..n]).with_context(|| {
            rquickjs_playground::tr!("failed-to-write-zip-entry", arg0 = zip_name)
        })?;
    }

    Ok(())
}

fn file_options(options: FileOptions<'_, ()>, len: u64) -> FileOptions<'_, ()> {
    // The archive's central directory switches to ZIP64 automatically; an
    // individual stored entry needs the larger local header before streaming.
    options.large_file(len >= zip::ZIP64_BYTES_THR)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;
    use std::sync::atomic::{AtomicU64, Ordering};

    struct TempDir(PathBuf);
    impl TempDir {
        fn new() -> Self {
            static NEXT: AtomicU64 = AtomicU64::new(0);
            let path = std::env::temp_dir().join(format!(
                "breeze-backup-zip-test-{}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            std::fs::create_dir(&path).unwrap();
            Self(path)
        }
        fn path(&self, name: &str) -> PathBuf {
            self.0.join(name)
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn backup_zip_uses_zip64_entry_headers_only_at_the_size_boundary() {
        for (declared_size, expected_zip64) in [
            (zip::ZIP64_BYTES_THR - 1, false),
            (zip::ZIP64_BYTES_THR, true),
            (zip::ZIP64_BYTES_THR + 1, true),
        ] {
            // A tiny payload exercises the real ZIP writer/reader while the
            // simulated file length exercises the header selection boundary.
            let mut zip = ZipWriter::new(Cursor::new(Vec::new()));
            let options =
                FileOptions::<()>::default().compression_method(CompressionMethod::Stored);
            zip.start_file("video.mp4", file_options(options, declared_size))
                .unwrap();
            zip.write_all(b"fixture").unwrap();
            let cursor = zip.finish().unwrap();
            let extra_length = u16::from_le_bytes([cursor.get_ref()[28], cursor.get_ref()[29]]);
            assert_eq!(extra_length == 20, expected_zip64);
            let mut archive = zip::ZipArchive::new(cursor).unwrap();
            let mut value = String::new();
            archive
                .by_name("video.mp4")
                .unwrap()
                .read_to_string(&mut value)
                .unwrap();
            assert_eq!(value, "fixture");
        }
    }

    #[tokio::test]
    async fn backup_zip_roundtrip_includes_portable_data_and_rejects_parent_path() {
        let temp = TempDir::new();
        let source = temp.path("source");
        std::fs::create_dir(&source).unwrap();
        let fixtures = [
            (
                "config.json",
                r#"{"version":"fixture","includeDownloads":false}"#,
            ),
            ("objectbox.json", r#"{"pluginConfig":[]}"#),
            (
                "portable-data.json",
                r#"{"format":"breeze-portable-data","version":1,"preferences":{},"videoLibrary":{}}"#,
            ),
        ];
        for (name, contents) in fixtures {
            std::fs::write(source.join(name), contents).unwrap();
        }
        let zip = temp.path("backup.zip");
        let extracted = temp.path("extracted");
        create_data_backup_zip(
            zip.to_string_lossy().into_owned(),
            source.to_string_lossy().into_owned(),
            None,
        )
        .await
        .unwrap();
        assert_eq!(
            read_data_backup_config(zip.to_string_lossy().into_owned())
                .await
                .unwrap(),
            fixtures[0].1
        );
        extract_data_backup_zip(
            zip.to_string_lossy().into_owned(),
            extracted.to_string_lossy().into_owned(),
        )
        .await
        .unwrap();
        for (name, contents) in fixtures {
            assert_eq!(
                std::fs::read_to_string(extracted.join(name)).unwrap(),
                contents
            );
        }

        let bad_zip = temp.path("bad.zip");
        let mut bad = ZipWriter::new(File::create(&bad_zip).unwrap());
        bad.start_file("../escape.txt", FileOptions::<()>::default())
            .unwrap();
        bad.write_all(b"fixture").unwrap();
        bad.finish().unwrap();
        assert!(
            extract_data_backup_zip(
                bad_zip.to_string_lossy().into_owned(),
                temp.path("bad-extracted").to_string_lossy().into_owned()
            )
            .await
            .is_err()
        );
        assert!(!temp.path("escape.txt").exists());
        for (index, name) in [
            temp.path("absolute.txt").to_string_lossy().into_owned(),
            "..\\escape.txt".to_string(),
        ]
        .into_iter()
        .enumerate()
        {
            let path = temp.path(&format!("invalid-{index}.zip"));
            let mut zip = ZipWriter::new(File::create(&path).unwrap());
            zip.start_file(name, FileOptions::<()>::default()).unwrap();
            zip.write_all(b"fixture").unwrap();
            zip.finish().unwrap();
            assert!(
                extract_data_backup_zip(
                    path.to_string_lossy().into_owned(),
                    temp.path("invalid-extracted")
                        .to_string_lossy()
                        .into_owned()
                )
                .await
                .is_err()
            );
        }
        assert!(!temp.path("absolute.txt").exists());
    }
}

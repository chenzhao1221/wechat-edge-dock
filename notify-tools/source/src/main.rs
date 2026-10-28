#![allow(dead_code)]
mod data;
mod feature;
mod image;
mod notify;
mod progress;
mod xlog;

use std::{collections::BTreeMap, error::Error};
type Result<T> = std::result::Result<T, Box<dyn Error + Send + Sync>>;

fn run() -> Result<()> {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args.len() == 1 && args[0] == "init-runtime" {
        return notify::initialize(&progress::Progress::default());
    }
    if args.len() < 2 || args.len() > 3 { return Err("Usage: wechat-notify-module <symbols|scan|patch-copy> <DLL copy> [output]".into()); }
    let bytes = std::fs::read(&args[1])?;
    let image = image::Image::parse(&bytes)?;
    let progress = progress::Progress::default();
    if args[0] == "symbols" {
        let symbols = xlog::find_optional(&image, notify::symbol_names(), &progress)?;
        for (name, addresses) in symbols {
            println!("{}\t{}\t{}", if addresses.is_empty() { "MISSING" } else { "FOUND" }, addresses.len(), name);
        }
        return Ok(());
    }
    if args[0] != "scan" && args[0] != "patch-copy" { return Err("Unknown command".into()); }
    let target = &notify::FEATURE.targets[0];
    let symbols = (target.find)(&image, &progress)?;
    let mut analysis = (target.scan)(symbols);
    let references = image.references("notify", BTreeMap::new(), &progress, |_, _, _| Ok(()))?;
    for function in image.functions()? { analysis.visit(&image, &function, &references, &progress)?; }
    let modes = analysis.finish(&image, &references, &progress)?;
    if args[0] == "patch-copy" {
        if args.len() != 3 { return Err("patch-copy requires a new output filename".into()); }
        let output = std::path::Path::new(&args[2]);
        if output.exists() { return Err("Refusing to overwrite existing output".into()); }
        let mode = modes.into_iter().find(|x| x.id == "square").ok_or("Missing mode")?;
        let mut result = bytes.clone();
        let mut writes = BTreeMap::new();
        for edit in &mode.edits {
            if edit.range.len() != edit.bytes.len() || edit.range.end > bytes.len() { return Err("Invalid edit bounds".into()); }
            for (offset, byte) in edit.range.clone().zip(&edit.bytes) {
                if let Some(previous) = writes.insert(offset, *byte) {
                    if previous != *byte { return Err(format!("Conflicting edits at {offset}").into()); }
                }
                result[offset] = *byte;
            }
        }
        // Every changed byte must be covered by a validated edit. Preserve all
        // other existing modifications, including the installed anti-revoke.
        let changed = bytes.iter().zip(&result).filter(|(a,b)| a != b).count();
        std::fs::write(output, &result)?;
        println!("PATCH_COPY edits={} changed_bytes={} size={} output={}", mode.edits.len(), changed, result.len(), output.display());
        return Ok(());
    }
    for mode in modes {
        println!("MODE {} {} edits={}", mode.id, mode.name, mode.edits.len());
        for edit in mode.edits { println!("EDIT {}..{} bytes={}", edit.range.start, edit.range.end, edit.bytes.len()); }
    }
    Ok(())
}

fn main() -> std::process::ExitCode {
    match run() {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => { eprintln!("ERROR {e}"); std::process::ExitCode::FAILURE }
    }
}

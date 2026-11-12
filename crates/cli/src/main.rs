//! Offline diagnostics. Status describes this process, never a probed service.

fn main() -> std::process::ExitCode {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() != 1 {
        return usage();
    }
    if args[0] == "--version" {
        println!("threadmark {}", env!("CARGO_PKG_VERSION"));
    } else if args[0] == "status" {
        println!(
            "stage=foundation contract={} service=not-connected storage=not-implemented adapters=none inference=disabled",
            threadmark_core::CONTRACT_VERSION
        );
    } else if args[0] == "smoke" {
        if threadmark_daemon::smoke().is_err() {
            eprintln!("foundation check failed");
            return std::process::ExitCode::FAILURE;
        }
        println!("foundation check passed; synthetic_items=1; no host delivery");
    } else {
        return usage();
    }
    std::process::ExitCode::SUCCESS
}

fn usage() -> std::process::ExitCode {
    eprintln!("usage: threadmark --version | status | smoke (offline diagnostics)");
    std::process::ExitCode::from(2)
}

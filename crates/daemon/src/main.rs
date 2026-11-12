//! Finite daemon diagnostics; intentionally does not install or start a service.

fn main() -> std::process::ExitCode {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == "--version" {
        println!("threadmark-daemon {}", env!("CARGO_PKG_VERSION"));
    } else if args.len() == 1 && args[0] == "--smoke" {
        if threadmark_daemon::smoke().is_err() {
            eprintln!("foundation check failed");
            return std::process::ExitCode::FAILURE;
        }
        println!("foundation check passed; synthetic_items=1; service=not-started");
    } else {
        eprintln!("usage: threadmark-daemon --version | --smoke (offline; no service)");
        return std::process::ExitCode::from(2);
    }
    std::process::ExitCode::SUCCESS
}

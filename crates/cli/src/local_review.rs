//! Process-owned bounded stdin and lifetime for private review protocol v1.
use std::io::{BufReader, Read, Write};
use std::path::Path;
use std::process::ExitCode;
use std::sync::{Arc, Mutex, mpsc};
use std::time::{Duration, Instant};
use threadmark_daemon::preparation::RetrievalMode;
use threadmark_daemon::review_session::{self as protocol, Action, Control, Error, LocalReview};

enum Input {
    Original(String),
    Action(Action),
}

struct Output {
    frames: usize,
    bytes: usize,
}
impl Output {
    fn emit(&mut self, value: &serde_json::Value, terminal: bool) -> Result<(), Error> {
        let mut line = serde_json::to_vec(value).map_err(|_| Error::Invalid)?;
        line.push(b'\n');
        // Reserve the eighth output frame for terminal bound/failure metadata.
        if line.len() > protocol::FRAME_BYTES
            || self.frames >= protocol::MAX_FRAMES
            || (!terminal && self.frames >= protocol::MAX_FRAMES - 1)
            || self.bytes + line.len() > protocol::TOTAL_BYTES
        {
            return Err(Error::Overflow);
        }
        if std::io::stdout().lock().write_all(&line).is_err() {
            // A partial frame cannot be repaired by appending an error object.
            // Poison output permanently, retaining conservative bounds on all
            // attempted bytes/frames even if the pipe later becomes writable.
            self.frames = protocol::MAX_FRAMES;
            self.bytes = protocol::TOTAL_BYTES;
            return Err(Error::Unavailable);
        }
        self.frames += 1;
        self.bytes += line.len();
        Ok(())
    }
}

fn frame(reader: &mut impl Read) -> Result<Vec<u8>, Error> {
    let mut bytes = Vec::new();
    loop {
        let mut byte = [0];
        match reader.read(&mut byte) {
            Ok(0) => {
                return Err(if bytes.is_empty() {
                    Error::Canceled
                } else {
                    Error::Invalid
                });
            }
            Ok(_) => bytes.push(byte[0]),
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => continue,
            Err(_) => return Err(Error::Unavailable),
        }
        if byte[0] == b'\n' {
            return Ok(bytes);
        }
        if bytes.len() >= protocol::FRAME_BYTES {
            return Err(Error::Overflow);
        }
    }
}

fn read_input(
    tx: mpsc::SyncSender<Input>,
    control: Control,
    ready: Arc<Mutex<bool>>,
    stopped: Arc<Mutex<Option<Error>>>,
) {
    read_input_from(
        BufReader::new(std::io::stdin().lock()),
        tx,
        control,
        ready,
        stopped,
    );
}

fn read_input_from(
    mut reader: impl Read,
    tx: mpsc::SyncSender<Input>,
    control: Control,
    ready: Arc<Mutex<bool>>,
    stopped: Arc<Mutex<Option<Error>>>,
) {
    let result = (|| {
        let mut total = 0;
        for index in 0..protocol::MAX_FRAMES {
            let bytes = frame(&mut reader)?;
            total += bytes.len();
            if total > protocol::TOTAL_BYTES {
                return Err(Error::Overflow);
            }
            let input = if index == 0 {
                Input::Original(protocol::original(&bytes)?)
            } else {
                let action = protocol::action(&bytes)?;
                if matches!(action, Action::Cancel(_)) {
                    return Err(Error::Canceled);
                }
                if !*ready.lock().map_err(|_| Error::Unavailable)? {
                    return Err(Error::Invalid);
                }
                Input::Action(action)
            };
            tx.try_send(input).map_err(|_| Error::Overflow)?;
        }
        // Eight frames may contain a terminal choice. Do not cancel that last
        // choice merely because the input budget is exhausted. Read no ninth
        // frame: receiver closes with bound failure if the eighth was nonterminal.
        Ok(())
    })();
    if let Err(error) = result {
        if let Ok(mut reason) = stopped.lock() {
            *reason = Some(error);
        }
        control.cancel();
    }
}

fn session(
    data_dir: &Path,
    options: threadmark_daemon::local_refinement::Options,
    retrieval: RetrievalMode,
    control: &Control,
    rx: mpsc::Receiver<Input>,
    ready: &Mutex<bool>,
    output: &mut Output,
) -> Result<(), Error> {
    let receive = || {
        rx.recv_timeout(control.deadline().saturating_duration_since(Instant::now()))
            .map_err(|error| match error {
                mpsc::RecvTimeoutError::Timeout => Error::Deadline,
                mpsc::RecvTimeoutError::Disconnected => Error::Overflow,
            })
    };
    let Input::Original(original) = receive()? else {
        return Err(Error::Invalid);
    };
    let mut review =
        LocalReview::start_with_retrieval(data_dir, options, original, control.clone(), retrieval)?;
    control.checkpoint()?;
    let event = review.review()?;
    // Serialize initial publication with input admission: an immediate response
    // waits for the write to finish, while pre-publication actions fail closed.
    {
        let mut published = ready.lock().map_err(|_| Error::Unavailable)?;
        output.emit(&event, false)?;
        *published = true;
    }
    let mut inputs = 1;
    loop {
        let input = receive()?;
        control.checkpoint()?;
        inputs += 1;
        let Input::Action(action) = input else {
            return Err(Error::Invalid);
        };
        match review.apply(action) {
            Ok((event, terminal)) => {
                control.checkpoint()?;
                output.emit(&event, terminal)?;
                if terminal {
                    return Ok(());
                }
            }
            Err(Error::ReviewRequired) => {
                output.emit(&protocol::failure(Error::ReviewRequired), false)?
            }
            Err(error) => return Err(error),
        }
        if inputs == protocol::MAX_FRAMES {
            return Err(Error::Overflow);
        }
    }
}

pub fn run(data_dir: &Path, raw_words: &[std::ffi::OsString]) -> ExitCode {
    let deadline = Instant::now() + Duration::from_secs(300);
    let mut output = Output {
        frames: 0,
        bytes: 0,
    };
    let control = Control::new(deadline);
    // No detached process. This process-owned watchdog also bounds blocked
    // stdout/stdin/core calls. Main returning exits all its threads; the invoking
    // parent must wait/reap, including if it kills the process externally.
    let watchdog_control = control.clone();
    let (_lifetime, watchdog_rx) = mpsc::sync_channel::<()>(0);
    let _watchdog = std::thread::spawn(move || {
        if watchdog_rx.recv_timeout(deadline.saturating_duration_since(Instant::now()))
            == Err(mpsc::RecvTimeoutError::Timeout)
        {
            watchdog_control.cancel();
            std::process::exit(2);
        }
    });
    let words = (raw_words.len() <= 78)
        .then(|| {
            raw_words
                .iter()
                .map(|word| {
                    word.to_str()
                        .filter(|word| word.len() <= 4096)
                        .map(str::to_owned)
                })
                .collect::<Option<Vec<_>>>()
        })
        .flatten();
    let parsed = words.as_deref().and_then(super::local_refinement::parse);
    let Some((options, retrieval)) = parsed else {
        let _ = output.emit(&protocol::failure(Error::Invalid), true);
        return ExitCode::from(2);
    };
    let (tx, rx) = mpsc::sync_channel(1);
    let ready = Arc::new(Mutex::new(false));
    let stopped = Arc::new(Mutex::new(None));
    let reader_control = control.clone();
    let reader_ready = ready.clone();
    let reader_stopped = stopped.clone();
    let _reader =
        std::thread::spawn(move || read_input(tx, reader_control, reader_ready, reader_stopped));
    match session(
        data_dir,
        options,
        retrieval,
        &control,
        rx,
        &ready,
        &mut output,
    ) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            let reason = stopped
                .lock()
                .ok()
                .and_then(|reason| *reason)
                .unwrap_or(error);
            control.cancel();
            let _ = output.emit(&protocol::failure(reason), true);
            ExitCode::from(2)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bounded_queue_cancels_without_waiting_or_buffering_more_commands() {
        let control = Control::new(Instant::now() + Duration::from_secs(1));
        let stopped = Arc::new(Mutex::new(None));
        let (tx, rx) = mpsc::sync_channel(1);
        let bytes = b"{\"version\":1,\"original\":\"synthetic\"}\n{\"use-original\":{\"revision\":1,\"digest\":\"x\"}}\n";
        read_input_from(
            bytes.as_slice(),
            tx,
            control.clone(),
            Arc::new(Mutex::new(true)),
            stopped.clone(),
        );
        assert_eq!(control.checkpoint(), Err(Error::Canceled));
        assert_eq!(*stopped.lock().unwrap(), Some(Error::Overflow));
        assert!(matches!(rx.try_recv(), Ok(Input::Original(_))));
        assert!(rx.try_recv().is_err());
    }

    #[test]
    fn frame_limit_counts_newline_before_parse_and_never_allocates_unbounded() {
        let mut exact = b"{\"version\":1,\"original\":\"synthetic\"}".to_vec();
        exact.resize(8191, b' ');
        exact.push(b'\n');
        assert_eq!(frame(&mut exact.as_slice()).unwrap().len(), 8192);
        assert!(protocol::original(&exact).is_ok());
        let mut oversized = vec![b' '; 8192];
        oversized.push(b'\n');
        assert_eq!(frame(&mut oversized.as_slice()), Err(Error::Overflow));
        assert_eq!(frame(&mut b"partial".as_slice()), Err(Error::Invalid));
    }

    #[test]
    fn output_budget_reserves_terminal_slot_and_never_truncates() {
        // Exercise the exact shared predicates without writing sensitive output.
        let mut output = Output {
            frames: 7,
            bytes: 1000,
        };
        assert_eq!(
            output.emit(&protocol::failure(Error::ReviewRequired), false),
            Err(Error::Overflow)
        );
        output.frames = 8;
        assert_eq!(
            output.emit(&protocol::failure(Error::Overflow), true),
            Err(Error::Overflow)
        );
        output.frames = 0;
        output.bytes = protocol::TOTAL_BYTES;
        assert_eq!(
            output.emit(&protocol::failure(Error::Overflow), true),
            Err(Error::Overflow)
        );
        output.bytes = 0;
        assert_eq!(
            output.emit(&serde_json::json!({"proposed":"x".repeat(8192)}), false),
            Err(Error::Overflow)
        );
    }
}

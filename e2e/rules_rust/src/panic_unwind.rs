// Panics through a frame with a destructor and catches the panic, so both the
// search and the cleanup phase of unwinding run.
use std::panic;
use std::sync::atomic::{AtomicBool, Ordering};

static DROPPED: AtomicBool = AtomicBool::new(false);

struct Guard;

impl Drop for Guard {
    fn drop(&mut self) {
        DROPPED.store(true, Ordering::SeqCst);
    }
}

#[inline(never)]
fn unwind() {
    let _guard = Guard;
    panic!("unwind");
}

fn main() {
    panic::set_hook(Box::new(|_| {}));
    assert!(panic::catch_unwind(unwind).is_err());
    assert!(DROPPED.load(Ordering::SeqCst));
    println!("caught");
}

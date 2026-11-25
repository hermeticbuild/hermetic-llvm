// Catches a panic inside the shared library, so the library's own unwinder
// runs both phases of unwinding.
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

/// Returns 1 if the panic was caught after the guard's destructor ran.
#[no_mangle]
pub extern "C" fn panic_unwind_caught() -> i32 {
    panic::set_hook(Box::new(|_| {}));
    let caught = panic::catch_unwind(unwind).is_err();
    (caught && DROPPED.load(Ordering::SeqCst)) as i32
}

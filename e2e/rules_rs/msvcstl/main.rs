#[cfg(not(target_env = "msvc"))]
compile_error!("Expected a Rust MSVC target");

extern "C" {
    fn msvcstl_probe(value: std::ffi::c_int) -> std::ffi::c_int;
}

fn main() {
    let mut value: libc::c_int = 0;
    assert_eq!(
        unsafe { libc::sscanf(c"42".as_ptr(), c"%d".as_ptr(), &mut value) },
        1
    );
    assert_eq!(unsafe { msvcstl_probe(value) }, 42);
}

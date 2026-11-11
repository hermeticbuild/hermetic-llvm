#[cfg(not(target_env = "msvc"))]
compile_error!("Expected a Rust MSVC target");

extern "C" {
    fn msvcstl_probe(value: std::ffi::c_int) -> std::ffi::c_int;
}

fn main() {
    assert_eq!(unsafe { msvcstl_probe(42) }, 42);
}

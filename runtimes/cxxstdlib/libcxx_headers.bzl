"""Partition libc++ headers for explicit Clang header modules."""

def split_libcxx_headers(headers, prefix):
    """Returns public and textual header lists, preserving their input order.

    Args:
        headers: Header paths below the libc++ include directory.
        prefix: Include directory prefix to strip when classifying paths.

    Returns:
        Two lists of public and textual header paths.
    """
    public = []
    textual = []
    for header in headers:
        relative = header.removeprefix(prefix)
        if "/" not in relative and "." not in relative and not relative.startswith("__"):
            public.append(header)
        else:
            # Implementation variants cannot all be compiled together.
            # C wrappers need textual inclusion for include_next.
            textual.append(header)
    return public, textual

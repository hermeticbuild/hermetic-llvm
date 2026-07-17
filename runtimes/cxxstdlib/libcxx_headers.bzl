"""Partition libc++ headers for explicit Clang header modules."""

def split_libcxx_headers(headers, prefix):
    """Returns public and textual header lists, preserving their input order.

    Args:
        headers: Header paths below the libc++ include directory.
        prefix: Include directory prefix to strip when classifying paths.

    Returns:
        A pair of lists: extensionless public headers and textual headers.
    """
    public = []
    textual = []
    for header in headers:
        relative = header.removeprefix(prefix)
        if "/" not in relative and "." not in relative and not relative.startswith("__"):
            public.append(header)
        else:
            # Implementation headers include mutually exclusive variants;
            # C wrappers use include_next. Both must remain textual.
            textual.append(header)
    return public, textual

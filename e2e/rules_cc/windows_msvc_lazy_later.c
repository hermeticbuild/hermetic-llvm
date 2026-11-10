int wrong_archive_member_was_selected(void);

// The earlier object group supplies this symbol. Moving this archive ahead of
// that group selects this implementation and leaves an unresolved reference.
int selected_member(void) { return wrong_archive_member_was_selected(); }

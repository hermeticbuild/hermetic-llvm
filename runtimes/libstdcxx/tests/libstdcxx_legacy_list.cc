// Match GCC's src/c++98/list-aux-2.cc ABI. Current headers use __detail's
// list nodes, so declare the older layout directly to exercise its symbols.
namespace std {
struct _List_node_base {
    _List_node_base* _M_next;
    _List_node_base* _M_prev;

    void _M_hook(_List_node_base*) noexcept;
    void _M_unhook() noexcept;
    void _M_reverse() noexcept;
    void _M_transfer(_List_node_base*, _List_node_base*) noexcept;
};
}

bool legacy_list_abi_works() {
    std::_List_node_base head{&head, &head};
    std::_List_node_base first{};
    std::_List_node_base second{};
    first._M_hook(&head);
    second._M_hook(&head);
    head._M_reverse();
    if (head._M_next != &second || head._M_prev != &first) {
        return false;
    }

    std::_List_node_base other{&other, &other};
    other._M_transfer(head._M_next, &head);
    if (head._M_next != &head || other._M_next != &second) {
        return false;
    }
    first._M_unhook();
    second._M_unhook();
    return head._M_prev == &head && other._M_next == &other &&
           other._M_prev == &other;
}

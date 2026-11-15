function fortran_add(a, b) bind(c, name="fortran_add") result(value)
  use iso_c_binding, only: c_int
  implicit none
  integer(c_int), value :: a, b
  integer(c_int) :: value
  value = a + b
end function fortran_add

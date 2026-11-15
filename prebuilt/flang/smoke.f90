program smoke
  use iso_c_binding, only: c_int
  use iso_fortran_env, only: output_unit
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer(c_int) :: value

  value = 25
  if (.not. ieee_is_finite(1.0)) stop 2
  write(output_unit, '(a,i0)') 'Fortran=', value
end program smoke

cmake_minimum_required(VERSION 3.16)
project(foreign_msvcstl LANGUAGES CXX)
add_library(foreign STATIC foreign.cc)
install(TARGETS foreign ARCHIVE DESTINATION lib)

#include "windows_msvc_behavior_support.h"

namespace {
struct RegisterAlwayslinkObject {
  RegisterAlwayslinkObject() { windows_msvc_register_alwayslink(); }
};

RegisterAlwayslinkObject registration;
}  // namespace

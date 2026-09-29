#pragma once

#include <cairo.h>
#include <string>

cairo_surface_t* loadAppIcon(const std::string& appClass, const std::string& initialClass, int size, int pid);

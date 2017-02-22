#ifndef __USERHOOKS_HPP__
#define __USERHOOKS_HPP__

#include "Serializable.hpp"

extern "C" {
extern wallaroo::Serializable* w_user_data_deserialize (char* bytes_);
extern bool w_main(int argc, char **argv, Application *application_builder_);
}

#endif //__USERHOOKS__HPP

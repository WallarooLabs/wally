#ifndef __USERHOOKS_HPP__
#define __USERHOOKS_HPP__

#include "Serializable.hpp"

extern "C" {
extern wallaroo::Serializable* w_user_data_deserialize (char* bytes_, size_t sz_);
}

#endif //__USERHOOKS__HPP

#ifndef __WALLAROO_SOURCE_DECODER_H__
#define __WALLAROO_SOURCE_DECODER_H__

#include <cstdlib>
#include "ManagedObject.hpp"
#include "Data.hpp"

namespace wallaroo
{
class SourceDecoder: public ManagedObject
{
public:
  virtual Data *decode(char *bytes, std::size_t sz_) = 0;
};
}

#endif // __WALLAROO_SOURCE_DECODER_H__

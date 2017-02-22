#ifndef __WALLAROO_SOURCE_DECODER_H__
#define __WALLAROO_SOURCE_DECODER_H__

#include "ManagedObject.hpp"
#include "Data.hpp"

namespace wallaroo
{
class SourceDecoder: public ManagedObject
{
public:
  virtual std::size_t header_length() = 0;
  virtual std::size_t payload_length(char *bytes_) = 0;
  virtual Data *decode(char *bytes_) = 0;
};
}

#endif // __WALLAROO_SOURCE_DECODER_H__

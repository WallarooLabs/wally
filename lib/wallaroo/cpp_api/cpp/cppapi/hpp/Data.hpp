#ifndef __DATA_HPP__
#define __DATA_HPP__

#include "Buffers.hpp"
#include "ManagedObject.hpp"

namespace wallaroo
{
class Data: public ManagedObject
{
public:
  virtual ~Data();
};

class EncodableData: public Data
{
public:
  virtual ~EncodableData() {};
  virtual size_t encode_get_size() = 0;
  virtual void encode(char *bytes_) = 0;
};

}
#endif //__DATA_HPP__

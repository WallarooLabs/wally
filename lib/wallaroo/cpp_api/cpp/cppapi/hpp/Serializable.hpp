#ifndef __SERIALIZABLE_HPP__
#define __SERIALIZABLE_HPP__

#include <cstddef>

namespace wallaroo
{
class Serializable
{
public:
  virtual void deserialize (char* bytes_) {}
  virtual void serialize (char* bytes_, size_t nsz_) {}
  virtual size_t serialize_get_size () { return 0; }
};
}
#endif // __SERIALIZABLE_HPP__

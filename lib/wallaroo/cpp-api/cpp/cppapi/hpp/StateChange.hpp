#ifndef __STATECHANGE_H__
#define __STATECHANGE_H__

#include "State.hpp"

namespace wallaroo
{
class StateChange: public ManagedObject
{
public:
  virtual char *name() = 0;
  virtual uint64_t id() = 0;
  virtual void apply(State *state_) = 0;
  virtual size_t get_log_entry_size() = 0;
  virtual void to_log_entry(char *bytes_) = 0;
  virtual size_t get_log_entry_size_header_size() = 0;
  virtual size_t read_log_entry_size_header(char *bytes_) = 0;
  virtual bool read_log_entry(char *bytes_) = 0;
};
}

#endif // __STATECHANGE_H__

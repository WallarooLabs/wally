#ifndef __STATECHANGE_H__
#define __STATECHANGE_H__


#include "State.hpp"
#include <cstdint>
#include <cstddef>

namespace wallaroo
{
class StateChange: public ManagedObject
{
  protected:
    uint64_t _id;

  public:
    StateChange() : _id(0) {}
    StateChange(uint64_t id_) : _id(id_) {}

  public:
    virtual const char *name() = 0;
    virtual void apply(State *state_) = 0;
    virtual void to_log_entry(char *bytes_) = 0;
    virtual size_t get_log_entry_size() = 0;
    virtual size_t get_log_entry_size_header_size() = 0;
    virtual size_t read_log_entry_size_header(char *bytes_) = 0;
    virtual bool read_log_entry(char *bytes_) = 0;

  public:
    virtual uint64_t id() { return _id; }
    virtual string str() { return "StateChange"; }
};
}

#endif // __STATECHANGE_H__
